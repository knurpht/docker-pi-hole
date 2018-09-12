#!/bin/bash
# Name: 
# Description: Script to install and run a pihole server
# License: Creative Commons, shared copyright
# Current distros supported: "openSUSE" "Fedora" "Red_Hat" "CentOS" "Debian" "*buntu" "Linux_Mint" "PopOS" "Raspbian"


# BEGIN DISTROS NB Don't use spaces. Add code to the prepare_system() function for docker install. Use _ instead of spaces like Red_Hat
DISTRO_ARRAY=("openSUSE" "SUSE" "Fedora" "Red_Hat" "CentOS" "Debian" "*buntu" "Linux_Mint" "PopOS" "Raspbian") ;
DISTROS=$( printf '%s\n' ${DISTRO_ARRAY[@]} | sort );
# END DISTROS


# BEGIN VARS here
VERSION=0.9
AUTHORS='Gertjan Lettink; Wesley Landaal'
COPYRIGHT='2018'
# interface
WDT="--width=500"
HGT="--height=250"
LHGT="--height=480"
DOCKER_ARCH=$(uname -i);
SUDO="sudo -Sp ''";
# END VARS


# BEGIN FUNCTIONS
check_for_zenity()
{
	ZENITY_INSTALLED=$(which zenity)
	if [ ! "$ZENITY_INSTALLED" ] ; then
		xmessage "Zenity is not installed. \
			Please install before running the script." ;
		exit 4
	fi
}

# initial info screen
show_info()
{
    START_Y_N=$(zenity --question --text="This script will (re)install, (re)configure, remove or update your own Pihole server\nVersion: $VERSION  AUTHORS: $AUTHORS  ©$COPYRIGHT" $WDT $HGT && echo YES || echo NO) ;
    if  [ "$START_Y_N" == "NO" ] ; then
        exit 1
    fi
}

# ask the user for the distro used
get_os()
{
    OS=$(zenity --list --title="Linux Distro" --text="Pick your linux distro" --column="Distro" $DISTROS $WDT $LHGT)  ;	
    if [ "$OS" == "" ] ; then
        get_os
    fi
    if [ "$OS" == "openSUSE"  || "$OS" == "SUSE" ] ; then
            $MSG;
            PKG="docker";
            PKGMGR="zypper";
            PKG_OK="--no-confirm";
            PKG_INSTALL="install";
            PKG_REMOVE="remove";
    fi
    if [ "$OS" == "Fedora" ||  "$OS" == "Red_Hat" || "CentOS" ] ; then
            $MSG;
            $PKG="docker";
            $PKGMGR="yum";
            $PKG_OK="-y";
            $PKG_INSTALL="install";
            $PKG_REMOVE="remove";
    fi
    if [ "$OS" == "Debian" || "$OS" == "*buntu" || "$OS" == "Debian" || "$OS" == "PopOS" || "$OS" == "Linux_Mint" ||  "$OS" == "Raspbian" ] ; then
            $MSG;
            $PKG="docker.io";
            $PKGMGR="apt";
            $PKG_OK="-y";
            $PKG_INSTALL="install";
            $PKG_REMOVE="remove";
            $FIX_RESOLVE="yes";
    fi
}

# have the user confirm his distro to install on
confirm_os()
{
    OS_CONFIRM=$(zenity --question --text="$OS is the distro you entered\n\nSure this the correct one? " $WDT $HGT && echo YES || echo NO) ;
    if  [ "$OS_CONFIRM" == "NO" ] ; then
            get_os
    fi
}

# ask the user for the root password to make the 'sudo' commands work
get_sudo_password()
{
    zenity --info --text="You will now be asked to enter your root/sudo password\n\nMake sure it's correct" $WDT $HGT ;
    PASSWD=$(zenity --password --title="Root password" $WDT $HGT) ;
    if [ "$PASSWD" == "" ] ; then
        get_sudo_password
    fi
	if  [[ ${?} != 0 || -z ${PASSWD} ]] ; then
        get_sudo_password
	fi
	if ! sudo -kSp '' [ 1 ] <<<${PASSWD} 2>/dev/null ; then
        get_sudo_password
	fi
}

# announce install of dependencies and system preparation
prepare_system_msg()
{
	zenity --info --text="The script will now setup your system for the pihole server" $WDT $HGT ;
	prepare_system 
}

