#! /bin/sh

# <codex>
# <abstract>Script to remove everything installed by the sample.</abstract>
# </codex>

# This uninstalls everything installed by the sample.  It's useful when testing to ensure that 
# you start from scratch.

sudo launchctl unload /Library/LaunchDaemons/com.cxy.PPTPVPN.HelpTool.plist
sudo rm /Library/LaunchDaemons/com.cxy.PPTPVPN.HelpTool.plist
sudo rm /Library/PrivilegedHelperTools/com.cxy.PPTPVPN.HelpTool
sudo rm /etc/ppp/peers/pptp_vpn_config_file
sudo rm /tmp/pptp_vpn_log.txt

sudo security -q authorizationdb remove "com.cxy.PPTPVPN.HelpTool"

