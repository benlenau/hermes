#!/bin/bash
docker pull pihole/pihole:latest

printf "\nRemoving previous Pi-hole installation... "
docker stop pihole && docker rm pihole

printf "\nInstalling Pi-hole... "

# Create custom dnsmasq records and settings file (required)
[ ! -f $(pwd)/dnsmasq.conf ] && touch $(pwd)/dnsmasq.conf
[ ! -f $(pwd)/hermes.env ] && touch $(pwd)/hermes.env

docker run -d $(cat hermes_network.conf) \
	--name pihole \
	-p 0.0.0.0:53:53/tcp \
	-p 0.0.0.0:53:53/udp \
	-v $(pwd)/adlists.sh:/home/adlists.sh:ro \
	-v $(pwd)/config/:/etc/pihole/ \
	-v $(pwd)/dnsmasq.conf:/etc/dnsmasq.d/10-custom-dnsmasq.conf:ro \
	--dns=127.0.0.1 \
	--dns=1.1.1.1 \
	--restart=unless-stopped \
	--hostname=$(hostname) \
	--env-file=$(pwd)/hermes.env \
	pihole/pihole:latest

printf "\nPlease wait for Pi-hole Docker container to finish installation"

# Healthcheck of newly established Docker-container and continue when healthy
for i in $(seq 1 60); do
	if [ "$(docker inspect -f "{{.State.Health.Status}}" pihole)" = "healthy" ] ; then
        	printf ' OK\n\n'
		break
	else
		sleep 1
		printf '.'
	fi
done

# Exit if healthcheck fails
[ $i -eq 60 ] && printf "\nTimeout! Please consult Pi-hole container logs for more info (\`docker logs pihole\`)" && exit 1

# Custom DNS records.
[ -f $(pwd)/custom.list ] && docker cp $(pwd)/custom.list pihole:/etc/pihole/custom.list

# Run adlists.sh inside Docker container to add and update adlists from other sources.
[ -f $(pwd)/adlists.sh ] && docker exec pihole sh /home/adlists.sh

# Run Pi-hole DNS restart inside Docker container to make install changes permanent
docker exec pihole pihole restartdns
