#!/bin/bash
DNS1=192.168.1.1 # Change this to your preferred DNS provider
DNS2=192.168.1.1 # Change this to your preferred DNS provider
DNSMASQ_USER=root # Change user running dns to either pihole (increase security) or root
name=hermes # Docker host name
httpip=192.168.1.2 # Host interface IP HTTP container availability
httpport=8080
dnsip=0.0.0.0 # Host interface IP DNS container availability
dnsport=53

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
        --dns=192.168.1.1 \
        --restart=unless-stopped \
	--hostname=$name \
        -e WEBPASSWORD="" \
	-e DNSMASQ_USER=$DNSMASQ_USER \
	-e VIRTUAL_HOST=$name \
	-e PIHOLE_DNS_="$DNS1;$DNS2" \
        -e DNS_FQDN_REQUIRED="false" \
        -e DNS_BOGUS_PRIV="false" \
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
