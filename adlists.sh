#!/bin/bash

# update pihole
sqlite3 /etc/pihole/gravity.db "SELECT Address FROM adlist" |sort >pihole.list
echo "https://www.github.developerdan.com/hosts/lists/ads-and-tracking-extended.txt" >>temp.list
echo "https://mirror1.malwaredomains.com/files/justdomains" >>temp.list
echo "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" >>temp.list
sort temp.list >all.list
comm -23 pihole.list all.list |xargs -I{} sudo sqlite3 /etc/pihole/gravity.db "DELETE FROM adlist WHERE Address='{}';"
comm -13 pihole.list all.list |xargs -I{} sudo sqlite3 /etc/pihole/gravity.db "INSERT INTO adlist (Address,Comment,Enabled) VALUES ('{}','Script added `date +%F`',1);"
rm all.list temp.list pihole.list
pihole restartdns reload-lists
pihole -g
