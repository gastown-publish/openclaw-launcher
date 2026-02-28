#!/usr/bin/env python3
"""
Batch GitHub Issue Creation Script for OpenClaw Launcher
Creates all 100 improvements as GitHub issues with rate limiting.

Usage:
    export GITHUB_TOKEN="your_token_here"
    python3 create-issues-batch.py [start_index] [end_index]

Example:
    python3 create-issues-batch.py 0 20    # Create issues 1-20
    python3 create-issues-batch.py 20 40   # Create issues 21-40
    python3 create-issues-batch.py         # Create all 100 issues
"""

import requests
import json
import time
import sys
import os

GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", "")
REPO = "gastown-publish/openclaw-launcher"
API_BASE = "https://api.github.com"

headers = {
    "Authorization": f"token {GITHUB_TOKEN}",
    "Accept": "application/vnd.github.v3+json",
    "Content-Type": "application/json"
}

improvements = [
    # Core Runtime (1-20)
    ("1", "core-runtime", "Implement `gt rig add openclaw` auto-configuration script", "Create automated configuration script that integrates OpenClaw as a first-class rig type within GasTown ecosystem. Handles complete setup from detection to initialization.", "high", "medium"),
    ("2", "core-runtime", "Create OpenClaw Gateway lifecycle manager", "Implement comprehensive lifecycle manager for OpenClaw Gateway handling start, stop, restart, status operations with proper state tracking and health monitoring.", "high", "high"),
    ("3", "core-runtime", "Add persistent hook storage for session recovery", "Implement persistent storage system for OpenClaw hooks enabling session recovery after Gateway restarts, crashes, or system reboots.", "high", "high"),
    ("4", "core-runtime", "Build channel auto-configuration (WhatsApp/Telegram QR pairing)", "Create automated channel configuration system handling QR code pairing for WhatsApp and bot token setup for Telegram with interactive CLI guidance.", "high", "high"),
    ("5", "core-runtime", "Implement model failover logic (Claude → GPT → local)", "Build intelligent failover system that automatically switches between AI providers when primary is unavailable, with configurable fallback chain.", "high", "high"),
    ("6", "core-runtime", "Create workspace sync between GasTown rigs and OpenClaw", "Implement bidirectional synchronization keeping GasTown rig state and OpenClaw workspace in sync with conflict resolution.", "high", "high"),
    ("7", "core-runtime", "Add memory compaction scheduler integration", "Build scheduler that periodically compacts and optimizes memory usage for long-running Gateway instances.", "high", "high"),
    ("8", "core-runtime", "Build skill hot-reload mechanism without Gateway restart", "Implement hot-reload capability allowing skill updates without Gateway restart, enabling rapid development iteration.", "high", "high"),
    ("9", "core-runtime", "Implement secure credential injection (env var → OpenClaw gateway)", "Create secure system for injecting credentials from environment variables into OpenClaw Gateway with encryption at rest.", "high", "high"),
    ("10", "core-runtime", "Add log aggregation from OpenClaw Gateway to GasTown beads", "Build log aggregation pipeline collecting Gateway logs and storing them in GasTown bead system for centralized monitoring.", "medium", "medium"),
    ("11", "core-runtime", "Create `openclaw-launcher doctor` diagnostic command", "Implement comprehensive diagnostic command that checks system health, configuration validity, and common issues.", "medium", "medium"),
    ("12", "core-runtime", "Build version compatibility matrix (GasTown ↔ OpenClaw)", "Create compatibility checking system ensuring GasTown and OpenClaw versions work together with upgrade guidance.", "medium", "medium"),
    ("13", "core-runtime", "Implement backup/restore for OpenClaw memory and config", "Build automated backup and restore system for OpenClaw memory state and configuration with scheduled backups.", "high", "high"),
    ("14", "core-runtime", "Add cron job synchronization between GasTown and OpenClaw", "Implement synchronization of scheduled jobs between GasTown scheduler and OpenClaw cron system.", "medium", "medium"),
    ("15", "core-runtime", "Create multi-profile support (dev/staging/prod Gateways)", "Build profile management system allowing multiple Gateway configurations for different environments.", "high", "high"),
    ("16", "core-runtime", "Build API key rotation automation", "Implement automated API key rotation with zero-downtime key swapping and secure old key expiration.", "high", "high"),
    ("17", "core-runtime", "Implement Gateway resource monitoring (CPU/mem alerts)", "Create resource monitoring system tracking Gateway CPU, memory usage with configurable alerting thresholds.", "medium", "medium"),
    ("18", "core-runtime", "Add webhook bridge (OpenClaw webhooks → GasTown notifications)", "Build webhook bridge converting OpenClaw webhook events into GasTown notification system.", "medium", "medium"),
    ("19", "core-runtime", "Create state export/import for migration between machines", "Implement state portability system allowing easy migration of OpenClaw state between different machines.", "high", "high"),
    ("20", "core-runtime", "Build silent/headless mode for CI/CD integration", "Create headless mode for CI/CD pipelines with structured output and exit codes for automation.", "medium", "medium"),
    
    # UI/UX (21-40)
    ("21", "ui-ux", "Create TUI dashboard using Ratatui/Spectre.Console for launcher status", "Build rich terminal-based dashboard providing real-time visibility into launcher operations with multi-pane layout and keyboard navigation.", "high", "high"),
    ("22", "ui-ux", "Build web dashboard showing active agents, convoys, and Gateway status", "Create modern web-based dashboard with React providing comprehensive visibility into GasTown-OpenClaw ecosystem.", "high", "high"),
    ("23", "ui-ux", "Add real-time WebSocket integration for live log streaming", "Implement seamless live log streaming across all dashboard interfaces with syntax highlighting and filtering.", "medium", "medium"),
    ("24", "ui-ux", "Implement QR code terminal display for channel pairing", "Create terminal-based QR code display for quick mobile device pairing with the Gateway.", "low", "low"),
    ("25", "ui-ux", "Create interactive setup wizard (`openclaw-launcher onboard`)", "Build guided step-by-step onboarding wizard helping new users configure the launcher with validation.", "medium", "medium"),
    ("26", "ui-ux", "Add system tray/menu bar app for quick Gateway toggle", "Create lightweight system tray application providing quick access to Gateway controls and status.", "medium", "medium"),
    ("27", "ui-ux", "Build mobile-responsive PWA for remote agent monitoring", "Create Progressive Web App enabling remote monitoring and basic control from mobile devices with offline capability.", "high", "high"),
    ("28", "ui-ux", "Implement dark/light theme toggle in dashboard", "Build comprehensive theming system supporting light, dark, and system-preference modes with smooth transitions.", "low", "low"),
    ("29", "ui-ux", "Add command palette (Cmd+K) for quick actions", "Create keyboard-driven command palette providing quick access to all dashboard features with fuzzy search.", "medium", "medium"),
    ("30", "ui-ux", "Create visualization for GasTown convoy → OpenClaw execution flow", "Build interactive visual diagram showing how GasTown convoys flow through system to OpenClaw execution.", "high", "high"),
    ("31", "ui-ux", "Build skill marketplace browser with install buttons", "Create skill marketplace interface for browsing, searching, and installing skills with one-click install.", "medium", "medium"),
    ("32", "ui-ux", "Add cost tracking dashboard (API usage per model/channel)", "Implement cost tracking dashboard showing API usage breakdown by model, channel, and time period.", "medium", "medium"),
    ("33", "ui-ux", "Implement chat interface for testing Gateway without external apps", "Create built-in chat interface for testing Gateway responses without needing external messaging apps.", "medium", "medium"),
    ("34", "ui-ux", "Create notification center for errors and completions", "Build centralized notification system for errors, completions, and important events across all channels.", "medium", "medium"),
    ("35", "ui-ux", "Add search functionality across logs and configurations", "Implement global search across logs, configurations, and documentation with filters and saved searches.", "high", "high"),
    ("36", "ui-ux", "Build heatmap view for agent activity patterns", "Create heatmap visualization showing agent activity patterns over time for capacity planning.", "medium", "medium"),
    ("37", "ui-ux", "Implement drag-and-drop skill configuration", "Build intuitive drag-and-drop interface for configuring skill pipelines and dependencies.", "medium", "medium"),
    ("38", "ui-ux", "Add audio notifications for critical errors", "Implement audio notification system for critical errors and alerts with configurable sounds.", "low", "low"),
    ("39", "ui-ux", "Create exportable PDF report generator for usage stats", "Build PDF report generation for usage statistics, costs, and performance metrics.", "medium", "medium"),
    ("40", "ui-ux", "Build split-pane view (GasTown beads + OpenClaw logs)", "Create split-pane interface showing GasTown beads and OpenClaw logs side-by-side for correlation.", "high", "high"),
    
    # Infrastructure (41-60)
    ("41", "infrastructure", "Create Docker Compose with GasTown + OpenClaw + PostgreSQL stack", "Build production-ready Docker Compose orchestrating complete GasTown-OpenClaw stack with PostgreSQL and Redis.", "medium", "medium"),
    ("42", "infrastructure", "Build Kubernetes Helm chart with StatefulSet for persistence", "Create production-grade Helm chart for Kubernetes deployment with StatefulSets and autoscaling.", "high", "high"),
    ("43", "infrastructure", "Add Tailscale integration for secure remote access", "Integrate Tailscale for secure zero-config VPN access to GasTown infrastructure.", "medium", "medium"),
    ("44", "infrastructure", "Implement cloud-init scripts for VPS one-line deployment", "Create cloud-init scripts enabling one-line deployment on major VPS providers.", "medium", "medium"),
    ("45", "infrastructure", "Create GitHub Actions workflow for automated releases", "Build comprehensive CI/CD pipeline with automated testing, building, and releasing.", "high", "high"),
    ("46", "infrastructure", "Add multi-arch Docker builds (AMD64/ARM64 including Pi 5)", "Implement multi-architecture Docker builds supporting AMD64, ARM64, and ARMv7.", "medium", "medium"),
    ("47", "infrastructure", "Build Nix flake for reproducible installation", "Create Nix flake enabling reproducible installation and development environment.", "high", "high"),
    ("48", "infrastructure", "Implement automatic SSL certificate provisioning (Let's Encrypt)", "Build automatic SSL certificate provisioning and renewal with Let's Encrypt integration.", "medium", "medium"),
    ("49", "infrastructure", "Add UFW firewall auto-configuration script", "Create UFW firewall auto-configuration for secure default networking.", "low", "low"),
    ("50", "infrastructure", "Create systemd service templates with auto-restart", "Build systemd service templates with auto-restart, logging, and health checks.", "low", "low"),
    ("51", "infrastructure", "Build Windows installer (MSI) with WSL2 detection", "Create Windows MSI installer with WSL2 detection and automatic setup.", "high", "high"),
    ("52", "infrastructure", "Add macOS Homebrew formula and cask", "Create Homebrew formula and cask for easy macOS installation.", "medium", "medium"),
    ("53", "infrastructure", "Implement rolling update strategy for zero-downtime deploys", "Build rolling update strategy enabling zero-downtime deployments with health checks.", "high", "high"),
    ("54", "infrastructure", "Create health check endpoints for load balancer integration", "Implement health check endpoints for Kubernetes and load balancer integration.", "low", "low"),
    ("55", "infrastructure", "Add Prometheus metrics exporter", "Build Prometheus metrics exporter for Gateway and system metrics.", "medium", "medium"),
    ("56", "infrastructure", "Build Grafana dashboard templates", "Create pre-configured Grafana dashboards for monitoring and alerting.", "medium", "medium"),
    ("57", "infrastructure", "Implement log rotation and cleanup automation", "Build automated log rotation and cleanup to prevent disk space issues.", "low", "low"),
    ("58", "infrastructure", "Add disk space monitoring with alerting", "Implement disk space monitoring with configurable alerting thresholds.", "medium", "medium"),
    ("59", "infrastructure", "Create disaster recovery runbook automation", "Build automated disaster recovery procedures with backup verification and restoration.", "high", "high"),
    ("60", "infrastructure", "Build cross-platform installer script (detect OS/arch)", "Create universal installer script detecting OS and architecture for one-line installation.", "high", "high"),
    
    # Security (61-75)
    ("61", "security", "Implement sandboxed skill execution (gVisor/Firecracker)", "Build containerized skill execution using gVisor or Firecracker microVMs for isolation.", "high", "high"),
    ("62", "security", "Add approval gating for destructive operations", "Implement multi-tier approval system intercepting destructive operations requiring explicit confirmation.", "high", "high"),
    ("63", "security", "Build secret scanning pre-commit hooks", "Create Git pre-commit hooks preventing accidental secret leakage in commits.", "medium", "medium"),
    ("64", "security", "Implement MCP server allowlisting/denylisting", "Build policy engine controlling which MCP servers can be registered based on configurable lists.", "medium", "medium"),
    ("65", "security", "Add prompt injection detection middleware", "Implement middleware analyzing prompts for injection attacks and blocking suspicious input.", "high", "high"),
    ("66", "security", "Create audit log for all agent actions", "Build comprehensive audit logging system recording all agent activities with tamper-evident storage.", "medium", "medium"),
    ("67", "security", "Implement RBAC for multi-user setups", "Create Role-Based Access Control system for managing permissions in multi-user deployments.", "high", "high"),
    ("68", "security", "Add automatic security patch notifications", "Build automated system monitoring dependencies for security vulnerabilities and notifying administrators.", "medium", "medium"),
    ("69", "security", "Build encrypted at-rest storage for sensitive configs", "Implement encryption for all sensitive configuration data stored on disk with secure key management.", "high", "high"),
    ("70", "security", "Implement network isolation between Gateway and skills", "Build network segmentation isolating skill execution environments from Gateway and external networks.", "high", "high"),
    ("71", "security", "Add fail2ban integration for Gateway protection", "Integrate fail2ban intrusion prevention system protecting Gateway from brute-force attacks.", "medium", "medium"),
    ("72", "security", "Create security manifest generator for skills", "Build automated tool generating security manifests for skills documenting capabilities and risks.", "high", "high"),
    ("73", "security", "Implement input sanitization for all user-provided paths", "Create comprehensive input sanitization preventing path traversal and injection attacks.", "medium", "medium"),
    ("74", "security", "Add dependency vulnerability scanning in CI", "Implement dependency vulnerability scanning in CI pipeline with automated alerts.", "medium", "medium"),
    ("75", "security", "Build automated security benchmark runner (CIS compliance)", "Create automated security benchmark runner checking CIS compliance and best practices.", "high", "high"),
    
    # Integrations (76-90)
    ("76", "integration", "Create ClawHub skill registry integration", "Build integration with ClawHub skill registry for discovering and installing community skills.", "high", "high"),
    ("77", "integration", "Add MCP server auto-discovery and configuration", "Implement automatic MCP server discovery and configuration with service mesh integration.", "medium", "medium"),
    ("78", "integration", "Implement Gmail Pub/Sub webhook handler", "Create Gmail Pub/Sub integration for processing emails and triggering workflows.", "high", "high"),
    ("79", "integration", "Build Slack Bolt app for Gateway control commands", "Build Slack Bolt application enabling Gateway control through Slack commands and notifications.", "high", "high"),
    ("80", "integration", "Add Discord bot integration for agent monitoring", "Create Discord bot providing agent monitoring and control through Discord.", "medium", "medium"),
    ("81", "integration", "Create Home Assistant integration for IoT triggers", "Build Home Assistant integration enabling IoT device triggers and automations.", "high", "high"),
    ("82", "integration", "Implement n8n workflow node for OpenClaw", "Create n8n workflow node enabling OpenClaw integration in n8n automation workflows.", "medium", "medium"),
    ("83", "integration", "Add Zapier webhook receiver skill template", "Build Zapier webhook receiver skill template for easy Zapier integration.", "medium", "medium"),
    ("84", "integration", "Build GitHub App for PR/code review automation", "Create GitHub App enabling PR automation and code review assistance.", "high", "high"),
    ("85", "integration", "Implement Obsidian plugin for note synchronization", "Build Obsidian plugin synchronizing notes with OpenClaw memory and context.", "high", "high"),
    ("86", "integration", "Add browser extension for quick skill invocation", "Create browser extension enabling quick skill invocation from any webpage.", "medium", "medium"),
    ("87", "integration", "Create VS Code extension for agent management", "Build VS Code extension for managing agents and viewing status within the editor.", "medium", "medium"),
    ("88", "integration", "Build iOS Shortcut actions for voice triggers", "Create iOS Shortcut actions enabling voice-triggered agent commands.", "high", "high"),
    ("89", "integration", "Implement Matrix bot for decentralized chat control", "Build Matrix bot enabling decentralized chat-based agent control.", "medium", "medium"),
    ("90", "integration", "Add BlueBubbles integration for iMessage automation", "Create BlueBubbles integration enabling iMessage-based agent interactions.", "medium", "medium"),
    
    # Testing & QA (91-100)
    ("91", "testing", "Build integration test suite with TestContainers", "Create comprehensive integration test suite using TestContainers for realistic testing.", "high", "high"),
    ("92", "testing", "Add end-to-end tests for all channel integrations", "Implement end-to-end tests covering all messaging channel integrations.", "high", "high"),
    ("93", "testing", "Implement chaos engineering tests (random Gateway restarts)", "Build chaos engineering tests randomly restarting Gateway to test resilience.", "high", "high"),
    ("94", "testing", "Create load testing harness for concurrent agents", "Implement load testing harness simulating hundreds of concurrent agents.", "high", "high"),
    ("95", "testing", "Add snapshot testing for TUI output", "Create snapshot testing for Terminal UI ensuring consistent rendering.", "medium", "medium"),
    ("96", "testing", "Build accessibility audit automation for dashboard", "Implement automated accessibility auditing for web dashboard ensuring WCAG compliance.", "medium", "medium"),
    ("97", "testing", "Implement property-based testing for configuration parsing", "Build property-based testing for configuration parsing using generative testing.", "medium", "medium"),
    ("98", "testing", "Add performance regression benchmarks in CI", "Create performance regression benchmarks running in CI to catch performance degradation.", "medium", "medium"),
    ("99", "testing", "Create manual QA checklist generator for releases", "Build manual QA checklist generator creating release-specific testing checklists.", "medium", "medium"),
    ("100", "testing", "Build automated documentation sync from code changes", "Implement automated documentation synchronization triggered by code changes.", "high", "high"),
]

