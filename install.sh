#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
PLAIN='\033[0m'

colorEcho() {
    echo -e "${1}${@:2}${PLAIN}"
}

print_black() {
    echo -e "\033[30m$1\033[0m"
}

print_red() {
    echo -e "\033[31m$1\033[0m"
}

print_green() {
    echo -e "\033[32m$1\033[0m"
}

print_yellow() {
    echo -e "\033[33m$1\033[0m"
}

print_blue() {
    echo -e "\033[34m$1\033[0m"
}

print_magenta() {
    echo -e "\033[35m$1\033[0m"
}

print_cyan() {
    echo -e "\033[36m$1\033[0m"
}

print_grey() {
    echo -e "\033[37m$1\033[0m"
}

print_white() {
    echo "$1"
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

clear
PROGRAM="PortForwardGo"

mirror="https://pkg.zeroteam.top"
service="$PROGRAM"
rpc="websocket"
disable_exec=false
disable_ipv4_report=false
disable_ipv6_report=false
backup=false
offline=0

print_cyan "$PROGRAM installation script"

# Read parameters
{
    # Parse parameters
    while [ $# -gt 0 ]; do
        case $1 in
        --api)
            api=$2
            shift
            ;;
        --secret)
            secret=$2
            shift
            ;;
        --license)
            license=$2
            shift
            ;;
        --service)
            service=$2
            shift
            ;;
        --proxy)
            proxy=$2
            shift
            ;;
        --listen)
            listen=$2
            shift
            ;;
        --mirror)
            mirror=$2
            shift
            ;;
        --region)
            region=$2
            shift
            ;;
        --version)
            version=$2
            shift
            ;;
        --rpc)
            rpc=$2
            shift
            ;;
        --disable-exec)
            disable_exec=true
            ;;
        --machine-id)
            machine_id=$2
            shift
            ;;
        --disable-ipv4-report)
            disable_ipv4_report=true
            ;;
        --disable-ipv6-report)
            disable_ipv6_report=true
            ;;
        --backup)
            backup=true
            ;;
        --offline)
            offline=1
            ;;
        *)
            print_red " Unknown parameter: $1"
            exit 2
            ;;
        esac
        shift
    done

    # Apply region profile
    if [ ! -z "$region" ]; then
        case "$region" in
        CN)
            print_yellow " Current region profile: China Mainland (CN)"

            [ -z "$license" ] && proxy="internal+panel"
            listen="auto"
            ;;
        IR)
            print_yellow " Current region profile: Iran (IR)"

            [ -z "$license" ] && proxy="panel"
            listen="auto"
            ;;
        *)
            print_yellow " Current region profile '$region' not found, using default profile..."
            ;;
        esac
    fi

    # Check parameters validity
    {
        if [ -z "$api" ]; then
            print_red " Parameter 'api' not found"
            exit 2
        fi

        if [ -z "$secret" ]; then
            print_red " Parameter 'secret' not found"
            exit 2
        fi

        if [ -z "$service" ]; then
            print_red " Parameter 'service' not found"
            exit 2
        fi

        if [ -z "$mirror" ]; then
            print_red " Parameter 'mirror' not found"
            exit 2
        fi
    }
}

# Check system
{
    print_yellow " ** Checking system info..."
    archAffix
    checkSystem
    # Check systemd
    command -V systemctl >/dev/null
    if [ "$?" -ne 0 ]; then
        print_red "Not found systemd"
        exit 1
    fi

    # Check network config
    if [ "$listen" == "auto" ]; then
        listen=""

        default_out_ip=$(curl -4sL --connect-timeout 5 myip.ipip.net | awk '{print $2}' | awk -F ： '{print $2}')
        default_in_ip="$default_out_ip"

        bind_ips=$(ip address show | grep inet | grep -v inet6 | grep -v host | grep -v docker | grep -v tun | grep -v tap | awk '{print $2}' | awk -F "/" '{print $1}')
        for bind_ip in ${bind_ips[@]}; do
            out_ip=$(curl -4sL --connect-timeout 5 --interface $bind_ip myip.ipip.net | awk '{print $2}' | awk -F ： '{print $2}')
            if [ -z "$out_ip" ]; then
                continue
            fi

            print_cyan " Network card binding IP '$bind_ip' => Public IP '$out_ip'"

            if [ "$out_ip" != "$default_out_ip" ]; then
                default_in_ip="$out_ip"
                listen="$bind_ip"
            fi
        done

        print_white ""

        if [ -z "$listen" ]; then
            print_green " The inbound IP was not obtained. It may be a single ip machine."
            print_green " Public IP '$default_out_ip'"
        else
            print_green " Inbound: Network card binding IP '$listen' => Public IP '$default_in_ip'"
            print_green " Outbound: Public IP '$default_out_ip'"
        fi
    fi

    # Check installed
    while [ -f "/etc/systemd/system/$service.service" ] || [ -d "/opt/$service" ] || [ "$service" == "all" ]; do
        read -ep " Service '$service' exists or invalid, please enter a new service name: " service
    done
}

