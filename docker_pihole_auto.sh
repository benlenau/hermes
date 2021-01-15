#!/bin/bash

#Default values
DNS1=192.168.1.1 # Change this to your preferred DNS provider
DNS2=192.168.1.1 # Change this to your preferred DNS provider
name=${1:-hermes}
httpip=${2:-0.0.0.0}
dnsip=${3:-0.0.0.0}
dnsport=${4:-53}
httpport=${5:-8080}

echo
echo "---- Current path: $(pwd) ----"

echo
read -p "Please enter Pi-Hole Server Name [$name]: "
name=${REPLY:-$name}

read -p "Please enter HTTP IP for Pi-hole Server [$httpip]: "
httpip=${REPLY:-$httpip}

read -p "Please enter DNS IP for Pi-hole Server [$dnsip]: "
dnsip=${REPLY:-$dnsip}

read -p "Please enter DNS port number [$dnsport]: "
dnsport=${REPLY:-$dnsport}

read -p "Please enter HTTP port number [$httpport]: "
httpport=${REPLY:-$httpport}

echo
while true; do
    read -p "Do you wish to stop and delete previous $name docker install? " yn
    case $yn in
        [Yy]* ) echo
                echo "Removing $name"
                docker stop $name
                docker rm $name; break;;
        [Nn]* ) break;;
        * ) echo "Please answer [y]es or [n]o.";;
    esac
done

echo
while true; do
    read -p "SERVER: $name / HTTP: $httpip:$httpport / DNS: $dnsip:$dnsport / INSTALL PATH: $(pwd) - Is this correct? " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit 0;;
        * ) echo "Please answer [y]es or [n]o.";;
    esac
done

echo
echo "Updating Pi-hole container image (pihole/pihole:latest)..."
docker pull pihole/pihole:latest

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
        --dns-search="localdomain" \
        --dns-search="iot" \
        --dns-search="svr" \
        --dns-search="guest" \
        -e WEBPASSWORD="" \
	-e DNSMASQ_USER=pihole \
        -e VIRTUAL_HOST=$name \
	-e PIHOLE_DNS_="$DNS1;$DNS2" \
        -e DNS_FQDN_REQUIRED="false" \
        -e DNS_BOGUS_PRIV="false" \
	-e CONDITIONAL_FORWARDING="true" \
	-e CONDITIONAL_FORWARDING_IP="192.168.1.1" \
        pihole/pihole:latest

echo
printf "Please wait for container install to finish"

for i in $(seq 1 60); do
    if [ "$(docker inspect -f "{{.State.Health.Status}}" $name)" == "healthy" ] ; then
        printf ' OK\n\n'
	break;
    else
        sleep 1
        printf '.'
    fi

    if [ $i -eq 60 ] ; then
        echo -e "\nTimed out waiting for $name to start! Please consult container logs for more info (\`docker logs $name\`)"
        exit 1
    fi
done;

# Add local DNS records.
docker cp $(pwd)/custom.list $name:/etc/pihole/custom.list

# Running adlists.sh inside Pi-hole docker container
docker exec $name /home/adlists.sh

echo
echo "Done!"