def create_issue(number, category, title, description, priority, effort):
    """Create a GitHub issue via API"""
    url = f"{API_BASE}/repos/{REPO}/issues"
    
    category_labels = {
        "core-runtime": "polecat-1",
        "ui-ux": "polecat-2",
        "infrastructure": "polecat-3",
        "security": "polecat-4",
        "integration": "polecat-4",
        "testing": "polecat-4"
    }
    
    labels = ["improvement", category, f"priority: {priority}", category_labels.get(category, "")]
    labels = [l for l in labels if l]
    
    body = f"""## Improvement #{number}

### Category
{category}

### Description
{description}

### Priority
{priority}

### Estimated Effort
{effort}

### Implementation Checklist
- [ ] Review existing codebase for integration points
- [ ] Create implementation plan
- [ ] Write tests (TDD approach)
- [ ] Implement feature
- [ ] Update documentation
- [ ] Code review
- [ ] Merge to main

### Acceptance Criteria
- [ ] Feature is implemented according to specification
- [ ] All tests pass
- [ ] Documentation is updated
- [ ] Code review is approved
- [ ] No regressions introduced

---
*This issue was auto-generated by the Kimi Swarm contribution system.*
"""
    
    payload = {
        "title": f"[IMPROVEMENT] {title} (#{number})",
        "body": body,
        "labels": labels
    }
    
    try:
        response = requests.post(url, headers=headers, json=payload, timeout=30)
        if response.status_code == 201:
            return True, response.json().get("number")
        else:
            return False, f"HTTP {response.status_code}: {response.text}"
    except Exception as e:
        return False, str(e)

