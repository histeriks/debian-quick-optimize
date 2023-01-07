#!/usr/bin/env bash
XS_APTIPV4="yes"
XS_APTUPGRADE="yes"
XS_BASHRC="yes"
XS_DISABLERPC="yes"
XS_ENTROPY="yes"
XS_FAIL2BAN="yes"
XS_GUESTAGENT="yes"
XS_IFUPDOWN2="yes"
XS_JOURNALD="yes"
XS_KERNELHEADERS="yes"
XS_KEXEC="yes"
XS_KSMTUNED="yes"
XS_LANG="en_US.UTF-8"
XS_LIMITS="yes"
XS_LOGROTATE="yes"
XS_LYNIS="yes"
XS_MAXFS="yes"
XS_MEMORYFIXES="yes"
XS_NET="yes"
XS_NOAPTLANG="yes"
XS_PIGZ="yes"
XS_SWAPPINESS="yes"
XS_TCPBBR="yes"
XS_TCPFASTOPEN="yes"
XS_TIMESYNC="yes"
XS_TIMEZONE=""
XS_UTILS="yes"

echo "Processing .... "

if [ "$XS_LANG" == "" ] ; then
    XS_LANG="en_US.UTF-8"
fi
export LANG="$XS_LANG"
export LC_ALL="C"

RAM_SIZE_GB=$(( $(vmstat -s | grep -i "total memory" | xargs | cut -d" " -f 1) / 1024 / 1000))

apt-get update > /dev/null 2>&1

apt-get -y install apt-transport-https ca-certificates curl

if [ "$XS_UTILS" == "yes" ] ; then
    apt-get -y install \
    axel \
    build-essential \
    dialog \
    dnsutils \
    dos2unix \
    git \
    gnupg-agent \
    grc \
    htop \
    iftop \
    iotop \
    iperf \
    ipset \
    iptraf \
    mlocate \
    msr-tools \
    nano \
    net-tools \
    omping \
    software-properties-common \
    sshpass \
    tmux \
    unzip \
    vim \
    vim-nox \
    wget \
    whois \
    zip
fi

if [ "$XS_LYNIS" == "yes" ] ; then
wget -O - https://packages.cisofy.com/keys/cisofy-software-public.key | apt-key add -
echo "deb https://packages.cisofy.com/community/lynis/deb/ stable main" > /etc/apt/sources.list.d/cisofy-lynis.list
apt-get update > /dev/null 2>&1
apt-get -y install lynis
fi

if [ "$XS_KSMTUNED" == "yes" ] ; then
apt-get -y install ksm-control-daemon
    if [[ RAM_SIZE_GB -le 16 ]] ; then
        KSM_THRES_COEF=50
        KSM_SLEEP_MSEC=80
    elif [[ RAM_SIZE_GB -le 32 ]] ; then
        KSM_THRES_COEF=40
        KSM_SLEEP_MSEC=60
    elif [[ RAM_SIZE_GB -le 64 ]] ; then
        KSM_THRES_COEF=30
        KSM_SLEEP_MSEC=40
    elif [[ RAM_SIZE_GB -le 128 ]] ; then
        KSM_THRES_COEF=20
        KSM_SLEEP_MSEC=20
    else
        KSM_THRES_COEF=10
        KSM_SLEEP_MSEC=10
    fi
sed -i -e "s/\# KSM_THRES_COEF=.*/KSM_THRES_COEF=${KSM_THRES_COEF}/g" /etc/ksmtuned.conf
sed -i -e "s/\# KSM_SLEEP_MSEC=.*/KSM_SLEEP_MSEC=${KSM_SLEEP_MSEC}/g" /etc/ksmtuned.conf
systemctl enable ksmtuned
fi

apt-get -y install qemu-guest-agent open-vm-tools virtualbox-guest-utils

if [ "$XS_FAIL2BAN" == "yes" ] ; then
apt-get -y install fail2ban
cat <<EOF > /etc/fail2ban/jail.local
[DEFAULT]
banaction = iptables-ipset-proto4
EOF
systemctl enable fail2ban
fi

if [ "$XS_LIMITS" == "yes" ] ; then
cat <<EOF > /etc/sysctl.d/99-xs-maxwatches.conf
fs.inotify.max_user_watches=1048576
fs.inotify.max_user_instances=1048576
fs.inotify.max_queued_events=1048576
EOF
cat <<EOF >> /etc/security/limits.d/99-xs-limits.conf
* soft     nproc          256000
* hard     nproc          256000
* soft     nofile         256000
* hard     nofile         256000
root soft     nproc          256000
root hard     nproc          256000
root soft     nofile         256000
root hard     nofile         256000
EOF
cat <<EOF > /etc/sysctl.d/99-xs-maxkeys.conf
kernel.keys.root_maxkeys=1000000
kernel.keys.maxkeys=1000000
EOF
echo "DefaultLimitNOFILE=256000" >> /etc/systemd/system.conf
echo "DefaultLimitNOFILE=256000" >> /etc/systemd/user.conf
echo 'session required pam_limits.so' >> /etc/pam.d/common-session
echo 'session required pam_limits.so' >> /etc/pam.d/runuser-l
echo "ulimit -n 256000" >> /root/.profile
fi

