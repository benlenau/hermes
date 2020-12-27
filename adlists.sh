#!/bin/bash

# Export already added adlists
sqlite3 /etc/pihole/gravity.db "SELECT Address FROM adlist" |sort >pihole.list

# Uncomment the following lines if you want more adlists added
# The folloing wget-line is special because it first needs to be downloaded and sorted before being in a format that Pi-hole accepts
#wget -qO - https://v.firebog.net/hosts/lists.php?type=tick | sort >>temp.list
#echo "https://block.energized.pro/ultimate/formats/hosts.txt" >>temp.list
echo "https://www.github.developerdan.com/hosts/lists/ads-and-tracking-extended.txt" >>temp.list
echo "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" >>temp.list
sort temp.list >all.list

# Add adlists to Pi-hole database
comm -23 pihole.list all.list | xargs -I{} sudo sqlite3 /etc/pihole/gravity.db "DELETE FROM adlist WHERE Address='{}';"
comm -13 pihole.list all.list | xargs -I{} sudo sqlite3 /etc/pihole/gravity.db "INSERT INTO adlist (Address,Comment,Enabled) VALUES ('{}','Script added `date +%F`',1);"

# Cleanup
rm all.list temp.list pihole.list

# Add regex entries from mmotti
#apt install -y python3
#curl -sSl https://raw.githubusercontent.com/mmotti/pihole-regex/master/install.py | sudo python3

# Whitelisting stuff
pihole --white-regex "(\.|^)microsoft\.com$" "(\.|^)gvt3\.com$" "(\.|^)gvt2\.com$" "(\.|^)gstatic\.com$" "(\.|^)youtube\.com$" "(\.|^)ui\.com$"

# Blacklisting stuff
pihole --regex ".ru$" ".work$" ".fit$" ".casa$" ".loan$" ".cf$" ".tk$" ".rest$" ".ml$" ".london$" ".top$" "fivem"

# Restart and reload Pi-hole
pihole restartdns reload-lists
pihole -g
