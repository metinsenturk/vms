#!/bin/bash

# 1. Check if the container is actually running
if ! docker ps | grep -q pihole; then
    echo "❌ Error: Pi-hole container is not running."
    exit 1
fi

# 2. Verify FTL picked up the environment variable
LOG_CHECK=$(docker logs pihole 2>&1 | grep "FTLCONF_misc_dnsmasq_lines")

if echo "$LOG_CHECK" | grep -q "\[✓\]"; then
    echo "✅ Success: Pi-hole v6 engine has loaded the wildcard DNS lines."
    echo "   Details: $LOG_CHECK"
else
    echo "⚠️ Warning: Wildcard DNS environment variable was NOT found or was ignored."
    echo "   Check your apps/pihole/.env file and docker-compose.yml."
    exit 1
fi

# 3. Functional DNS check (The real truth)
echo "🔍 Testing internal resolution for anything.hub.local..."
DIG_RESULT=$(dig @127.0.0.1 anything.hub.local +short)

if [ "$DIG_RESULT" == "192.168.1.138" ]; then
    echo "✅ Functional Test Passed: anything.hub.local -> $DIG_RESULT"
else
    echo "❌ Functional Test Failed: Expected 192.168.1.138 but got '$DIG_RESULT'"
    exit 1
fi