if [ "$XS_LOGROTATE" == "yes" ] ; then
cat <<EOF > /etc/logrotate.conf
daily
su root adm
rotate 7
create
compress
size=10M
delaycompress
copytruncate
include /etc/logrotate.d
EOF
systemctl restart logrotate
fi

if [ "$XS_JOURNALD" == "yes" ] ; then
cat <<EOF > /etc/systemd/journald.conf
[Journal]
Storage=persistent
SplitMode=none
RateLimitInterval=0
RateLimitIntervalSec=0
RateLimitBurst=0
ForwardToSyslog=no
ForwardToWall=yes
Seal=no
Compress=yes
SystemMaxUse=64M
RuntimeMaxUse=60M
MaxLevelStore=warning
MaxLevelSyslog=warning
MaxLevelKMsg=warning
MaxLevelConsole=notice
MaxLevelWall=crit
EOF
systemctl restart systemd-journald.service
journalctl --vacuum-size=64M --vacuum-time=1d;
journalctl --rotate
fi

if [ "$XS_ENTROPY" == "yes" ] ; then
apt-get -y install haveged
cat <<EOF > /etc/default/haveged
DAEMON_ARGS="-w 1024"
EOF
systemctl daemon-reload
systemctl enable haveged
fi

if [ "$XS_MEMORYFIXES" == "yes" ] ; then
cat <<EOF > /etc/sysctl.d/99-xs-memory.conf
vm.min_free_kbytes=524288
vm.nr_hugepages=72
vm.max_map_count=262144
vm.overcommit_memory = 1
EOF
fi

if [ "$XS_TCPBBR" == "yes" ] ; then
cat <<EOF > /etc/sysctl.d/99-xs-kernel-bbr.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
fi

if [ "$XS_TCPFASTOPEN" == "yes" ] ; then
cat <<EOF > /etc/sysctl.d/99-xs-tcp-fastopen.conf
net.ipv4.tcp_fastopen=3
EOF
fi

if [ "$XS_NET" == "yes" ] ; then
cat <<EOF > /etc/sysctl.d/99-xs-net.conf
net.core.netdev_max_backlog=8192
net.core.optmem_max=8192
net.core.rmem_max=16777216
net.core.somaxconn=8151
net.core.wmem_max=16777216
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.log_martians = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.default.log_martians = 0
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.ip_local_port_range=1024 65535
net.ipv4.tcp_base_mss = 1024
net.ipv4.tcp_challenge_ack_limit = 999999999
net.ipv4.tcp_fin_timeout=10
net.ipv4.tcp_keepalive_intvl=30
net.ipv4.tcp_keepalive_probes=3
net.ipv4.tcp_keepalive_time=240
net.ipv4.tcp_limit_output_bytes=65536
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_max_tw_buckets = 1440000
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_rfc1337=1
net.ipv4.tcp_rmem=8192 87380 16777216
net.ipv4.tcp_sack=1
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_syn_retries=3
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_tw_reuse = 0
net.ipv4.tcp_wmem=8192 65536 16777216
net.netfilter.nf_conntrack_generic_timeout = 60
net.netfilter.nf_conntrack_helper=0
net.netfilter.nf_conntrack_max = 524288
net.netfilter.nf_conntrack_tcp_timeout_established = 28800
net.unix.max_dgram_qlen = 4096
EOF
fi

if [ "$XS_SWAPPINESS" == "yes" ] ; then
cat <<EOF > /etc/sysctl.d/99-xs-swap.conf
vm.swappiness=10
EOF
fi

if [ "$XS_MAXFS" == "yes" ] ; then
cat <<EOF > /etc/sysctl.d/99-xs-fs.conf
fs.nr_open=12000000
fs.file-max=9000000
EOF
fi

if [ "$XS_BASHRC" == "yes" ] ; then
cat <<EOF >> /root/.bashrc
export HISTTIMEFORMAT="%d/%m/%y %T "
export PS1='\u@\h:\W \$ '
alias l='ls -CF'
alias la='ls -A'
alias ll='ls -alF'
alias ls='ls --color=auto'
source /etc/profile.d/bash_completion.sh
export PS1="\[\e[31m\][\[\e[m\]\[\e[38;5;172m\]\u\[\e[m\]@\[\e[38;5;153m\]\h\[\e[m\] \[\e[38;5;214m\]\W\[\e[m\]\[\e[31m\]]\[\e[m\]\\$ "
EOF
    echo "source /root/.bashrc" >> /root/.bash_profile
fi

exit 0
