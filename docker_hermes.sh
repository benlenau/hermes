#!/bin/bash

# Check and load hermes.conf-file if present
if [ -f $(pwd)/hermes.conf ]; then . $(pwd)/hermes.conf; fi

DNS1=${DNS1:-1.1.1.1} 		# Change this to your preferred DNS provider
DNS2=${DNS2:-1.0.0.1} 		# Change this to your preferred DNS provider
httpport=${httpport:-8080} 	# Pihole HTTP port (default 8080)
dnsport=${dnsport:-53} 		# DNS Port (default 53)
httpip=${httpip:-0.0.0.0}	# Host interface IP HTTP container availability (default all)
dnsip=${dnsip:-0.0.0.0}		# Host interface IP DNS container availability (default all)
name=${name:-$(hostname)}	# Docker host name

# Update to latest Pi-hole container image
docker pull pihole/pihole:latest

echo
read -p "Stop and delete current Pi-hole Docker install? [yN] " yn
case $yn in
	Y | y ) echo
	echo "Removing Pi-hole"
	docker stop pihole
	docker rm pihole;;
	* ) exit 1;;
esac

echo
echo "Installing Pi-hole on HTTP: $httpip:$httpport and DNS: $dnsip:$dnsport"

echo
docker run -d \
        --name pihole \
        -p $dnsip:$dnsport:53/tcp \
        -p $dnsip:$dnsport:53/udp \
        -p $httpip:$httpport:80 \
        -v /etc/localtime:/etc/localtime:ro \
	-v "$(pwd)/adlists.sh:/home/adlists.sh:ro" \
	-v "$(pwd)/config/etc-pihole/:/etc/pihole/" \
	-v "$(pwd)/config/etc-dnsmasq.d/:/etc/dnsmasq.d/" \
        --dns=1.1.1.1 \
	--dns=1.0.0.1 \
        --restart=unless-stopped \
	--hostname=$name \
        -e WEBPASSWORD="" \
	-e PIHOLE_DNS_="$DNS1;$DNS2" \
        -e DNS_FQDN_REQUIRED="true" \
        -e DNS_BOGUS_PRIV="true" \
        -e REV_SERVER="true" \
        -e REV_SERVER_CIDR="192.168.0.0/16" \
        -e REV_SERVER_TARGET="192.168.1.1" \
	-e FTLCONF_MAXDBDAYS=7 \
	-e FTLCONF_DBINTERVAL=5 \
	-e FTLCONF_BLOCK_ICLOUD_PR=true \
	pihole/pihole:latest

echo
printf "Please wait for Pi-hole Docker container to finish installation"

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
if [ $i -eq 60 ] ; then
	echo "\nTimeout! Please consult Pi-hole container logs for more info (\`docker logs pihole\`)"
	exit 1
fi

# Custom DNS records.
if [ -f $(pwd)/custom.list ]; then
	docker cp $(pwd)/custom.list pihole:/etc/pihole/custom.list
fi

# Custom dnsmasq records.
if [ -f $(pwd)/10-custom-dnsmasq.conf ]; then
	docker cp $(pwd)/10-custom-dnsmasq.conf pihole:/etc/dnsmasq.d/
fi

# Run adlists.sh inside Docker container to add and update adlists from other sources.
if [ -f $(pwd)/adlists.sh ]; then
	docker exec pihole sh /home/adlists.sh
fi

# Run Pi-hole DNS restart inside Docker container to make install changes permanent
docker exec pihole pihole restartdns
