# OpenClaw Skills

Skills are installed at runtime into each sub-instance from ClawHub.

## Maton-Powered Skills (auto-installed on first boot)

These skills use the Maton API Gateway for OAuth-managed access:

| Skill | Description |
|-------|-------------|
| api-gateway | Connect to 100+ APIs via gateway.maton.ai |
| gmail | Gmail read, send, manage labels |
| google-docs | Create and edit Google Docs |
| google-sheets | Read and write spreadsheets |
| google-drive | List, search, upload, download files |
| google-calendar-api | Create and manage calendar events |
| google-contacts | Manage contacts |
| google-slides | Create presentations |
| google-meet | Create meeting spaces |
| google-tasks-api | Manage task lists |
| google-forms | Create and manage forms |

## Adding Custom Skills

Place SKILL.md files in `/home/openclaw/.openclaw/workspace/skills/<skill-name>/`
inside the running instance, or install via `clawhub install <slug>`.