# Install program
{
    # Download release
    {
        print_yellow " ** Downloading release..."
        mkdir -p /opt/PortForwardGo
        curl -L -o /opt/PortForwardGo/PortForwardGo "https://raw.githubusercontent.com/Slotheve/PortForwardGo/main/PortForwardGo"
        chmod +x /opt/PortForwardGo/PortForwardGo
        if [ $? -ne 0 ] || [ ! -f "/opt/PortForwardGo/PortForwardGo" ]; then
            print_red "Download failed"
            exit 1
        fi
    }

    # Configure program
    {
        cat > /opt/PortForwardGo/examples/backend.json<<-EOF
    {
        "Api": "{api}",
        "License": "{license}",
        "Secret": "{secret}",
        "Proxy": "{proxy}",
        "Speed": 0,
        "ListenIP": "{listen}",
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
        sed -i "s#{api}#$api#g" /opt/PortForwardGo/config.json
        sed -i "s#{secret}#$secret#g" /opt/PortForwardGo/config.json
        sed -i "s#{license}#$license#g" /opt/PortForwardGo/config.json
        sed -i "s#{proxy}#$proxy#g" /opt/PortForwardGo/config.json
        sed -i "s#{listen}#$listen#g" /opt/PortForwardGo/config.json
        #sed -i "s#{rpc}#$rpc#g" /opt/$service/config.json
        #sed -i "s#{disable_exec}#$disable_exec#g" /opt/$service/config.json
        #sed -i "s#{machine_id}#$machine_id#g" /opt/$service/config.json
        #sed -i "s#{disable_ipv4_report}#$disable_ipv4_report#g" /opt/$service/config.json
        #sed -i "s#{disable_ipv6_report}#$disable_ipv6_report#g" /opt/$service/config.json
        #sed -i "s#{backup}#$backup#g" /opt/$service/config.json
    }

    # Add system service
    {
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
WorkingDirectory=/opt/$service
ExecStart=/opt/$service/PortForwardGo --config config.json --log run.log

[Install]
WantedBy=multi-user.target
EOF
    }
}

# Optimize system config
{
    print_yellow " ** Optimizing system config..."

    # System external connection port
    if [ -z "$listen" ]; then
        echo "net.ipv4.ip_local_port_range = 50000 65535" >/etc/sysctl.d/97-system-port-range.conf
        print_green " The port occupied by the system's external connection has been modified to '50000-65535', file location '/etc/sysctl.d/97-system-port-range.conf'"
    else
        echo "net.ipv4.ip_local_port_range = 1024 65535" >/etc/sysctl.d/97-system-port-range.conf
        print_green " The port occupied by the system's external connection has been modified to '1024-65535', file location '/etc/sysctl.d/97-system-port-range.conf'"
    fi

    # Sysctl
    {
        cat >/etc/sysctl.d/98-optimize.conf <<EOF
fs.file-max = 1000000
fs.inotify.max_user_instances = 8192
fs.pipe-max-size = 1048576
fs.pipe-user-pages-hard = 0
fs.pipe-user-pages-soft = 0

net.ipv4.somaxconn = 3276800
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_retries1 = 5
net.ipv4.tcp_retries2 = 5
net.ipv4.tcp_orphan_retries = 3
net.ipv4.tcp_fin_timeout = 2
net.ipv4.tcp_max_tw_buckets = 4096
net.ipv4.tcp_tw_recycle = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_orphans = 3276800
net.ipv4.tcp_abort_on_overflow = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_stdurg = 0
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_dsack = 1
net.ipv4.tcp_frto = 2
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_ecn_fallback = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_reordering = 300
net.ipv4.tcp_retrans_collapse = 0
net.ipv4.tcp_autocorking = 1
net.ipv4.tcp_low_latency = 0
net.ipv4.tcp_slow_start_after_idle = 1
net.ipv4.tcp_no_metrics_save = 0
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_tso_win_divisor = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_congestion_control = bbr

net.ipv4.ip_forward = 1
net.ipv4.route.gc_timeout = 100
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

net.core.netdev_max_backlog = 16384
net.core.netdev_budget = 600
net.core.somaxconn = 3276800
net.core.default_qdisc = fq
EOF
        print_green " BBR and system tuning have been enabled, file location '/etc/sysctl.d/98-optimize.conf'"
    }

    # Ulimit limits
    {
        cat >/etc/security/limits.d/99-unlock.conf <<EOF
* soft nofile 1048576
* hard nofile 1048576
* soft nproc 1048576
* hard nproc 1048576
* soft core 1048576
* hard core 1048576
* hard memlock unlimited
* soft memlock unlimited
EOF
        print_green " Unlocked system ulimit limits, file location '/etc/security/limits.d/99-unlock.conf'"
    }

    # Apply system config
    {
        print_yellow "  * Apply new system config..."

        sysctl -p >/dev/null 2>&1
        sysctl --system >/dev/null 2>&1

        print_green " Done, may you need reboot to apply some config!"
    }
}

# Finish installation
{
    print_yellow " ** Starting program..."

    systemctl daemon-reload
    systemctl enable --now $service
}

print_green "$PROGRAM installed successfully"
