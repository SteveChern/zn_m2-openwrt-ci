#!/bin/sh
# HomeProxy 自愈：清理 urltest 池里的悬空节点 id，并在服务消失时拉起。
# 触发场景：update_subscriptions.uc 删掉池内节点后，generate_client.uc 取
# outbounds[length-1] 得到 null 直接崩溃，且清理未落盘 —— 崩溃后的配置
# 每次重启都会同样失败，服务可以静默躺几天。

CONF=/etc/config/homeproxy
STATE=/tmp/hp-health.state
LOG="logger -t hp-health"

dangling=""
for id in $(sed -n "s/.*main_urltest_nodes '\([0-9a-f]\{32\}\)'.*/\1/p" $CONF); do
	grep -q "^config node '$id'" $CONF || dangling="$dangling $id"
done

if [ -n "$dangling" ]; then
	for id in $dangling; do
		uci -q del_list homeproxy.config.main_urltest_nodes="$id"
	done
	uci commit homeproxy
	/etc/init.d/homeproxy restart
	$LOG "removed dangling urltest ids:$dangling; homeproxy restarted"
	echo 0 > $STATE
	exit 0
fi

if ! pidof sing-box >/dev/null 2>&1; then
	/etc/init.d/homeproxy restart
	$LOG "sing-box was down; homeproxy restarted"
	echo 0 > $STATE
	exit 0
fi

# 隧道数：sing-box 的 ESTABLISHED 出站连接。全零说明没有可用出口，
# 此时 main-dns(detour=main-out) 也会一起失效，海外域名解析将整体超时。
tunnels=$(netstat -tnp 2>/dev/null | grep sing-box | grep -c ESTABLISHED)
fails=$(cat $STATE 2>/dev/null || echo 0)
if [ "$tunnels" -eq 0 ]; then
	fails=$((fails + 1))
	echo $fails > $STATE
	[ $fails -ge 6 ] && $LOG "WARN: no established tunnel for $((fails * 10)) min, check airport entry IP/ports"
else
	[ "$fails" != 0 ] && $LOG "tunnels recovered: $tunnels"
	echo 0 > $STATE
fi
