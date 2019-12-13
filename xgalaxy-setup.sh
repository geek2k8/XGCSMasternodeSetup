#!/bin/bash
# XGalaxy Masternode Setup Script V1.4 for Ubuntu 16.04 LTS
# (c) 2018 by npq7721 for XGalaxy Coin
#
# Script will attempt to autodetect primary public IP address
# and generate masternode private key unless specified in command line
#
# Usage:
# bash xgalaxy-setup.sh 
#

#Color codes
RED='\033[0;91m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#XGCS TCP port
PORT=23058
RPC=23057

#Clear keyboard input buffer
function clear_stdin { while read -r -t 0; do read -r; done; }

#Delay script execution for N seconds
function delay { echo -e "${GREEN}Sleep for $1 seconds...${NC}"; sleep "$1"; }

#Stop daemon if it's already running
function stop_daemon {
    if pgrep -x 'xgalaxyd' > /dev/null; then
        echo -e "${YELLOW}Attempting to stop xgalaxyd${NC}"
        xgalaxy-cli stop
        delay 30
        if pgrep -x 'xgalaxy' > /dev/null; then
            echo -e "${RED}xgalaxyd daemon is still running!${NC} \a"
            echo -e "${RED}Attempting to kill...${NC}"
            pkill xgalaxyd
            delay 30
            if pgrep -x 'xgalaxyd' > /dev/null; then
                echo -e "${RED}Can't stop xgalaxyd! Reboot and try again...${NC} \a"
                exit 2
            fi
        fi
    fi
}
#Function detect_ubuntu

 if [[ $(lsb_release -d) == *16.04* ]]; then
   UBUNTU_VERSION=16
else
   echo -e "${RED}You are not running Ubuntu 16.04, Installation is cancelled.${NC}"
   exit 1

fi

#Process command line parameters
genkey=$1
rm -rf .xgalaxycore
clear

echo -e "${YELLOW}XGalaxy Masternode Setup Script V1.5 for Ubuntu 16.04 LTS${NC}"
echo "Do you want me to generate a masternode private key for you?[y/n]"
read DOSETUP

if [[ $DOSETUP =~ "n" ]] ; then
          read -e -p "Enter your private key:" genkey;
              read -e -p "Confirm your private key: " genkey2;
    fi

#Confirming match
  if [ $genkey = $genkey2 ]; then
     echo -e "${GREEN}MATCH! ${NC} \a" 
else 
     echo -e "${RED} Error: Private keys do not match. Try again or let me generate one for you...${NC} \a";exit 1
fi
sleep .5
clear

# Determine primary public IP address
dpkg -s dnsutils 2>/dev/null >/dev/null || sudo apt-get -y install dnsutils
publicip=$(dig +short myip.opendns.com @resolver1.opendns.com)
if [ -n "$publicip" ]; then
	echo ""
else
    publicip=$(curl -4 icanhazip.com)
fi

if [ -n "$publicip" ]; then
    echo -e "${YELLOW}IP Address detected:" $publicip ${NC}
else
    echo -e "${RED}ERROR: Public IP Address was not detected!${NC} \a"
    clear_stdin
    read -e -p "Enter VPS Public IP Address: " publicip
    if [ -z "$publicip" ]; then
        echo -e "${RED}ERROR: Public IP Address must be provided. Try again...${NC} \a"
        exit 1
    fi
fi
#Check Deps
if [ -d "/var/lib/fail2ban/" ]; 
then
    echo -e "${GREEN}Dependencies already installed...${NC}"
else
    echo -e "${GREEN}Updating system and installing required packages...${NC}"

sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
apt-get update -y
sudo apt-get -y upgrade
sudo apt-get -y dist-upgrade
sudo apt-get -y autoremove
sudo apt-get -y install wget nano htop jq git
sudo apt-get -y install libzmq3-dev
sudo apt-get -y install libboost-system-dev libboost-filesystem-dev libboost-chrono-dev libboost-program-options-dev libboost-test-dev libboost-thread-dev
sudo apt-get -y install libevent-dev
sudo apt-get -y install unzip
sudo apt -y install software-properties-common
sudo add-apt-repository ppa:bitcoin/bitcoin -y
sudo apt-get -y update
sudo apt-get -y install libdb4.8-dev libdb4.8++-dev
sudo apt-get install unzip
sudo apt-get -y install libminiupnpc-dev
sudo apt-get -y install fail2ban
sudo service fail2ban restart
sudo apt-get install libdb5.3++-dev libdb++-dev libdb5.3-dev libdb-dev && ldconfig
sudo apt-get install -y unzip libzmq3-dev build-essential libssl-dev libboost-all-dev libqrencode-dev libminiupnpc-dev libboost-system1.58.0 libboost1.58-all-dev libdb4.8++ libdb4.8 libdb4.8-dev libdb4.8++-dev libevent-pthreads-2.0-5
   fi

#Network Settings
echo -e "${GREEN}Installing Network Settings...${NC}"
{
sudo apt-get install ufw -y
} &> /dev/null
echo -ne '[##                 ]  (10%)\r'
{
sudo apt-get update -y
} &> /dev/null
echo -ne '[######             ] (30%)\r'
{
sudo ufw default deny incoming
} &> /dev/null
echo -ne '[#########          ] (50%)\r'
{
sudo ufw default allow outgoing
sudo ufw allow ssh
} &> /dev/null
echo -ne '[###########        ] (60%)\r'
{
sudo ufw allow $PORT/tcp
sudo ufw allow $RPC/tcp
} &> /dev/null
echo -ne '[###############    ] (80%)\r'
{
sudo ufw allow 22/tcp
sudo ufw limit 22/tcp
} &> /dev/null
echo -ne '[#################  ] (90%)\r'
{
echo -e "${YELLOW}"
sudo ufw --force enable
echo -e "${NC}"
} &> /dev/null
echo -ne '[###################] (100%)\n'

#Generating Random Password for xgalaxyd JSON RPC
rpcuser=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
rpcpassword=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

#Create 2GB swap file
if grep -q "SwapTotal" /proc/meminfo; then
    echo -e "${GREEN}Skipping disk swap configuration...${NC} \n"
else
    echo -e "${YELLOW}Creating 2GB disk swap file. \nThis may take a few minutes!${NC} \a"
    touch /var/swap.img
    chmod 600 swap.img
    dd if=/dev/zero of=/var/swap.img bs=1024k count=2000
    mkswap /var/swap.img 2> /dev/null
    swapon /var/swap.img 2> /dev/null
    if [ $? -eq 0 ]; then
        echo '/var/swap.img none swap sw 0 0' >> /etc/fstab
        echo -e "${GREEN}Swap was created successfully!${NC} \n"
    else
        echo -e "${RED}Operation not permitted! Optional swap was not created.${NC} \a"
        rm /var/swap.img
    fi
fi

#KILL THE MFER
pkill xgalaxyd
rm -r .xgalaxycore 
rm -rf /usr/bin/xgalaxy*
 
#Installing Daemon
 cd ~
wget https://github.com/officialXGalaxy/XGalaxy/releases/download/1.2.1/xgalaxy-1.2.1_ubuntu16.tar.gz
tar -xzf xgalaxy-1.2.1_ubuntu16.tar.gz -C ~/XGCSMasternodeSetup
rm -rf xgalaxy-1.2.1_ubuntu16.tar.gz

  stop_daemon
 
 # Deploy binaries to /usr/bin
 sudo cp ~/XGCSMasternodeSetup/xgalaxy-1.2.1_ubuntu16/xgalaxy* /usr/bin/
 sudo chmod 755 -R ~/XGCSMasternodeSetup
 sudo chmod 755 /usr/bin/xgalaxy* 
 # Deploy masternode monitoring script
 cp ~/XGCSMasternodeSetup/xgalaxymon.sh /usr/local/bin
 sudo chmod 711 /usr/local/bin/xgalaxymon.sh
 # Deploy restart script 
 cp ~/XGCSMasternodeSetup/xgalaxy-restart.sh /usr/local/bin
 sudo chmod 711 /usr/local/bin/xgalaxy-restart.sh
 
 #Create xgalaxy datadir
 if [ ! -f ~/.xgalaxycore/xgalaxy.conf ]; then 
 	sudo mkdir ~/.xgalaxycore
 fi

