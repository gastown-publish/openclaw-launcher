#!/bin/bash
# Force immediate plugin update

curl -X POST http://localhost:8080/update-plugins
echo "Plugin update triggered"
