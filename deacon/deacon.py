#!/usr/bin/env python3
"""
OpenClaw Launcher - Deacon Service

Manages the lifecycle of sub-OpenClaw instances:
- Launch new instances on demand
- Health monitoring
- Daily OpenClaw upgrades across all instances
- Instance teardown
"""

import os
import sys
import time
import json
import logging
import schedule
import threading
from datetime import datetime, timezone
from typing import Dict, List, Optional
from http.server import HTTPServer, BaseHTTPRequestHandler
import docker

logging.basicConfig(
    level=getattr(logging, os.getenv("LOG_LEVEL", "INFO").upper(), logging.INFO),
    format="%(asctime)s [%(name)s] %(levelname)s %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger("deacon")

OPENCLAW_IMAGE = os.getenv("OPENCLAW_IMAGE", "openclaw-launcher/instance:latest")
OPENCLAW_NETWORK = os.getenv("OPENCLAW_NETWORK", "openclaw-launcher_openclaw-isolated")
HEALTH_CHECK_INTERVAL = int(os.getenv("HEALTH_CHECK_INTERVAL", "300"))
UPGRADE_INTERVAL = int(os.getenv("UPGRADE_INTERVAL", "86400"))
STATE_FILE = "/var/lib/deacon/instances.json"


class InstanceManager:
    """Manages OpenClaw sub-instance lifecycle."""

    def __init__(self):
        self.client = docker.from_env()
        self.instances: Dict[str, dict] = {}
        self._load_state()

    def _load_state(self):
        try:
            if os.path.exists(STATE_FILE):
                with open(STATE_FILE) as f:
                    self.instances = json.load(f)
                logger.info("Loaded %d instance records", len(self.instances))
        except Exception as e:
            logger.warning("Could not load state: %s", e)

    def _save_state(self):
        try:
            with open(STATE_FILE, "w") as f:
                json.dump(self.instances, f, indent=2)
        except Exception as e:
            logger.error("Could not save state: %s", e)

    def launch_instance(
        self,
        name: str,
        telegram_bot_token: str,
        env_keys: Optional[Dict[str, str]] = None,
        mem_limit: str = "4g",
        cpu_limit: float = 2.0,
    ) -> dict:
        """Launch a new OpenClaw sub-instance."""
        container_name = f"openclaw-{name}"

        # Check if already exists
        try:
            existing = self.client.containers.get(container_name)
            if existing.status == "running":
                return {"status": "already_running", "name": container_name}
            existing.remove(force=True)
        except docker.errors.NotFound:
            pass

        # Build environment
        environment = {
            "HOME": "/home/openclaw",
            "PATH": "/home/openclaw/.local/bin:/usr/local/bin:/usr/bin:/bin",
            "OPENCLAW_AGENT": name,
            "OPENCLAW_CONFIG": "/home/openclaw/.openclaw/openclaw.json",
        }
        if env_keys:
            environment.update(env_keys)

        # Create per-instance volumes
        config_vol = f"openclaw-{name}-config"
        data_vol = f"openclaw-{name}-data"

        for vol_name in [config_vol, data_vol]:
            try:
                self.client.volumes.get(vol_name)
            except docker.errors.NotFound:
                self.client.volumes.create(vol_name)

        # Write initial config if volume is fresh
        self._init_config(config_vol, name, telegram_bot_token)

        # Launch container
        container = self.client.containers.run(
            image=OPENCLAW_IMAGE,
            name=container_name,
            detach=True,
            restart_policy={"Name": "unless-stopped"},
            environment=environment,
            volumes={
                config_vol: {"bind": "/home/openclaw/.openclaw", "mode": "rw"},
                data_vol: {"bind": "/home/openclaw/data", "mode": "rw"},
            },
            dns=["8.8.8.8", "1.1.1.1"],
            mem_limit=mem_limit,
            nano_cpus=int(cpu_limit * 1e9),
            network=OPENCLAW_NETWORK,
            labels={
                "openclaw.managed": "true",
                "openclaw.instance": name,
                "openclaw.launcher": "deacon",
            },
        )

        record = {
            "name": name,
            "container_name": container_name,
            "container_id": container.id,
            "created_at": datetime.now(timezone.utc).isoformat(),
            "status": "running",
            "mem_limit": mem_limit,
            "cpu_limit": cpu_limit,
        }
        self.instances[name] = record
        self._save_state()

        logger.info("Launched instance %s (container: %s)", name, container.short_id)
        return record

    def _init_config(self, config_vol: str, name: str, telegram_bot_token: str):
        """Write initial openclaw.json into the config volume if empty."""
        try:
            # Use a temp container to check/write to the volume
            result = self.client.containers.run(
                "ubuntu:24.04",
                command="cat /config/openclaw.json",
                volumes={config_vol: {"bind": "/config", "mode": "rw"}},
                remove=True,
                stdout=True,
                stderr=True,
            )
            # Config already exists
            return
        except Exception:
            pass

        config = {
            "agents": {
                "defaults": {
                    "model": {"primary": "kimi-coding/k2p5"},
                    "compaction": {"mode": "safeguard"},
                    "maxConcurrent": 4,
                }
            },
            "channels": {
                "telegram": {
                    "enabled": True,
                    "dmPolicy": "allowlist",
                    "botToken": telegram_bot_token,
                    "allowFrom": [],
                    "groupPolicy": "allowlist",
                    "groupAllowFrom": [],
                }
            },
            "gateway": {
                "port": 18790,
                "mode": "local",
                "bind": "lan",
                "controlUi": {"dangerouslyAllowHostHeaderOriginFallback": True},
            },
            "plugins": {
                "entries": {
                    "telegram": {"enabled": True},
                    "llm-task": {"enabled": True},
                }
            },
        }

        config_json = json.dumps(config, indent=2)

        try:
            self.client.containers.run(
                "ubuntu:24.04",
                command=["bash", "-c", f"mkdir -p /config/state /config/workspace/skills && echo {config_json} > /config/openclaw.json"],
                volumes={config_vol: {"bind": "/config", "mode": "rw"}},
                remove=True,
            )
            logger.info("Initialized config for instance %s", name)
        except Exception as e:
            logger.error("Failed to init config for %s: %s", name, e)

    def stop_instance(self, name: str) -> dict:
        """Stop an instance."""
        container_name = f"openclaw-{name}"
        try:
            container = self.client.containers.get(container_name)
            container.stop(timeout=30)
            if name in self.instances:
                self.instances[name]["status"] = "stopped"
                self._save_state()
            return {"status": "stopped", "name": container_name}
        except docker.errors.NotFound:
            return {"status": "not_found", "name": container_name}

    def destroy_instance(self, name: str) -> dict:
        """Stop and remove an instance (keeps volumes)."""
        container_name = f"openclaw-{name}"
        try:
            container = self.client.containers.get(container_name)
            container.remove(force=True)
        except docker.errors.NotFound:
            pass

        if name in self.instances:
            self.instances[name]["status"] = "destroyed"
            self._save_state()

        return {"status": "destroyed", "name": container_name}

    def list_instances(self) -> List[dict]:
        """List all managed instances with live status."""
        results = []
        for name, record in self.instances.items():
            container_name = f"openclaw-{name}"
            try:
                container = self.client.containers.get(container_name)
                record["live_status"] = container.status
            except docker.errors.NotFound:
                record["live_status"] = "not_found"
            results.append(record)
        return results

    def get_managed_containers(self) -> List:
        """Get all running containers with openclaw.managed label."""
        return self.client.containers.list(
            filters={"label": "openclaw.managed=true"}
        )

    def upgrade_all(self):
        """Upgrade OpenClaw in all running instances."""
        logger.info("Starting OpenClaw upgrade across all instances...")
        containers = self.get_managed_containers()

        for container in containers:
            try:
                logger.info("Upgrading %s...", container.name)
                result = container.exec_run(
                    ["npm", "update", "-g", "openclaw@latest"],
                    environment={"HOME": "/home/openclaw"},
                )
                if result.exit_code == 0:
                    logger.info("Upgraded %s successfully", container.name)
                else:
                    logger.warning(
                        "Upgrade failed for %s: %s",
                        container.name,
                        result.output.decode(),
                    )
            except Exception as e:
                logger.error("Error upgrading %s: %s", container.name, e)

    def health_check_all(self):
        """Health check all managed instances."""
        logger.info("Running health checks...")
        containers = self.get_managed_containers()

        for container in containers:
            try:
                health = {
                    "name": container.name,
                    "status": container.status,
                    "running": container.status == "running",
                }
                if container.status != "running":
                    logger.warning("Instance %s is %s", container.name, container.status)
                else:
                    # Check if gateway process is alive
                    result = container.exec_run(["pgrep", "-f", "openclaw-gateway"])
                    health["gateway_alive"] = result.exit_code == 0
                    if not health["gateway_alive"]:
                        logger.warning("Gateway not running in %s", container.name)

                logger.info("Health: %s -> %s", container.name, health)
            except Exception as e:
                logger.error("Health check failed for %s: %s", container.name, e)


class APIHandler(BaseHTTPRequestHandler):
    """HTTP API for the Deacon service."""

    manager: InstanceManager = None

    def log_message(self, format, *args):
        logger.debug("API: %s", format % args)

    def do_GET(self):
        if self.path == "/health":
            self._json({"status": "healthy", "timestamp": datetime.now(timezone.utc).isoformat()})
        elif self.path == "/instances":
            self._json(self.manager.list_instances())
        else:
            self._error(404, "Not found")

    def do_POST(self):
        if self.path == "/instances/launch":
            body = self._read_body()
            if not body:
                self._error(400, "Missing request body")
                return
            name = body.get("name")
            token = body.get("telegram_bot_token")
            if not name or not token:
                self._error(400, "name and telegram_bot_token required")
                return
            result = self.manager.launch_instance(
                name=name,
                telegram_bot_token=token,
                env_keys=body.get("env_keys"),
                mem_limit=body.get("mem_limit", "4g"),
                cpu_limit=body.get("cpu_limit", 2.0),
            )
            self._json(result)
        elif self.path == "/instances/stop":
            body = self._read_body()
            if not body or "name" not in body:
                self._error(400, "name required")
                return
            self._json(self.manager.stop_instance(body["name"]))
        elif self.path == "/instances/destroy":
            body = self._read_body()
            if not body or "name" not in body:
                self._error(400, "name required")
                return
            self._json(self.manager.destroy_instance(body["name"]))
        elif self.path == "/upgrade":
            threading.Thread(target=self.manager.upgrade_all, daemon=True).start()
            self._json({"status": "upgrade_triggered"})
        else:
            self._error(404, "Not found")

    def _read_body(self) -> Optional[dict]:
        try:
            length = int(self.headers.get("Content-Length", 0))
            if length == 0:
                return None
            return json.loads(self.rfile.read(length))
        except Exception:
            return None

    def _json(self, data):
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data, default=str).encode())

    def _error(self, code: int, msg: str):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"error": msg}).encode())


def main():
    logger.info("=" * 50)
    logger.info("OpenClaw Deacon starting")
    logger.info("Image: %s", OPENCLAW_IMAGE)
    logger.info("Network: %s", OPENCLAW_NETWORK)
    logger.info("=" * 50)

    manager = InstanceManager()

    # Schedule tasks
    schedule.every(HEALTH_CHECK_INTERVAL).seconds.do(manager.health_check_all)
    schedule.every(UPGRADE_INTERVAL).seconds.do(manager.upgrade_all)

    # Start API server
    APIHandler.manager = manager
    server = HTTPServer(("0.0.0.0", 8080), APIHandler)
    api_thread = threading.Thread(target=server.serve_forever, daemon=True)
    api_thread.start()
    logger.info("API server listening on :8080")

    # Run initial health check
    manager.health_check_all()

    logger.info("Deacon is running")

    try:
        while True:
            schedule.run_pending()
            time.sleep(1)
    except KeyboardInterrupt:
        logger.info("Shutting down...")


if __name__ == "__main__":
    main()
