#!/bin/bash
# Trigger immediate OpenClaw upgrade across all instances
curl -s -X POST http://localhost:8080/upgrade
echo "Upgrade triggered"
