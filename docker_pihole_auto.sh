#!/bin/bash

#default values
name=hermes
httpip=192.168.1.3
dnsip=0.0.0.0
dnsport=53
httpport=8080

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
                docker rm $name
                rm etc-* -r; break;;
        [Nn]* ) break;;
        * ) echo "Please answer [y]es or [n]o.";;
    esac
done

echo
while true; do
    read -p "SERVER: $name / HTTP: $httpip:$httpport / DNS: $dnsip:$dnsport / INSTALL PATH: $(pwd) - Is this correct? " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer [y]es or [n]o.";;
    esac
done

echo
echo "Updating container image to latest..."
docker pull pihole/pihole:latest

echo
echo "Installing... SERVER: $name / HTTP: $httpip:$httpport / DNS: $dnsip:$dnsport"

echo
docker run -d \
        --name $name \
        -p $dnsip:$dnsport:53 \
        -p $dnsip:$dnsport:53/udp \
        -p $httpip:$httpport:80 \
        -e TZ="Europe/Copenhagen" \
        -v "$(pwd)/etc-pihole/:/etc/pihole/" \
        -v "$(pwd)/etc-dnsmasq.d/:/etc/dnsmasq.d/" \
        --dns=192.168.1.1 \
        --restart=unless-stopped \
        --hostname=$name \
        --dns-search=localdomain \
        -e WEBPASSWORD="" \
        -e VIRTUAL_HOST=$name \
        -e PROXY_LOCATION=$name \
        -e DNS1="172.17.0.4" \
        -e DNS2="1.1.1.1" \
	-e DNS_FQDN_REQUIRED="true" \
	-e DNSSEC="false" \
	-e DNS_BOGUS_PRIV="true" \
        -e CONDITIONAL_FORWARDING="true" \
        -e CONDITIONAL_FORWARDING_IP="192.168.1.1" \
        -e CONDITIONAL_FORWARDING_DOMAIN="localdomain" \
        pihole/pihole:latest

echo
echo "Please for container install to finish "

for i in $(seq 1 40); do
    if [ "$(docker inspect -f "{{.State.Health.Status}}" $name)" == "healthy" ] ; then
        printf ' OK'
    else
        sleep 2
        printf '.'
    fi

    if [ $i -eq 40 ] ; then
        echo -e "\nTimed out waiting for Pi-hole start, consult check your container logs for more info (\`docker logs pihole\`)"
        exit 1
    fi
done;

echo
echo
echo "Adding whitelists..."

docker exec $name pihole --white-regex "(\.|^)microsoft\.com$" "(\.|^)gvt3\.com$" "(\.|^)gvt2\.com$" "(\.|^)gstatic\.com$" "(\.|^)youtube\.com$"

echo
echo "Adding TLD blacklists..."
docker exec $name pihole --regex ".ru$" ".work$" ".fit$" ".casa$" ".loan$" ".cf$" ".tk$" ".rest$" ".ml$" ".london$" ".top$"

echo
echo "Adding local DNS records"
cp $(pwd)/custom.list etc-pihole/

echo
echo "Adding and running adlists.sh (if present)..."
docker cp $(pwd)/adlists.sh $name:/home
docker exec $name /home/adlists.sh

echo
echo "Done!"
