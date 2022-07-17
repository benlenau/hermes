#!/bin/bash

# Preserve current adlists
sqlite3 /etc/pihole/gravity.db "SELECT Address FROM adlist" |sort >pihole.list

# Un/comment or add to the following lines if you want more og less adlists added during Pi-hole install
curl https://v.firebog.net/hosts/lists.php?type=tick >>temp.list
echo "https://block.energized.pro/basic/formats/hosts.txt" >>temp.list
echo "https://www.github.developerdan.com/hosts/lists/ads-and-tracking-extended.txt" >>temp.list
echo "https://www.github.developerdan.com/hosts/lists/amp-hosts-extended.txt" >>temp.list
echo "https://www.github.developerdan.com/hosts/lists/dating-services-extended.txt" >>temp.list
echo "https://www.github.developerdan.com/hosts/lists/hate-and-junk-extended.txt" >>temp.list
echo "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" >>temp.list
sort temp.list >all.list

# Add adlists to Pi-hole database
comm -23 pihole.list all.list | xargs -I{} sudo sqlite3 /etc/pihole/gravity.db "DELETE FROM adlist WHERE Address='{}';"
comm -13 pihole.list all.list | xargs -I{} sudo sqlite3 /etc/pihole/gravity.db "INSERT INTO adlist (Address,Comment,Enabled) VALUES ('{}','Script added `date +%F`',1);"

# Temp-file Cleanup
rm all.list temp.list pihole.list

# Add regex entries from mmotti
#apt install -y python3
#curl -sSl https://raw.githubusercontent.com/mmotti/pihole-regex/master/install.py | sudo python3

# Add to whitelist
pihole --white-regex "(\.|^)microsoft\.com$" "(\.|^)gvt3\.com$" "(\.|^)gvt2\.com$" "(\.|^)gstatic\.com$" "(\.|^)youtube\.com$" "(\.|^)ui\.com$" "(\.|^)msecnd\.net$"
pihole -w video-fa.scdn.co --comment "Spotify Podcasts"
pihole -w i.instagram.com --comment "Instagram"
pihole -w amp-api-edge.apps.apple.com --comment "Apple App Store"
pihole -w www.nfbio.dk --comment "Nordisk Film Biografer"
pihole -w t.co --comment "Twitter Links"
pihole -w l.instagram.com --comment "Instagram Links (app)"

# Add to blacklist
pihole --regex ".ru$" ".work$" ".fit$" ".casa$" ".loan$" ".cf$" ".tk$" ".rest$" ".ml$" ".london$" ".top$" ".live$" ".ga$" ".buzz$" ".date$"

# Reload added lists and upgrade Pi-hole Gravity
pihole restartdns reload-lists
pihole -g
