#!/usr/bin/env python3
"""
OpenClaw Launcher - Deacon Service

The Deacon is a daemon service responsible for:
1. Daily plugin updates via clawhub update --all
2. Maton.ai integration health checks
3. Custom skills backup to persistent storage
4. Telegram STT failure monitoring (known issue)
5. Resource monitoring and alerting
"""

import os
import sys
import time
import json
import logging
import schedule
import threading
from datetime import datetime
from typing import Dict, List, Optional, Callable
import requests
import docker
from http.server import HTTPServer, BaseHTTPRequestHandler
from prometheus_client import start_http_server, Counter, Gauge, Histogram

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('/var/log/deacon/deacon.log')
    ]
)
logger = logging.getLogger('deacon')

# Prometheus metrics
PLUGIN_UPDATES_TOTAL = Counter('deacon_plugin_updates_total', 'Total plugin updates', ['status'])
HEALTH_CHECKS_TOTAL = Counter('deacon_health_checks_total', 'Total health checks', ['service', 'status'])
BACKUPS_TOTAL = Counter('deacon_backups_total', 'Total backups', ['status'])
ACTIVE_CONTAINERS = Gauge('deacon_active_containers', 'Number of active OpenClaw containers')
TELEGRAM_STT_ERRORS = Counter('deacon_telegram_stt_errors_total', 'Telegram STT errors')
PLUGIN_UPDATE_DURATION = Histogram('deacon_plugin_update_duration_seconds', 'Plugin update duration')

class Config:
    """Deacon configuration"""
    PLUGIN_UPDATE_INTERVAL = int(os.getenv('PLUGIN_UPDATE_INTERVAL', '86400'))
    HEALTH_CHECK_INTERVAL = int(os.getenv('HEALTH_CHECK_INTERVAL', '300'))
    BACKUP_INTERVAL = int(os.getenv('BACKUP_INTERVAL', '3600'))
    ALERT_WEBHOOK_URL = os.getenv('ALERT_WEBHOOK_URL', '')
    LOG_LEVEL = os.getenv('LOG_LEVEL', 'info')
    API_PORT = int(os.getenv('API_PORT', '8080'))
    METRICS_PORT = int(os.getenv('METRICS_PORT', '9090'))

class AlertManager:
    """Manages alerts and notifications"""
    
    def __init__(self, webhook_url: str = ''):
        self.webhook_url = webhook_url
        self.alert_history: List[Dict] = []
    
    def send_alert(self, title: str, message: str, severity: str = 'warning'):
        """Send alert via webhook"""
        alert = {
            'timestamp': datetime.utcnow().isoformat(),
            'title': title,
            'message': message,
            'severity': severity
        }
        
        self.alert_history.append(alert)
        
        if self.webhook_url:
            try:
                response = requests.post(
                    self.webhook_url,
                    json=alert,
                    timeout=10
                )
                response.raise_for_status()
                logger.info(f"Alert sent: {title}")
            except Exception as e:
                logger.error(f"Failed to send alert: {e}")
        else:
            logger.warning(f"ALERT: [{severity}] {title} - {message}")

class DockerManager:
    """Manages Docker containers and operations"""
    
    def __init__(self):
        self.client = docker.from_env()
    
    def get_openclaw_containers(self) -> List[docker.models.containers.Container]:
        """Get all OpenClaw containers"""
        containers = []
        for container in self.client.containers.list():
            if 'openclaw' in container.name.lower():
                containers.append(container)
        return containers
    
    def exec_in_container(self, container_name: str, command: List[str]) -> tuple:
        """Execute command in container"""
        try:
            container = self.client.containers.get(container_name)
            result = container.exec_run(command)
            return result.exit_code, result.output.decode('utf-8')
        except Exception as e:
            logger.error(f"Failed to exec in {container_name}: {e}")
            return -1, str(e)
    
    def get_container_health(self, container_name: str) -> Dict:
        """Get container health status"""
        try:
            container = self.client.containers.get(container_name)
            return {
                'name': container.name,
                'status': container.status,
                'health': container.attrs.get('State', {}).get('Health', {}).get('Status', 'unknown'),
                'running': container.status == 'running'
            }
        except Exception as e:
            logger.error(f"Failed to get health for {container_name}: {e}")
            return {'name': container_name, 'status': 'error', 'error': str(e)}

