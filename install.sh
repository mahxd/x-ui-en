#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && Echo -e "${red} error: ${plain} must use the root user to run this script! \ n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red} without detecting the system version, please contact the script author! ${plain} \ n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="amd64"
    echo -e "${red} The detection architecture failed, using the default architecture: ${arch} ${plain}"
fi

echo "Architecture: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "This software does not support 32 -bit system (X86). Please use 64 -bit system (X86_64). If the detection is wrong, please contact the author "
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Please use the system 7 or higher version of the system!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or higher version system!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use Debian 8 or higher version system!${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar lsof certbot -y
    else
        apt install wget curl tar lsof certbot -y
    fi
}

#This function will be called when user installed x-ui out of sercurity
config_after_install() {
    echo -e "${yellow}For security considerations, after installation/update, you need to mandate the port and the account password ${plain} "
    read -p "Confirm whether it continues?[y/n]": config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "Please set your account name:" config_account
        echo -e "${yellow}Your account name will be set to:${config_account}${plain}"
        read -p "Please set your account password:" config_password
        echo -e "${yellow} Your account password will be set to: ${config_password} ${plain}"
        read -p "Please set the panel access port:" config_port
        echo -e "${yellow} Your panel access port will be set to: ${config_port} ${plain}"
        echo -e "${yellow} Confirm the settings, set ${plain}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        echo -e "${yellow} account password settings complete ${plain}"
        /usr/local/x-ui/x-ui setting -port ${config_port}
        echo -e "${yellow} panel port settings complete ${plain}"
    else
        echo -e "${red} has been canceled, all settings are settled by default, please modify ${plain}" in time
    fi
}

install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/mahxd/x-ui-en/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red} The x-ui version failed, which may be beyond the GitHub API limit. Please try it later, or manually specify the x-ui version to install ${play}"
            exit 1
        fi
        echo -e "The latest version of x-ui: ${last_version}, start installation"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz https://github.com/mahxd/x-ui-en/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red} download x-ui failure, please make sure your server can download GitHub file ${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/mahxd/x-ui-en/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
        echo -e "Start installing x-ui V $ 1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red} download x-ui V $ 1 Failure, please make sure this version exists ${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-${arch}.tar.gz
    rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/mahxd/x-ui-en/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install
    #echo -e "If it is a new installation, the default web port port is ${Green} 54321 ${plain}, and the user name and password are all ${Green} admin ${plain}"
    #echo -e "Please make sure that this port is not occupied by other programs, ${yellow} and ensure that port 54321 has been released ${plain}"
    #    echo -e "If you want to modify 54321 to other ports and enter the x-ui command to modify it, you must also ensure that the port you modify is also released."
    #echo -e ""
    #echo -e "If it is updated, access the panel according to your previous way"
    #echo -e ""
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui v${last_version}${plain} The installation is complete, the panel has been started,"
    echo -e ""
    echo -e "x-ui Management script usage: "
    echo -e "----------------------------------------------"
    echo -e "x-ui              - Show the management menu (more features)"
    echo -e "x-ui start        - Start the x-ui panel"
    echo -e "x-ui stop         - Stop x-ui panel"
    echo -e "x-ui restart      - Restart x-ui panel"
    echo -e "x-ui status       - View x-ui Status "
    echo -e "x-ui enable       - Set the x-ui boot self-starting"
    echo -e "x-ui disable      - Cancel the x-ui boot self-starting"
    echo -e "x-ui log          - View x-ui log"
    echo -e "x-ui v2-ui        - Migrate V2-UI account data of this machine to x-ui"
    echo -e "x-ui update       - Update x-ui panel"
    echo -e "x-ui install      - Install the x-ui panel"
    echo -e "x-ui uninstall    - Uninstall x-ui panel"
    echo -e "----------------------------------------------"
}

check_80(){
        if [[ -z $(type -P lsof) ]]; then
        if [[ ! $SYSTEM == "CentOS" ]]; then
            ${PACKAGE_UPDATE[int]}
        fi
        ${PACKAGE_INSTALL[int]} lsof
    fi
    
    echo -e "${yellow}Checking if the port 80 is in use...${plain}"
    sleep 1
    
    if [[  $(lsof -i:"80" | grep -i -c "listen") -eq 0 ]]; then
        echo -e "${green}Good! Port 80 is not in use${plain}"
        sleep 1
    else
        "${red}Port 80 is currently in use, please close the service this service, which is using port 80:${plain}"
        lsof -i:"80"
        read -rp "If you need to close this service right now, please press Y. Otherwise, press N to abort SSL issuing [Y/N]: " yn
        if [[ $yn =~ "Y"|"y" ]]; then
            lsof -i:"80" | awk '{print $2}' | grep -v "PID" | xargs kill -9
            sleep 1
        else
            exit 1
        fi
    fi
}

install_cert(){
    while true
    do
        read -p "Enter your mail:" email
        read -p "Enter your domain:" domain
        if [[ -z "$email"  || -z "$domain"  ]]; then
            echo -e "Please enter email and domain or press ctrl+c to exit\n"
        else 
        break
        fi
    done
    echo "Try to generate certificate"
    echo "Port 80 should be open"
    check_80
    certbot certonly --standalone --preferred-challenges http --agree-tos --email ${email} -d ${domain}
}

echo -e "${green}start installation${plain}"
install_base
install_x-ui $1

echo 
read -p "Do you want to generate SSL certificate too y/n? " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    install_cert
fi