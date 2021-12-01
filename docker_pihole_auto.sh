#!/bin/bash
DNS1=1.1.1.1        # Change this to your preferred DNS provider
DNS2=1.0.0.1  # Change this to your preferred DNS provider
DNSMASQ_USER=pihole  # Change user running dns to either pihole (increase security) or root
httpport=8080        # Pihole HTTP port (default 8080)
dnsport=53           # DNS Port (default 53)

# Check if ips.conf-file is present
if [ -f $(pwd)/hermes.conf ]; then
        . $(pwd)/hermes.conf
else
        httpip=0.0.0.0    # Host interface IP HTTP container availability
	dnsip=0.0.0.0     # Host interface IP DNS container availability
	name=$(hostname)  # Docker host name
fi

# Update to latest Pi-hole container image
docker pull pihole/pihole:latest

echo
read -p "Do you wish to stop and delete the current $name Docker install? [yN] " yn
case $yn in
	Y | y ) echo
	echo "Removing $name"
	docker stop $name
	docker rm $name;;
	* ) exit 1;;
esac

echo
echo "Installing... SERVER: $name / HTTP: $httpip:$httpport / DNS: $dnsip:$dnsport"

echo
docker run -d \
        --name $name \
        -p $dnsip:$dnsport:53/tcp \
        -p $dnsip:$dnsport:53/udp \
        -p $httpip:$httpport:80 \
        -e TZ="Europe/Copenhagen" \
	-v "$(pwd)/adlists.sh:/home/adlists.sh:ro" \
	-v "$(pwd)/config/etc-pihole/:/etc/pihole/" \
	-v "$(pwd)/config/etc-dnsmasq.d/:/etc/dnsmasq.d/" \
        --dns=1.1.1.1 \
	--dns=1.0.0.1 \
        --restart=unless-stopped \
	--hostname=$name \
        -e WEBPASSWORD="" \
	-e DNSMASQ_USER=$DNSMASQ_USER \
	-e VIRTUAL_HOST=$name \
	-e PIHOLE_DNS_="$DNS1;$DNS2" \
        -e DNS_FQDN_REQUIRED="true" \
        -e DNS_BOGUS_PRIV="true" \
        -e REV_SERVER="true" \
        -e REV_SERVER_CIDR="192.168.0.0/16" \
        -e REV_SERVER_TARGET="192.168.1.1" \
	pihole/pihole:latest

echo
printf "Please wait for Pi-hole Docker container to finish install"

for i in $(seq 1 60); do
    if [ "$(docker inspect -f "{{.State.Health.Status}}" $name)" = "healthy" ] ; then
        printf ' OK\n\n'
	break
    else
        sleep 1
        printf '.'
    fi
done

# Exit if healthcheck fails
if [ $i -eq 60 ] ; then
	echo "\nTimed out waiting for $name to start! Please consult container logs for more info (\`docker logs $name\`)"
	exit 1
fi

# Add custom DNS records.
if [ -f $(pwd)/custom.list ]; then
	docker cp $(pwd)/custom.list $name:/etc/pihole/custom.list
fi

# Add custom dnsmasq records.
if [ -f $(pwd)/10-custom-dnsmasq.conf ]; then
	docker cp $(pwd)/10-custom-dnsmasq.conf $name:/etc/dnsmasq.d/
fi

# Run adlists.sh inside Docker container to add and update adlists from other sources.
if [ -f $(pwd)/adlists.sh ]; then
	docker exec $name sh /home/adlists.sh
fi

# Run Pi-hole DNS restart inside Docker container to make install changes permanent
docker exec $name pihole restartdns
