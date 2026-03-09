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
    if [[ "$CPU" = "x86_64" ]] || [[ "$CPU" = "amd64" ]]; then
	exit 1
    else
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
	yum install zip unzip wget -y >/dev/null 2>&1
	echo ""
    else
	echo ""
	colorEcho $YELLOW "安装依赖中..."
	apt install zip unzip wget -y >/dev/null 2>&1
	echo ""
    fi
}

Download(){
    rm -rf /opt/PortForwardGoPanel
    archAffix
    DOWNLOAD_LINK="https://raw.githubusercontent.com/Slotheve/PortForwardGo/main/PortForwardGoPanel-linux-amd64.zip"
    colorEcho $YELLOW "下载PortForwardGoPanel: ${DOWNLOAD_LINK}"
    curl -L -H "Cache-Control: no-cache" -o /opt/PortForwardGoPanel.zip ${DOWNLOAD_LINK}
    unzip /opt/PortForwardGoPanel.zip
	rm -rf /opt/PortForwardGoPanel.zip
    cp /opt/PortForwardGoPanel/systemd/PortForwardGoPanel.service /etc/systemd/system/PortForwardGoPanel.service
    chmod -R +x /opt/PortForwardGoPanel
	systemctl daemon-reload
	systemctl enable PortForwardGoPanel
}

Install(){
    Install_dependency
	Download
    colorEcho $BLUE "安装完成,请更新/opt/PortForwardGoPanel/config.json后启动"
    echo ""
    ShowInfo
}

Uninstall(){
    read -p $' 是否卸载PortForwardGoPanel？[y/n]\n (默认n, 回车): ' answer
    if [[ "${answer}" = "y" ]]; then
		systemctl disable --now PortForwardGoPanel >/dev/null 2>&1
		rm -rf /opt/PortForwardGoPanel
		colorEcho $BLUE " PortForwardGoPanel已经卸载完毕"
    else
	colorEcho $BLUE " 取消卸载"
    fi
}

checkSystem
menu() {
	clear
	echo "#################################"
	echo -e "# ${RED}PortForwardGoPanel一键安装脚本${PLAIN}#"
	echo -e "#  ${GREEN}作者${PLAIN}: 怠惰(Slotheve)         #"
	echo -e "#  ${GREEN}网址${PLAIN}: https://slotheve.com   #"
	echo -e "#  ${GREEN}频道${PLAIN}: https://t.me/SlothNews #"
	echo "#################################"
	echo " ----------------------"
	echo -e "  ${GREEN}1.${PLAIN}  安装PortForwardGoPanel"
	echo -e "  ${GREEN}2.${PLAIN}  ${RED}卸载PortForwardGoPanel${PLAIN}"
	echo " ----------------------"
	echo -e "  ${GREEN}0.${PLAIN}  退出"
	echo ""
	echo -n " 当前状态："
	statusText
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
