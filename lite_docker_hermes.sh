#!/bin/bash
# This script starts a Pi-hole container.

# Backup previous install custom.list
[ -f $(pwd)/config/custom.list ] && printf "Backup custom.list-file from previous Pi-hole installation.\n" && cp $(pwd)/config/custom.list $(pwd)/custom.list

printf "Removing previous Pi-hole installation."
docker stop pihole >/dev/null 2>&1 && docker rm pihole >/dev/null 2>&1 && rm -rf config/

printf "\nPulling latest Pi-hole image."
docker pull pihole/pihole:latest >/dev/null 2>&1

# Create custom dnsmasq records and settings file (required).
printf "\nCreating files."
[ ! -f $(pwd)/dnsmasq.conf ] && touch $(pwd)/dnsmasq.conf
[ ! -f $(pwd)/hermes.env ] && touch $(pwd)/hermes.env
[ ! -f $(pwd)/hermes.conf ] && echo "-p 0.0.0.0:8080:80/tcp --hostname=$(hostname)" > $(pwd)/hermes.conf

printf "\nInstalling Pi-hole."

docker run -d $(cat hermes.conf) \
	--name=pihole \
	--dns=127.0.0.1 \
	--dns=1.1.1.1 \
	--env-file=$(pwd)/hermes.env \
	-p 0.0.0.0:53:53/tcp \
	-p 0.0.0.0:53:53/udp \
	-v $(pwd)/adlists.sh:/home/adlists.sh:ro \
	-v $(pwd)/config/:/etc/pihole/ \
	-v $(pwd)/dnsmasq.conf:/etc/dnsmasq.d/10-custom-dnsmasq.conf:ro \
	-v /etc/localtime:/etc/localtime:ro \
	--restart=unless-stopped \
	pihole/pihole:latest >/dev/null 2>&1

# Healthcheck of newly established Docker-container and continue when healthy.
for i in $(seq 1 60); do
        if [ "$(docker inspect -f "{{.State.Health.Status}}" pihole)" = "healthy" ] ; then
                printf 'OK'
                break
        else
                sleep 1
                printf '.'
        fi
done

# Stop and exit if healthcheck fails.
[ $i -eq 60 ] && printf "\nTimeout! Please consult Pi-hole container logs for more info (\`docker logs pihole\`)" && exit 1

# Custom DNS records.
[ -f $(pwd)/custom.list ] && docker cp $(pwd)/custom.list pihole:/etc/pihole/custom.list

# Add sites to whitelist.
printf "\nAdding whitelists."

docker exec pihole pihole --white-regex \
	"(\.|^)apple\.com$" \
	"(\.|^)instagram\.com$" \
	"(\.|^)gstatic\.com$" \
	"(\.|^)gvt2\.com$" \
	"(\.|^)gvt3\.com$" \
	"(\.|^)microsoft\.com$" \
	"(\.|^)msecnd\.net$" \
	"(\.|^)omtrdc\.net$" \
	"(\.|^)t\.co$" \
	"(\.|^)ui\.com$" \
	"(\.|^)youtube\.com$" \
	"(\.|^)app-measurement\.com$" \
	"(\.|^)roblox\.com$" \
	--comment "Hermes Lite Default" >/dev/null 2>&1

# Run Pi-hole DNS restart inside Docker container to make install changes permanent.
sleep 1 && docker exec pihole pihole restartdns

printf "\nDone!\n"