echo -e "${YELLOW}Creating xgalaxy.conf...${NC}"

# If genkey was not supplied in command line, we will generate private key on the fly
if [ -z $genkey ]; then
    cat <<EOF > ~/.xgalaxycore/xgalaxy.conf
rpcuser=$rpcuser
rpcpassword=$rpcpassword
EOF

    sudo chmod 755 -R ~/.xgalaxycore/xgalaxy.conf

    #Starting daemon first time just to generate masternode private key
    xgalaxyd -daemon
echo -ne '[##                 ] (15%)\r'
sleep 6
echo -ne '[######             ] (30%)\r'
sleep 6
echo -ne '[########           ] (45%)\r'
sleep 6
echo -ne '[##############     ] (72%)\r'
sleep 10
echo -ne '[###################] (100%)\r'
echo -ne '\n'

    #Generate masternode private key
    echo -e "${YELLOW}Generating masternode private key...${NC}"
    genkey=$(xgalaxy-cli masternode genkey)
    if [ -z "$genkey" ]; then
        echo -e "${RED}ERROR: Can not generate masternode private key.${NC} \a"
        echo -e "${RED}ERROR: Reboot VPS and try again or supply existing genkey as a parameter.${NC}"
        exit 1
    fi
    
    #Stopping daemon to create xgalaxy.conf
    stop_daemon
fi

# Create xgalaxy.conf
cat <<EOF > ~/.xgalaxycore/xgalaxy.conf
rpcuser=$rpcuser
rpcpassword=$rpcpassword
rpcport=$RPC
rpcallowip=127.0.0.1
listen=1
server=1
daemon=1
maxconnections=200
externalip=$publicip:$PORT
masternode=1
masternodeprivkey=$genkey
addnode=194.135.80.122
addnode=212.24.102.195
addnode=176.223.131.230
addnode=176.223.132.133
addnode=176.223.139.250
addnode=176.223.143.129
addnode=109.235.71.173
addnode=212.24.99.46
addnode=176.223.135.89
addnode=176.223.137.84
addnode=89.47.160.250
addnode=212.24.106.214
addnode=89.40.14.229
addnode=212.24.96.212
addnode=195.181.244.253 
addnode=176.223.138.175 
addnode=194.135.90.225 
addnode=195.181.244.83 
addnode=195.181.245.38 
addnode=94.176.234.65

EOF

#Finally, starting xgalaxy daemon with new xgalaxy.conf
xgalaxyd --daemon
delay 5

#Setting auto start cron job for xgalaxyd
cronjob="@reboot sleep 30 && xgalaxyd"
crontab -l > tempcron
if ! grep -q "$cronjob" tempcron; then
    echo -e "${GREEN}Configuring crontab job...${NC}"
    echo $cronjob >> tempcron
    crontab tempcron
fi
rm tempcron