class PluginManager:
    """Manages plugin updates and operations"""
    
    def __init__(self, docker_manager: DockerManager, alert_manager: AlertManager):
        self.docker = docker_manager
        self.alerts = alert_manager
    
    def update_all_plugins(self):
        """Update all plugins in all OpenClaw containers"""
        logger.info("Starting plugin update cycle...")
        start_time = time.time()
        
        containers = self.docker.get_openclaw_containers()
        ACTIVE_CONTAINERS.set(len(containers))
        
        success_count = 0
        fail_count = 0
        
        for container in containers:
            try:
                logger.info(f"Updating plugins in {container.name}...")
                
                # Update ClawHub plugins
                exit_code, output = self.docker.exec_in_container(
                    container.name,
                    ['clawhub', 'update', '--all']
                )
                
                if exit_code == 0:
                    logger.info(f"ClawHub plugins updated in {container.name}")
                else:
                    logger.warning(f"ClawHub update output: {output}")
                
                # Update OpenClaw plugins
                exit_code, output = self.docker.exec_in_container(
                    container.name,
                    ['openclaw', 'plugin', 'update', '--all']
                )
                
                if exit_code == 0:
                    logger.info(f"OpenClaw plugins updated in {container.name}")
                    success_count += 1
                else:
                    logger.error(f"Failed to update OpenClaw plugins in {container.name}: {output}")
                    fail_count += 1
                    
            except Exception as e:
                logger.error(f"Error updating plugins in {container.name}: {e}")
                fail_count += 1
        
        duration = time.time() - start_time
        PLUGIN_UPDATE_DURATION.observe(duration)
        PLUGIN_UPDATES_TOTAL.labels(status='success').inc(success_count)
        PLUGIN_UPDATES_TOTAL.labels(status='failed').inc(fail_count)
        
        logger.info(f"Plugin update cycle completed in {duration:.2f}s")
        
        if fail_count > 0:
            self.alerts.send_alert(
                'Plugin Update Failures',
                f'{fail_count} containers failed plugin updates',
                'warning'
            )

class HealthChecker:
    """Performs health checks on services"""
    
    def __init__(self, docker_manager: DockerManager, alert_manager: AlertManager):
        self.docker = docker_manager
        self.alerts = alert_manager
        self.check_results: Dict[str, Dict] = {}
    
    def check_all_services(self):
        """Run health checks on all services"""
        logger.info("Running health checks...")
        
        # Check OpenClaw containers
        containers = self.docker.get_openclaw_containers()
        for container in containers:
            health = self.docker.get_container_health(container.name)
            self.check_results[container.name] = health
            
            if health.get('running'):
                HEALTH_CHECKS_TOTAL.labels(service=container.name, status='healthy').inc()
                logger.info(f"{container.name} is healthy")
            else:
                HEALTH_CHECKS_TOTAL.labels(service=container.name, status='unhealthy').inc()
                logger.error(f"{container.name} is not running")
                self.alerts.send_alert(
                    'Container Unhealthy',
                    f'Container {container.name} is not running',
                    'critical'
                )
        
        # Check Telegram STT (known issue monitoring)
        self._check_telegram_stt()
    
    def _check_telegram_stt(self):
        """Check Telegram STT functionality"""
        containers = self.docker.get_openclaw_containers()
        
        for container in containers:
            try:
                # Check for STT-related errors in logs
                exit_code, output = self.docker.exec_in_container(
                    container.name,
                    ['grep', '-i', 'transcription failed', '/var/log/openclaw/telegram.log']
                )
                
                if exit_code == 0 and output.strip():
                    error_count = len(output.strip().split('\n'))
                    TELEGRAM_STT_ERRORS.inc(error_count)
                    
                    if error_count > 10:
                        self.alerts.send_alert(
                            'Telegram STT Issues',
                            f'{error_count} transcription failures detected in {container.name}',
                            'warning'
                        )
                        
            except Exception as e:
                logger.debug(f"Could not check Telegram STT for {container.name}: {e}")