# perform install of depencies and call acivation of the docker.service.
prepare_system()
{	
    get_sudo_password
    DOCKER_INSTALLED=$(which docker);
    MSG=$(zenity --info --text="Docker packages will be installed now\n\nThis may take a minute" $WDT $HGT) ;
    if [ "$DOCKER_INSTALLED" == "" ] ; then
        $MSG;
        $SUDO $PKGMGR $PKG_INSTALL $PKG_OK $PKG <<<${PASSWD};
    fi
    if [ "$FIX_RESOLVE" == "yes" ] ; then
 	    $SUDO service systemd-resolved stop <<<${PASSWD}
	    $SUDO systemctl disable systemd-resolved.service <<<${PASSWD}
    fi
	zenity --info --text="Docker packages installed" $WDT $HGT ;
	start_docker
}

# start the docker service
start_docker()
{
	DOCKER_RUNNING=$(systemctl show -p SubState --value docker)
	DOCKER_ENABLED=$(systemctl is-enabled docker.service)
	if [ "$DOCKER_RUNNING" == "running" ] ; then
		MSG=$(zenity --info --text="Docker service already enabled and running" $WDT $HGT);
	else
        MSG=$(zenity --info --text="Docker service now enabled and running" $WDT $HGT) ;
        if [ ! "$DOCKER_ENABLED" == "enabled" ] ; then
            $SUDO systemctl enable docker <<<${PASSWD}
            $SUDO systemctl start docker <<<${PASSWD}
        else
			zenity --info --text="Starting docker service" $WDT $HGT ;
			$SUDO systemctl start docker <<<${PASSWD}
		fi
	fi
    $MSG
	zenity --info --text="Starting configuration of your pihole server" $WDT $HGT ;
}

# ask for the Pihole server IP address | could be picked from ip addr or something like that
get_ipaddress()
{
    GET_IP=$(hostname -I | cut -d' ' -f1)
    IP=$(zenity --entry --text="Enter the pihole IP Address" --entry-text=$GET_IP $WDT $HGT) ;
    if [ "$GET_IP" == "" ] ; then
        get_ipaddress
    fi
}

# have the user confirm the entered IP address
confirm_ipaddress()
{
    IP_CONFIRM=$(zenity --question --text="$IP is the IP you entered\n\nSure this the correct IP address? " $WDT $HGT && echo YES || echo NO) ;
    if  [ "$IP_CONFIRM" == "NO" ] ; then
        get_ipaddress
	fi
}

# ask the user for the path to the pihole docker configs
get_docker_configs()
{
	DOCKER_CONFIGS=$(zenity --entry --text="Enter the path for you Pihole docker configs\n\nLeave default if you don't know what you're changing" --entry-text="/opt/pihole" $WDT $HGT) ;
    if [ "$DOCKER_CONFIGS" == "" ] ; then
        get_docker_configs
    fi	
}

# have the user confirm the entered path for docker configs
confirm_docker_configs()
{
    DOCKER_CONFIGS_CONFIRM=$(zenity --question --text="$DOCKER_CONFIGS is the docker config path you entered\n\nSure this the docker config path you want to use? " $WDT $HGT && echo YES || echo NO) ;
    if  [ "$DOCKER_CONFIGS_CONFIRM" == "NO" ] ; then
        get_docker_configs
	fi
}

# ask the user which port to access the pihole server for port 80
get_port_80()
{
    PORT_80=$(zenity --entry --text="Enter the port to access the pihole server through http\n\nLeave default if you don't know what you're changing" --entry-text="8081" $WDT $HGT) ;
    if [ "$PORT_80" == "" ] ; then
        get_port_80
    fi
}

# have the user confirm the port to access the pihole server for port 80
confirm_port_80()
{
	PORT_80_CONFIRM=$(zenity --question --text="$PORT_80 is the port serving port 80 you entered\n\nSure this is the port you want to use? " $WDT $HGT && echo YES || echo NO) ;
    if  [ "$PORT_80_CONFIRM" == "NO" ] ; then
        get_port_80
	fi
}

# ask the user which port to access the pihole server for port 443 
get_port_443()
{
    PORT_443=$(zenity --entry --text="Enter the port to access the pihole server through https\n\nLeave default if you don't know what you're changing" --entry-text="4443" $WDT $HGT) ;
    if [ "$PORT_443" == "" ] ; then
        get_port_443
    fi
}

# have the user confirm the port to access the pihole server for port 443
confirm_port_443()
{
	PORT_443_CONFIRM=$(zenity --question --text="$PORT_443 is the port serving port 443 you entered\n\nSure this is the port you want to use? " $WDT $HGT && echo YES || echo NO) ;
    if  [ "$PORT_443_CONFIRM" == "NO" ] ; then
        get_port_443
	fi
}

