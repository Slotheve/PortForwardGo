#!/bin/bash
# Author: Slotheve<https://slotheve.com>

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
PLAIN='\033[0m'

CPU=`uname -m`

colorEcho() {
    echo -e "${1}${@:2}${PLAIN}"
}

archAffix(){
    if [[ "$CPU" != "x86_64" ]] && [[ "$CPU" != "amd64" ]]; then
	colorEcho $RED " 不支持的CPU架构！"
    fi
}

checkSystem() {
    result=$(id | awk '{print $1}')
    if [[ $result != "uid=0(root)" ]]; then
        result=$(id | awk '{print $1}')
	if [[ $result != "用户id=0(root)" ]]; then
        colorEcho $RED " 请以root身份执行该脚本"
        exit 1
	fi
    fi

    res=`which yum 2>/dev/null`
    if [[ "$?" != "0" ]]; then
        res=`which apt 2>/dev/null`
        if [[ "$?" != "0" ]]; then
            colorEcho $RED " 不受支持的Linux系统"
            exit 1
        fi
	OS="apt"
    else
	OS="yum"
    fi
    res=`which systemctl 2>/dev/null`
    if [[ "$?" != "0" ]]; then
        colorEcho $RED " 系统版本过低，请升级到最新版本"
        exit 1
    fi
}

Install_dependency(){
    if [[ ${OS} == "yum" ]]; then
	echo ""
	colorEcho $YELLOW "安装依赖中..."
	yum install unzip wget -y >/dev/null 2>&1
	echo ""
    else
	echo ""
	colorEcho $YELLOW "安装依赖中..."
	apt install unzip wget -y >/dev/null 2>&1
	echo ""
    fi
}

Set1(){
	read -p $'请输入Api地址 [IP或网址]:' api
	if [[ -z "${api}" ]]; then
		colorEcho $RED "输入为空, 请重新输入。"
		echo ""
		Set1
	fi
}

Set2(){
	read -p $'请输入License [授权码]:' license
	if [[ -z "${license}" ]]; then
		colorEcho $RED "输入为空, 请重新输入。"
		echo ""
		Set2
	fi
}

Set3(){
	read -p $'请输入Secret [密钥]:' secret
	if [[ -z "${secret}" ]]; then
		colorEcho $RED "输入为空, 请重新输入。"
		echo ""
		Set3
	fi
}

Download(){
    rm -rf /opt/PortForwardGo
    mkdir -p /opt/PortForwardGo
    archAffix

    cat > /opt/PortForwardGo/config.json<<-EOF
{
    "Api": "$api",
    "License": "$license",
    "Secret": "$secret",
    "Proxy": "",
    "Speed": 0,
    "ListenIP": "0.0.0.0",
    "OutBounds": null,
    "DisableUDP": false,
    "DisableTFO": true,
    "DisableExec": false,
    "DNS": [
        "119.29.29.29",
        "8.8.8.8"
    ],
    "FirewallLog": "firewall.log"
}
EOF

    DOWNLOAD_LINK="https://raw.githubusercontent.com/Slotheve/PortForwardGo/main/PortForwardGo"
    colorEcho $YELLOW "下载PortForwardGo: ${DOWNLOAD_LINK}"
    curl -L -H "Cache-Control: no-cache" -o /opt/PortForwardGo/PortForwardGo ${DOWNLOAD_LINK}

    cat >/etc/systemd/system/PortForwardGo.service <<EOF
[Unit]
Description=PortForwardGo Backend Service For $api
Documentation=https://docs.zeroteam.top/pfgo/backend/
After=network.target

[Service]
Type=simple
User=root
Restart=always
RestartSec=20s
TasksMax=infinity
LimitCPU=infinity
LimitFSIZE=infinity
LimitDATA=infinity
LimitSTACK=infinity
LimitCORE=infinity
LimitRSS=infinity
LimitNOFILE=infinity
LimitAS=infinity
LimitNPROC=infinity
LimitSIGPENDING=infinity
LimitMSGQUEUE=infinity
LimitRTTIME=infinity
WorkingDirectory=/opt/PortForwardGo
ExecStart=/opt/PortForwardGo/PortForwardGo --config config.json --log run.log

[Install]
WantedBy=multi-user.target
EOF

    chmod -R +x /opt/PortForwardGo
	systemctl daemon-reload
	systemctl enable --now PortForwardGo
}

Install(){
    Install_dependency
    Set1
    Set2
    Set3
    Set4
	Download
    colorEcho $BLUE "安装完成"
}

Uninstall(){
    read -p $' 是否卸载PortForwardGo？[y/n]\n (默认n, 回车): ' answer
    if [[ "${answer}" = "y" ]]; then
		systemctl disable --now PortForwardGo >/dev/null 2>&1
		rm -rf /opt/PortForwardGo
		colorEcho $BLUE " PortForwardGo已经卸载完毕"
    else
	colorEcho $BLUE " 取消卸载"
    fi
}

checkSystem
menu() {
	clear
	echo "#################################"
	echo -e "#   ${RED}PortForwardGo一键安装脚本${PLAIN}   #"
	echo -e "#  ${GREEN}作者${PLAIN}: 怠惰(Slotheve)         #"
	echo -e "#  ${GREEN}网址${PLAIN}: https://slotheve.com   #"
	echo -e "#  ${GREEN}频道${PLAIN}: https://t.me/SlothNews #"
	echo "#################################"
	echo " ----------------------"
	echo -e "  ${GREEN}1.${PLAIN}  安装PortForwardGo"
	echo -e "  ${GREEN}2.${PLAIN}  ${RED}卸载PortForwardGo${PLAIN}"
	echo " ----------------------"
	echo -e "  ${GREEN}0.${PLAIN}  退出"
	echo ""
	echo 

	read -p " 请选择操作[0-2]：" answer
	case $answer in
		0)
			exit 0
			;;
		1)
			Install
			;;
		2)
			Uninstall
			;;
		*)
			colorEcho $RED " 请选择正确的操作！"
   			sleep 2s
			menu
			;;
	esac
}
menu
