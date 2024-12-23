#!/bin/sh
#This script will help configure device settings on UniFi Cloud Key Model: UC-CK
#Download script: sudo wget https://raw.githubusercontent.com/meokgo/UC-CK/main/2-Device-Config.sh
#Make script executable: sudo chmod +x 2-Device-Config.sh
#Run script: sudo ./2-Device-Config.sh

#Function for setting up MFA users
setup_users ()
{
  while : ; do
    #Continue setting up MFA for users?
      read -p "$(echo '\033[0;106m'"\033[30mSetup MFA for users? (y/n)\033[0m " | tee -a 2-Device-Config.log)" yn
      case $yn in
        [yY]) unset MFA_User
          read -p "$(echo '\n\033[0;106m'"\033[30mEnter user name to setup MFA:\033[0m " | tee -a 2-Device-Config.log)" MFA_User
          if [ -z "$MFA_User" ]; then
            echo '\n\033[0;35m'"\033[1mNothing entered.\033[0m" | tee -a 2-Device-Config.log
          else
            #Check if user exists in system
            if id -u $MFA_User >/dev/null 2>&1; then
              runuser -l $MFA_User -c 'google-authenticator -tdf -Q UTF8 -r 3 -R 30 -w 3'
            else
              echo '\n\033[0;31m'"\033[1m$MFA_User does not exist in system.\033[0m" | tee -a 2-Device-Config.log
            fi
          fi;;
        [nN]) echo '\033[0;35m'"\033[1mDone setting up MFA users.\033[0m" | tee -a 2-Device-Config.log
          break;;
        *) echo '\n\033[0;31m'"\033[1mInvalid response.\033[0m" | tee -a 2-Device-Config.log;;
      esac
    done
}
(
echo "$(date): Script started." >> 2-Device-Config.log
#Check if script is run as root
  echo '\033[0;36m'"\033[1mChecking if script is run as root...\033[0m"
  if ! [ $(id -u) = 0 ]; then
    echo '\n\033[0;31m'"\033[1mMust run script as root.\033[0m"
    exit 1
  fi
#Option to change hostname
  read -p "$(echo '\033[0;106m'"\033[30mNew hostname (leave blank to keep current):\033[0m ")" New_Name
    if [ -z "$New_Name" ]; then
      echo '\n\033[0;35m'"\033[1mNot updating hostname.\033[0m"
    else
      hostnamectl set-hostname $New_Name --static
      sed -i "s|UCK-G2-Plus|$New_Name.local $New_Name|g" /etc/hosts
    fi
#Option to set static IP
  while : ; do
    read -p "$(echo '\033[0;106m'"\033[30mConfigure static IP? (y/n)\033[0m ")" yn
    case $yn in
      [yY]) echo "#*****************************
#To set static IP change DHCP to no.
#Uncomment #Address #Gateway #DNS.
#Update with static IP info.
#*****************************
[Match]
Name = eth1
[Address]
#Address = 192.168.1.217/24
[Route]
#Gateway = 192.168.1.1
[Network]
DHCP = ipv4
LLMNR = no
#DNS = 8.8.4.4 8.8.8.8" > /etc/system/network/eth1.network
        read -p "$(echo '\n\033[0;106m'"\033[30mEnter static IP in 0.0.0.0/24 format (leave blank to keep DHCP):\033[0m ")" New_IP
          if [ -z "$New_IP" ]; then
            echo '\n\033[0;35m'"\033[1mNot configuring static IP, leaving as DHCP.\033[0m"
          else
            sed -i "s|192.168.1.100/24|$New_IP|g" /etc/systemd/network/eth0.network
            sed -i 's|#Address|Address|g' /etc/systemd/network/eth0.network
            sed -i 's|DHCP = ipv4|DHCP = no|g' /etc/systemd/network/eth0.network
            read -p "$(echo '\n\033[0;106m'"\033[30mEnter static gateway in 0.0.0.0 format (leave blank to keep DHCP):\033[0m ")" New_Gateway
            if [ -z "$New_Gateway" ]; then
              echo '\n\033[0;35m'"\033[1mNot configuring static gateway, leaving as DHCP.\033[0m"
              sed -i "s|$New_IP|192.168.1.100/24|g" /etc/systemd/network/eth0.network
              sed -i 's|Address|#Address|g' /etc/systemd/network/eth0.network
              sed -i 's|DHCP = no|DHCP = ipv4|g' /etc/systemd/network/eth0.network
            else
              sed -i "s|192.168.1.1|$New_Gateway|g" /etc/systemd/network/eth0.network
              sed -i 's|#Gateway|Gateway|g' /etc/systemd/network/eth0.network
              read -p "$(echo '\n\033[0;106m'"\033[30mEnter static DNS in 0.0.0.0 format (leave blank to keep DHCP):\033[0m ")" New_DNS
              if [ -z "$New_DNS" ]; then
                echo '\n\033[0;35m'"\033[1mNot configuring static DNS, leaving as DHCP.\033[0m"
                sed -i "s|$New_IP|192.168.1.100/24|g" /etc/systemd/network/eth0.network
                sed -i 's|Address|#Address|g' /etc/systemd/network/eth0.network
                sed -i 's|DHCP = no|DHCP = ipv4|g' /etc/systemd/network/eth0.network
                sed -i "s|$New_Gateway|192.168.1.1|g" /etc/systemd/network/eth0.network
                sed -i 's|Gateway|#Gateway|g' /etc/systemd/network/eth0.network
              else
                sed -i "s|8.8.4.4|$New_DNS|g" /etc/systemd/network/eth0.network
                sed -i 's|#DNS|DNS|g' /etc/systemd/network/eth0.network
                systemctl restart systemd-networkd.service
              fi
            fi
          fi
        break;;
      [nN]) echo '\n\033[0;35m'"\033[1mNot configuring static IP, leaving as DHCP.\033[0m"
        break;;
      *) echo '\n\033[0;31m'"\033[1mInvalid response.\033[0m";;
    esac
  done
#Enable automatic updates and reboots
  echo '\n\033[0;36m'"\033[1mEnabling automatic updates and reboots...\033[0m"
  DEBIAN_FRONTEND=noninteractive apt -y install unattended-upgrades -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
  DEBIAN_FRONTEND=noninteractive dpkg-reconfigure --priority=low unattended-upgrades
  sed -i 's|//Unattended-Upgrade::Automatic-Reboot "false";|Unattended-Upgrade::Automatic-Reboot "true";|g' /etc/apt/apt.conf.d/50unattended-upgrades
  systemctl start unattended-upgrades
  systemctl enable unattended-upgrades
#Enforce strong passwords
  echo '\033[0;36m'"\033[1mEnforcing strong passwords...\033[0m"
  DEBIAN_FRONTEND=noninteractive apt -y install libpam-pwquality -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
  cp /etc/pam.d/common-password /etc/pam.d/common-password.bak
  sed -i "s|\[default=ignore\]|requisite|g" /etc/pam.d/common-password
  sed -i "s|pam_pwquality.so retry=3|pam_pwquality.so remember=99 use_authok|g" /etc/pam.d/common-password
  sed -i "s| pam_usermapper.so mapfile=/etc/security/usermap.conf|			pam_pwquality.so minlen=16 difok=3 ucredit=-1 lcredit=-2 dcredit=-2 ocredit=-2 retry=3 enforce_for_root|g" /etc/pam.d/common-password
#Update root user password, option to add sudo user
  echo '\033[0;106m'"\033[30mUpdate root user password (Must be at least 16 characters, contain 3 different characters vs current, 1 uppercase character, 2 lowercase characters, 2 numbers and 2 special characters.):\033[0m"
  passwd root
  while : ; do
    read -p "$(echo '\033[0;106m'"\033[30mAdd new sudo user? (y/n)\033[0m ")" yn
    case $yn in
      [yY]) read -p "$(echo '\033[0;106m'"\033[30mEnter new sudo user name:\033[0m ")" New_User && 
        if [ -z "$New_User" ]; then
          echo '\033[0;35m'"\033[1mNothing entered, not adding new sudo user.\033[0m"
        else
          adduser --gecos GECOS $New_User
          usermod -aG sudo $New_User
          echo '\033[0;36m'"\033[1m$New_User added to sudo group.\033[0m"
          #Move $New_User home directory using symlink
          if [ -L "/home/$New_User" ]; then
            echo "symlink /home/$New_User already exists"
          else
            mkdir -p /data/home
            mv /home/$New_User /data/home/$New_User
            ln -s /data/home/$New_User /home/$New_User
          fi
          #Create user alias for ls to show more detail
          sed -i "s|alias ls='ls --color=auto'|alias ls='ls -hAlF --color=auto'|g" /home/$Tmux_User/.bashrc
          #Create $New_User alias for ssh logs
          if grep -Fxq "#User alias for ssh logs" /home/$New_User/.bashrc
          then
            echo '\033[0;35m'"\033[1mAlias for ssh logs already exists for $New_User.\033[0m"
          else
            echo "
#User alias for ssh logs
alias sshlog='echo "Last 10 successful logins:" && last -10 && echo "Last 10 failed logins:" && sudo lastb -10'" >> /home/$New_User/.bashrc
          fi
          source /home/$New_User/.bashrc
        fi
        break;;
      [nN]) echo '\n\033[0;35m'"\033[1mNot adding new sudo user.\033[0m"
        break;;
      *) echo '\n\033[0;31m'"\033[1mInvalid response.\033[0m";;
    esac
  done
#Option to harden SSH
  while : ; do
    read -p "$(echo "\e[1;33m\e[1;41m+------------------------------------------------------------------------------------------------------------+
|----MAKE SURE YOU HAVE CREATED A NEW SUDO USER AS SSH HARDENING WILL BLOCK LOGIN FOR root AND ubnt USERS----|
+------------------------------------------------------------------------------------------------------------+\e[0m
\e[1;106m\e[1;30mHarden SSH settings? (y/n)\e[0m ")" yn
    case $yn in
      [yY]) cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
        if grep -Fxq "AddressFamily inet" /etc/ssh/sshd_config
        then
          echo '\n\033[0;35m'"\033[1mAddressFamily inet already exists.\033[0m"
        else
          echo "
AddressFamily inet" >> /etc/ssh/sshd_config
        fi
        if grep -Fxq "ServerKeyBits 2048" /etc/ssh/sshd_config
        then
          echo '\n\033[0;35m'"\033[1mServerKeyBits 2048 already exists.\033[0m"
        else
          echo "
ServerKeyBits 2048" >> /etc/ssh/sshd_config
        fi
        if grep -Fxq "LogLevel VERBOSE" /etc/ssh/sshd_config
        then
          echo '\n\033[0;35m'"\033[1mLogLevel VERBOSE already exists.\033[0m"
        else
          echo "
LogLevel VERBOSE" >> /etc/ssh/sshd_config
        fi
        if grep -Fxq "LoginGraceTime 30" /etc/ssh/sshd_config
        then
          echo '\n\033[0;35m'"\033[1mLoginGraceTime 30 already exists.\033[0m"
        else
          echo "
LoginGraceTime 30" >> /etc/ssh/sshd_config
        fi
        sed -i 's|PermitRootLogin yes|PermitRootLogin no|g' /etc/ssh/sshd_config
        sed -i 's|X11Forwarding yes|X11Forwarding no|g' /etc/ssh/sshd_config
        sed -i 's|MaxAuthTries 6|MaxAuthTries 3|g' /etc/ssh/sshd_config
        if grep -Fxq "MaxSessions 1" /etc/ssh/sshd_config
        then
          echo '\n\033[0;35m'"\033[1mMaxSessions 1 already exists.\033[0m"
        else
          echo "
MaxSessions 1" >> /etc/ssh/sshd_config
        fi
        if grep -Fxq "AllowTcpForwarding no" /etc/ssh/sshd_config
        then
          echo '\033[0;35m'"\033[1mAllowTcpForwarding no already exists.\033[0m"
        else
          echo "
AllowTcpForwarding no" >> /etc/ssh/sshd_config
        fi
        if grep -Fxq "AllowAgentForwarding no" /etc/ssh/sshd_config
        then
          echo '\033[0;35m'"\033[1mAllowAgentForwarding no already exists.\033[0m"
        else
          echo "
AllowAgentForwarding no" >> /etc/ssh/sshd_config
        fi
        if grep -Fxq "Compression yes" /etc/ssh/sshd_config
        then
          echo '\033[0;35m'"\033[1mCompression yes already exists.\033[0m"
        else
          echo "
Compression yes" >> /etc/ssh/sshd_config
        fi
        if grep -Fxq "DenyUsers root" /etc/ssh/sshd_config
        then
          echo '\033[0;35m'"\033[1mDenyUsers already exists.\033[0m"
        else
          echo "
DenyUsers root" >> /etc/ssh/sshd_config
        fi
        SSH_Port=$(cat /etc/ssh/sshd_config | grep "^Port" | sed 's|Port ||g')
        if [ -z "$SSH_Port" ]; then
          echo "
Port 22" >> /etc/ssh/sshd_config
          SSH_Port=$(cat /etc/ssh/sshd_config | grep "^Port" | sed 's|Port ||g')
        else
          echo '\033[0;35m'"\033[1mPort $SSH_Port already exists.\033[0m"
        fi
        read -p "$(echo '\033[0;106m'"\033[30mEnter new SSH port (leave blank to use current port: $SSH_Port):\033[0m ")" New_Port
        if [ -z "$New_Port" ]; then
          echo '\n\033[0;35m'"\033[1mNothing entered, SSH port: $SSH_Port.\033[0m"
        else
          sed -i "s|Port $SSH_Port|Port $New_Port|g" /etc/ssh/sshd_config
        fi
        echo "#Script logs out idle SSH connections
if [ "\$SSH_CONNECTION" != "" ]; then
  TMOUT=900 #15 minutes
  readonly TMOUT
  export TMOUT
fi" > /etc/profile.d/ssh-timeout.sh
        #Set login limits for $New_User and root user
          if [ -z "$New_User" ]; then
            echo '\n\033[0;35m'"\033[1mNew sudo user was not setup, only adding login limits for root user.\033[0m"
          else
            if grep -q $New_User /etc/security/limits.conf;
            then
              echo '\033[0;35m'"\033[1mLogin limit for $New_User already exists.\033[0m";
            else
            #Set to 5 to allow for tmux use. 1 for running tmux, 3 for total of 3 tmux panels and 1 for allowing SSH reconnect
              sed -i "s|# End of file|$New_User	hard	maxlogins	5\x0A# End of file|g" /etc/security/limits.conf;
              echo '\033[0;36m'"\033[1mLogin limit set for $New_User.\033[0m"
            fi
        fi
        if grep -q "^root" /etc/security/limits.conf;
        then
          echo '\033[0;35m'"\033[1mLogin limit for root already exists.\033[0m";
        else
          sed -i 's|# End of file|root	hard	maxlogins	1\x0A# End of file|g' /etc/security/limits.conf;
        fi
        /etc/init.d/ssh restart
        echo '\033[0;36m'"\033[1mSSH settings updated.\033[0m"
        break;;
      [nN]) echo '\n\033[0;35m'"\033[1mNot hardening SSH settings.\033[0m"
        break;;
      *) echo '\n\033[0;31m'"\033[1mInvalid response.\033[0m";;
    esac
  done
) 2>&1 | tee -a 2-Device-Config.log
#Option to enable MFA
  while : ; do
    read  -p "$(echo '\033[0;106m'"\033[30mSetup Google Authenticator? (y/n)\033[0m "| tee -a 2-Device-Config.log)" yn
    case $yn in
      [yY]) DEBIAN_FRONTEND=noninteractive apt install -y libpam-google-authenticator -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" | tee -a 2-Device-Config.log
        sed -i 's|UsePAM no|UsePAM yes|g' /etc/ssh/sshd_config | tee -a 2-Device-Config.log
        sed -i 's|ChallengeResponseAuthentication no|ChallengeResponseAuthentication yes|g' /etc/ssh/sshd_config | tee -a 2-Device-Config.log
        if grep -Fxq "#MFA via Google Authenticator" /etc/pam.d/sshd
        then
          echo '\033[0;35m'"\033[1m#MFA via Google Authenticator already exists.\033[0m" | tee -a 2-Device-Config.log
        else
          echo "
#MFA via Google Authenticator
auth   required   pam_google_authenticator.so" >> /etc/pam.d/sshd
        fi
        systemctl restart ssh | tee -a 2-Device-Config.log
        setup_users
        break;;
      [nN]) echo '\033[0;35m'"\033[1mNot setting up MFA.\033[0m" | tee -a 2-Device-Config.log
        break;;
      *) echo '\033[0;31m'"\033[1mInvalid response.\033[0m" | tee -a 2-Device-Config.log;;
    esac
  done
echo "$(date): Script finished" >> 2-Device-Config.log