# have the user confirm all entered data
confirm_all()
{
    ALL_CONFIRM=$(zenity --question --text="Are you sure the following entries are correct?\n\nIP Address: $IP\nDocker configs: $DOCKER_CONFIGS\nPort 80: served on $PORT_80\nPort 443: served on $PORT_443\n\nClick No if you're in doubt." $WDT $HGT $WDT $HGT && echo YES || echo NO)
    if  [ "$ALL_CONFIRM" == "NO" ] ; then
        show_info
    else
        create_pihole_password
    fi
}

# create a password for the docker container admin page
create_pihole_password()
{
    zenity --info --text="You will now be asked to set a password for your Pihole admin page" $WDT $HGT ;
    DOCKER_PW=$(zenity --password --title="Pihole password" --text="The Pihole server needs a password to\naccess the admin webpages\n\nCreate a password and remember it somehow." $WDT $HGT) ;
    if [ "$DOCKER_PW" == "" ] ; then
        create_pihole_password
    fi
    start_docker_pihole
}

# ask the user whether the pihole server is going to be used as a DHCP server
confirm_pihole_dhcp()
{
    CONFIRM_DHCP=$(zenity --question --text="Do you want to use the Pihole server for DHCP?" $WDT $HGT $WDT $HGT && echo YES || echo NO)
    if  [ "$CONFIRM_DHCP" == "NO" ] ; then
        PIHOLE_DHCP_LINE="" ;
    else
        PIHOLE_DHCP_LINE=" -p 67:67/udp " ;
    fi
}

# start the docker container with provided data, remove old container/images
start_docker_pihole()
{
    confirm_pihole_dhcp
    open_firewall_ports
    $SUDO docker rm -f pihole <<<${PASSWD};
    if [ "$DOCKER_ARCH" == "aarch64" ] ; then
        DOCKER_IMAGE="pihole/pihole:v4.0_armhf";
        $SUDO docker rmi pihole/pihole:v4.0_armhf <<<${PASSWD};
    fi
    if [ "$DOCKER_ARCH" == "x86_64" ] ; then
        DOCKER_IMAGE="pihole/pihole:latest";
        $SUDO docker rmi pihole/pihole <<<${PASSWD};
    fi
    MSG=$(zenity --info --text="Pihole docker container being pulled now\n\nThis may take a couple of minutes" $WDT $HGT) ;
    $MSG
    $SUDO docker run -d \
    --name pihole \
    -p 53:53/tcp -p 53:53/udp \
    -p $PORT_80:80 \
    -p $PORT_443:443 \
    -v "${DOCKER_CONFIGS}/pihole/:/etc/pihole/" \
    -v "${DOCKER_CONFIGS}/dnsmasq.d/:/etc/dnsmasq.d/" \
    -e ServerIP="$IP" \
    --restart=unless-stopped \
    -e WEBPASSWORD=$DOCKER_PW \
    $PIHOLE_DHCP_LINE $DOCKER_IMAGE <<<${PASSWD}      ; 
}

# open firewall ports using IP tables.
open_firewall_ports()
{
    zenity --info --text="Opening necessary ports in the firewall " $WDT $HGT ;
    $SUDO iptables -A INPUT -p tcp --dport 53 -j ACCEPT <<<${PASSWD};
    $SUDO iptables -A INPUT -p udp --dport 53 -j ACCEPT <<<${PASSWD};
    $SUDO iptables -A INPUT -p tcp --dport 67 -j ACCEPT <<<${PASSWD};
    $SUDO iptables -A INPUT -p udp --dport 67 -j ACCEPT <<<${PASSWD};
    $SUDO iptables -A INPUT -p tcp --dport $PORT_80 -j ACCEPT <<<${PASSWD};
    $SUDO iptables -A INPUT -p udp --dport $PORT_80 -j ACCEPT <<<${PASSWD};
    $SUDO iptables -A INPUT -p tcp --dport $PORT_443 -j ACCEPT <<<${PASSWD};
    $SUDO iptables -A INPUT -p udp --dport $PORT_443 -j ACCEPT <<<${PASSWD};
}


# show DONE and provide URL and password for admin access
show_done()
{
    zenity --info --text="Your password for http://$IP:$PORT_80/admin/ is $DOCKER_PW\nYour password for https://$IP:$PORT_443/admin/ is $DOCKER_PW\n\nMake sure you open ports 53, 67 udp, $PORT_80 and $PORT_443 in the firewall\n\nTo start using Pihole:\nChange DNS 1 of your router or computer to $IP\nand reconnect your devices with the network.\n\nIn case of firewall issues, first restart your firewall\nto pick up the new rules" $WDT $HGT;
}

# END FUNCTIONS


# BEGIN INSTALLER
check_for_zenity
show_info
get_os
confirm_os
prepare_system_msg
get_ipaddress
get_docker_configs
get_port_80
get_port_443
confirm_all
show_done
# END INSTALLER