class BackupManager:
    """Manages backups of custom skills and data"""
    
    def __init__(self, docker_manager: DockerManager, alert_manager: AlertManager):
        self.docker = docker_manager
        self.alerts = alert_manager
        self.backup_dir = '/var/lib/deacon/backups'
    
    def backup_all(self):
        """Backup custom skills from all containers"""
        logger.info("Starting backup cycle...")
        
        containers = self.docker.get_openclaw_containers()
        success_count = 0
        fail_count = 0
        
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        
        for container in containers:
            try:
                backup_path = f"{self.backup_dir}/{container.name}_{timestamp}"
                os.makedirs(backup_path, exist_ok=True)
                
                # Backup skills directory
                exit_code, output = self.docker.exec_in_container(
                    container.name,
                    ['tar', 'czf', '-', '/root/.openclaw/skills']
                )
                
                if exit_code == 0:
                    with open(f"{backup_path}/skills.tar.gz", 'wb') as f:
                        # Note: exec_run returns bytes directly in newer docker SDK
                        if isinstance(output, bytes):
                            f.write(output)
                        else:
                            f.write(output.encode())
                    
                    logger.info(f"Backed up skills from {container.name}")
                    success_count += 1
                else:
                    logger.error(f"Failed to backup {container.name}: {output}")
                    fail_count += 1
                    
            except Exception as e:
                logger.error(f"Error backing up {container.name}: {e}")
                fail_count += 1
        
        BACKUPS_TOTAL.labels(status='success').inc(success_count)
        BACKUPS_TOTAL.labels(status='failed').inc(fail_count)
        
        logger.info(f"Backup cycle completed: {success_count} success, {fail_count} failed")
        
        # Cleanup old backups (keep last 7 days)
        self._cleanup_old_backups()
    
    def _cleanup_old_backups(self):
        """Remove backups older than 7 days"""
        try:
            import shutil
            
            for item in os.listdir(self.backup_dir):
                item_path = os.path.join(self.backup_dir, item)
                if os.path.isdir(item_path):
                    mtime = os.path.getmtime(item_path)
                    age_days = (time.time() - mtime) / 86400
                    
                    if age_days > 7:
                        shutil.rmtree(item_path)
                        logger.info(f"Removed old backup: {item}")
                        
        except Exception as e:
            logger.error(f"Error cleaning up old backups: {e}")

class APIHandler(BaseHTTPRequestHandler):
    """HTTP API handler for Deacon"""
    
    deacon_instance = None
    
    def log_message(self, format, *args):
        logger.info(f"API: {format % args}")
    
    def do_GET(self):
        """Handle GET requests"""
        if self.path == '/health':
            self._send_json({'status': 'healthy', 'timestamp': datetime.utcnow().isoformat()})
        elif self.path == '/status':
            self._send_json(self._get_status())
        elif self.path == '/metrics':
            self._send_prometheus_metrics()
        else:
            self._send_error(404, 'Not found')
    
    def do_POST(self):
        """Handle POST requests"""
        if self.path == '/update-plugins':
            threading.Thread(target=self.deacon_instance.plugin_manager.update_all_plugins).start()
            self._send_json({'status': 'update triggered'})
        elif self.path == '/backup':
            threading.Thread(target=self.deacon_instance.backup_manager.backup_all).start()
            self._send_json({'status': 'backup triggered'})
        else:
            self._send_error(404, 'Not found')
    
    def _send_json(self, data: Dict):
        """Send JSON response"""
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())
    
    def _send_error(self, code: int, message: str):
        """Send error response"""
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps({'error': message}).encode())
    
    def _get_status(self) -> Dict:
        """Get current status"""
        return {
            'timestamp': datetime.utcnow().isoformat(),
            'containers': len(self.deacon_instance.docker.get_openclaw_containers()),
            'last_plugin_update': getattr(self.deacon_instance, 'last_plugin_update', None),
            'last_health_check': getattr(self.deacon_instance, 'last_health_check', None),
            'last_backup': getattr(self.deacon_instance, 'last_backup', None)
        }
    
    def _send_prometheus_metrics(self):
        """Send Prometheus metrics"""
        from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
        
        self.send_response(200)
        self.send_header('Content-Type', CONTENT_TYPE_LATEST)
        self.end_headers()
        self.wfile.write(generate_latest())

