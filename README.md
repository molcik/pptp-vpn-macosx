# PPTP VPN for MAC OS X
PPTP VPN client for Mac OS X 



# Download: 
<img src="./screenshots/icon.png" width="25px" height="22px" /> [**PPTPVPN**](https://github.com/molcik/pptp-vpn-macosx/releases) (https://github.com/molcik/pptp-vpn-macosx/releases)

 </br> 

# Screenshots



<img src="./screenshots/menu.png" width="20%" />&emsp;&emsp;<img src="./screenshots/setting.png" width="40%" />



## Contribution

**General**

- You need signing certificate

**Build**

1. You need to set Signing for both targets and build product.

2. Locate your products and run **SMJobBlessUtil.py** (PPTPVPN.app, PPTPVPN/Info.plist, HelpTool-Info.plist). It should look like this:

   ```shell
   $ ./SMJobBlessUtil.py setreq build/Debug/PPTPVPN.app PPTPVPN/Info.plist HelpTool/HelpTool-Info.plist
      PPTPVPN/Info.plist: updated
   HelpTool/HelpTool-Info.plist: updated
   ```


	<img src="./screenshots/shell.png" width="70%"/>

   Here is Apple documentation for this script [SMJobBless.py](https://developer.apple.com/library/archive/samplecode/SMJobBless/Listings/ReadMe_txt.html#//apple_ref/doc/uid/DTS40010071-ReadMe_txt-DontLinkElementID_3) (Safari打开).


#### References:
[iHongRen/PPTP-VPN](https://github.com/iHongRen/pptp-vpn)

[Apple SMJobBless](https://developer.apple.com/library/archive/samplecode/SMJobBless/Introduction/Intro.html)

[Apple EvenBetterAuthorizationSample](https://developer.apple.com/library/archive/samplecode/EvenBetterAuthorizationSample/Introduction/Intro.html)

[lex-integrity-mac](https://github.com/davidjosefson/lex-integrity-mac) 

[Execute a terminal command from a Cocoa app](https://stackoverflow.com/questions/412562/execute-a-terminal-command-from-a-cocoa-app/412573#412573)

[AlonsoZhang/PPTP](https://github.com/AlonsoZhang/PPTP)
