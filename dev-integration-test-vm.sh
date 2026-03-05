#!/bin/bash
echo "Integration test........"

# Replace this with the actual VM instance URL or IP address
URL="node01"

if [[ -n "$URL" ]]; then
    ping -c 3 $URL  # Test connectivity with the VM
    
    # Retry loop to handle intermittent connectivity issues
    for i in {1..5}; do
        echo "Attempting to reach $URL:3000/live (Attempt $i)"
        http_code=$(curl -v -s -o /dev/null -w "%{http_code}" "$URL:3000/live")
        
        if [[ "$http_code" -eq 200 ]]; then
            echo "Connection successful on attempt $i"
            break
        else
            echo "Connection failed with HTTP Code: $http_code. Retrying in 3 seconds..."
            sleep 3
        fi
    done

    # Retrieve and parse the planet data
    planet_data=$(curl -v -s -XPOST "$URL:3000/planet" -H "Content-Type: application/json" -d '{"id": "3"}')
    planet_name=$(echo $planet_data | jq .name -r)

    echo "HTTP Code: $http_code"
    echo "Planet Name: $planet_name"

    # Check if both the HTTP code and planet name match expected values
    if [[ "$http_code" -eq 200 && "$planet_name" == "Earth" ]]; then
        echo "HTTP Status Code and Planet Name Tests Passed"
    else
        echo "One or more test(s) failed"
        exit 1
    fi
else
    echo "Issues with URL; Check/Debug line 4"
    exit 1
fi