def main():
    if not GITHUB_TOKEN:
        print("Error: GITHUB_TOKEN environment variable not set")
        print("Usage: export GITHUB_TOKEN='your_token_here'")
        sys.exit(1)
    
    start_idx = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    end_idx = int(sys.argv[2]) if len(sys.argv) > 2 else len(improvements)
    
    batch = improvements[start_idx:end_idx]
    
    print(f"Creating {len(batch)} GitHub issues ({start_idx+1} to {end_idx})...")
    print("=" * 70)
    
    completed = []
    failed = []
    
    for i, improvement in enumerate(batch):
        number, category, title, description, priority, effort = improvement
        actual_idx = start_idx + i + 1
        
        print(f"[{actual_idx}/{end_idx}] #{number}: {title[:45]}...", end=" ", flush=True)
        
        success, result = create_issue(number, category, title, description, priority, effort)
        
        if success:
            completed.append((number, result))
            print(f"✅ Created #{result}")
        else:
            failed.append((number, result))
            print(f"❌ Failed: {result}")
        
        # Rate limiting: 2 second delay between requests
        if i < len(batch) - 1:
            time.sleep(2)
        
        # Progress update every 5 issues
        if (i + 1) % 5 == 0:
            print(f"\n📊 Progress: {actual_idx}/{end_idx} | ✅ {len(completed)} | ❌ {len(failed)}")
            print("-" * 70)
    
    print("\n" + "=" * 70)
    print("Batch Complete!")
    print(f"✅ Successfully created: {len(completed)}")
    print(f"❌ Failed: {len(failed)}")
    
    if failed:
        print("\nFailed issues:")
        for number, error in failed:
            print(f"  - #{number}: {error}")
    
    # Save state
    with open("issue_creation_state.json", "w") as f:
        json.dump({
            "completed": completed,
            "failed": failed,
            "start_idx": start_idx,
            "end_idx": end_idx
        }, f, indent=2)
    
    print(f"\nState saved to issue_creation_state.json")

if __name__ == "__main__":
    main()
