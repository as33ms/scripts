#!/bin/bash
url=https://raw.githubusercontent.com/ashakunt/scripts/master/01.do-run_1st_on_droplet.sh
echo "Running user data step: " | tee /root/userdata.log
wget $url -O /root/run_me_first.sh -o /root/userdata.log
chmod +x /root/run_me_first.sh