class Deacon:
    """Main Deacon daemon"""
    
    def __init__(self):
        self.config = Config()
        self.docker = DockerManager()
        self.alerts = AlertManager(self.config.ALERT_WEBHOOK_URL)
        self.plugin_manager = PluginManager(self.docker, self.alerts)
        self.health_checker = HealthChecker(self.docker, self.alerts)
        self.backup_manager = BackupManager(self.docker, self.alerts)
        
        self.last_plugin_update: Optional[str] = None
        self.last_health_check: Optional[str] = None
        self.last_backup: Optional[str] = None
        
        self.running = False
    
    def setup_schedules(self):
        """Setup scheduled tasks"""
        # Plugin updates - daily
        schedule.every(self.config.PLUGIN_UPDATE_INTERVAL).seconds.do(self._run_plugin_update)
        
        # Health checks - every 5 minutes
        schedule.every(self.config.HEALTH_CHECK_INTERVAL).seconds.do(self._run_health_check)
        
        # Backups - hourly
        schedule.every(self.config.BACKUP_INTERVAL).seconds.do(self._run_backup)
        
        logger.info("Schedules configured:")
        logger.info(f"  - Plugin updates: every {self.config.PLUGIN_UPDATE_INTERVAL}s")
        logger.info(f"  - Health checks: every {self.config.HEALTH_CHECK_INTERVAL}s")
        logger.info(f"  - Backups: every {self.config.BACKUP_INTERVAL}s")
    
    def _run_plugin_update(self):
        """Run plugin update and record timestamp"""
        self.plugin_manager.update_all_plugins()
        self.last_plugin_update = datetime.utcnow().isoformat()
    
    def _run_health_check(self):
        """Run health check and record timestamp"""
        self.health_checker.check_all_services()
        self.last_health_check = datetime.utcnow().isoformat()
    
    def _run_backup(self):
        """Run backup and record timestamp"""
        self.backup_manager.backup_all()
        self.last_backup = datetime.utcnow().isoformat()
    
    def start_api_server(self):
        """Start HTTP API server"""
        APIHandler.deacon_instance = self
        server = HTTPServer(('0.0.0.0', self.config.API_PORT), APIHandler)
        
        def run_server():
            logger.info(f"API server started on port {self.config.API_PORT}")
            server.serve_forever()
        
        thread = threading.Thread(target=run_server, daemon=True)
        thread.start()
    
    def start_metrics_server(self):
        """Start Prometheus metrics server"""
        try:
            start_http_server(self.config.METRICS_PORT)
            logger.info(f"Metrics server started on port {self.config.METRICS_PORT}")
        except Exception as e:
            logger.error(f"Failed to start metrics server: {e}")
    
    def run(self):
        """Main run loop"""
        logger.info("=" * 50)
        logger.info("Deacon Service Starting")
        logger.info("=" * 50)
        
        self.setup_schedules()
        self.start_api_server()
        self.start_metrics_server()
        
        # Run initial checks
        self._run_health_check()
        
        self.running = True
        
        logger.info("Deacon is running")
        
        try:
            while self.running:
                schedule.run_pending()
                time.sleep(1)
        except KeyboardInterrupt:
            logger.info("Shutting down...")
            self.running = False
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            raise

def main():
    """Main entry point"""
    deacon = Deacon()
    deacon.run()

if __name__ == '__main__':
    main()