echo -e "========================================================================
${YELLOW}Masternode setup is complete!${NC}
========================================================================
Masternode was installed with VPS IP Address: ${YELLOW}$publicip${NC}
Masternode Private Key: ${YELLOW}$genkey${NC}
Now you can add the following string to the masternode.conf file
for your Hot Wallet (the wallet with your XGCSCOIN collateral funds):
======================================================================== \a"
echo -e "${YELLOW}mn1 $publicip:$PORT $genkey TxId TxIdx${NC}"
echo -e "========================================================================
Use your mouse to copy the whole string above into the clipboard by
tripple-click + single-click (Dont use Ctrl-C) and then paste it 
into your ${YELLOW}masternode.conf${NC} file and replace:
    ${YELLOW}mn1${NC} - with your desired masternode name (alias)
    ${YELLOW}TxId${NC} - with Transaction Id from masternode outputs
    ${YELLOW}TxIdx${NC} - with Transaction Index (0 or 1)
     Remember to save the masternode.conf and restart the wallet!
To introduce your new masternode to the Itis network, you need to
issue a masternode start command from your wallet, which proves that
the collateral for this node is secured."

clear_stdin
read -p "*** Press any key to continue ***" -n1 -s

echo -e "1) Wait for the node wallet on this VPS to sync with the other nodes
on the network. Eventually the 'Is Synced' status will change
to 'true', which will indicate a comlete sync, although it may take
from several minutes to several hours depending on the network state.
Your initial Masternode Status may read:
    ${YELLOW}Node just started, not yet activated${NC} or
    ${YELLOW}Node  is not in masternode list${NC}, which is normal and expected.
2) Wait at least until 'IsBlockchainSynced' status becomes 'true'.
At this point you can go to your wallet and issue a start
command by either using Debug Console:
    Tools->Debug Console-> enter: ${YELLOW}masternode start-alias mn1${NC}
    where ${YELLOW}mn1${NC} is the name of your masternode (alias)
    as it was entered in the masternode.conf file
    
or by using wallet GUI:
    Masternodes -> Select masternode -> RightClick -> ${YELLOW}start alias${NC}
Once completed step (2), return to this VPS console and wait for the
Masternode Status to change to: 'Masternode successfully started'.
This will indicate that your masternode is fully functional and
you can celebrate this achievement!
Currently your masternode is syncing with the XGCS network...
The following screen will display in real-time
the list of peer connections, the status of your masternode,
node synchronization status and additional network and node stats.
"
clear_stdin
read -p "*** Press any key to continue ***" -n1 -s

echo -e "
${GREEN}...scroll up to see previous screens...${NC}
Here are some useful commands and tools for masternode troubleshooting:
========================================================================
To view masternode configuration produced by this script in xgalaxy.conf:
${YELLOW}cat ~/.xgalaxycore/xgalaxy.conf${NC}
Here is your xgalaxy.conf generated by this script:
-------------------------------------------------${YELLOW}"
cat ~/.xgalaxycore/xgalaxy.conf
echo -e "${NC}-------------------------------------------------
NOTE: To edit xgalaxy.conf, first stop the xgalaxyd daemon,
then edit the xgalaxy.conf file and save it in nano: (Ctrl-X + Y + Enter),
then start the xgalaxyd daemon back up:
             to stop:   ${YELLOW}xgalaxy-cli stop${NC}
             to edit:   ${YELLOW}nano ~/.xgalaxycore/xgalaxy.conf${NC}
             to start:  ${YELLOW}xgalaxyd${NC}
========================================================================
To view Itis debug log showing all MN network activity in realtime:
             ${YELLOW}tail -f ~/.xgalaxycore/debug.log${NC}
========================================================================
To monitor system resource utilization and running processes:
                   ${YELLOW}htop${NC}
========================================================================
To view the list of peer connections, status of your masternode, 
sync status etc. in real-time, run the nodemon.sh script:
                 ${YELLOW}nodemon.sh${NC}
or just type 'node' and hit <TAB> to autocomplete script name.
========================================================================
Enjoy your XGCS Masternode and thanks for using this setup script!

If you found this script useful, please donate to : 
${GREEN}XRU3ZieGKjLiKMhgXtsndRwmLgDoEWqUh5${NC}
...and make sure to check back for updates!
Original Author: Dwigt
Author: npq7721 
"
delay 30
# Run nodemon.sh
xgalaxymon.sh

# EOF
