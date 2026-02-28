# Contributing to OpenClaw Launcher

Thank you for your interest in contributing to OpenClaw Launcher! This document provides guidelines and workflows for contributing to the project.

## 🦞 Swarm Architecture

This project uses a multi-agent "swarm" approach with specialized roles:

| Agent | Role | Focus Area |
|-------|------|------------|
| **Mayor** | Orchestrator | PR review, conflict resolution, roadmap maintenance |
| **Polecat-1** | Core Runtime | Gateway lifecycle, CLI, process management |
| **Polecat-2** | UI/UX | Dashboard, TUI, web interfaces |
| **Polecat-3** | Infrastructure | Docker, K8s, CI/CD, deployment |
| **Polecat-4** | Integration | MCP servers, webhooks, third-party services |

## Getting Started

### Prerequisites

- Git 2.30+
- GitHub CLI (`gh`)
- Node.js 18+ (for development)
- Docker (for infrastructure work)

### Repository Setup

```bash
# Clone the repository
git clone https://github.com/gastown-publish/openclaw-launcher.git
cd openclaw-launcher

# Install dependencies
npm install

# Set up GitHub CLI (optional but recommended)
gh auth login
```

## Workflow

### 1. Claim an Issue

Browse open issues and claim one that matches your specialization:

```bash
# List issues for your role
gh issue list --label "polecat-1"  # or polecat-2, polecat-3, polecat-4

# Claim an issue
gh issue comment <number> --body "🦞 Claimed by [your-handle]. Starting implementation."
```

### 2. Create a Branch

Use the naming convention: `feature/[improvement-id]-brief-description`

```bash
git checkout -b feature/042-gateway-lifecycle-manager
```

### 3. Development

#### Test-Driven Development (TDD)

1. Write failing tests first
2. Implement minimum code to pass
3. Refactor while keeping tests green

```bash
# Run tests
npm test

# Run tests in watch mode
npm run test:watch

# Run linter
npm run lint
```

#### Code Standards

- **Bash scripts**: Must use `set -euo pipefail`
- **TypeScript**: Follow ESLint configuration
- **Commits**: Use conventional commit format
- **Documentation**: Update relevant docs with changes

### 4. Commit Changes

Use conventional commit format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

Types:
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation
- `style` - Formatting
- `refactor` - Code restructuring
- `test` - Adding tests
- `chore` - Maintenance

Example:
```bash
git commit -m "feat(gateway): Add lifecycle manager

- Implement start/stop/restart operations
- Add health monitoring
- Include PID tracking

Closes #42"
```

### 5. Submit Pull Request

```bash
# Push branch
git push -u origin feature/042-gateway-lifecycle-manager

# Create PR using template
gh pr create --title "feat(gateway): Add lifecycle manager (#42)" \
             --body-file .github/PULL_REQUEST_TEMPLATE.md
```

PR Requirements:
- Fill out the PR template completely
- Link related issues
- Ensure all checks pass
- Request review from Mayor

## Quality Gates

All contributions must pass:

- [ ] Code follows style guidelines
- [ ] Tests written and passing
- [ ] Documentation updated
- [ ] No linting errors
- [ ] PR template complete
- [ ] Issue linked
- [ ] Review approved by Mayor

## Definition of Done

A task is complete when:

1. Code merged to `main`
2. Issue closed with PR reference
3. Documentation updated
4. Tests passing in CI
5. No regressions introduced

## Escalation

If blocked for more than 1 hour:

1. Comment on issue with problem details
2. Tag `@mayor` for assistance
3. Include error messages and attempted solutions

## Communication

- **Daily standups**: Comment on your active issues
- **Blockers**: Report immediately
- **Questions**: Ask in issue comments
- **Status updates**: Every 4 hours of active work

## Labels

| Label | Meaning |
|-------|---------|
| `polecat-1` | Core Runtime tasks |
| `polecat-2` | UI/UX tasks |
| `polecat-3` | Infrastructure tasks |
| `polecat-4` | Integration tasks |
| `good first issue` | Beginner-friendly |
| `priority: high` | High priority |
| `needs: template update` | PR needs work |

## Resources

- [Project Roadmap](./ROADMAP.md)
- [Architecture Documentation](./docs/architecture.md)
- [API Reference](./docs/api.md)
- [Development Guide](./docs/development.md)

## Code of Conduct

- Be respectful and constructive
- Welcome newcomers
- Focus on the problem, not the person
- Assume good intentions

## Questions?

- Open a [discussion](https://github.com/gastown-publish/openclaw-launcher/discussions)
- Comment on related issue
- Email: dev@gastown.games

---

Happy contributing! 🦞
