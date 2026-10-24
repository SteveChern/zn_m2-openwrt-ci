# ZN-M2 OpenWrt 固件

只针对 **兆能 ZN-M2（qualcommax / ipq60xx，IPQ6000）** 的云编译仓库。定位是一台稳定的有线路由器：**无 WiFi、无 USB**，保留 NSS 有线加速与 ZRAM。

- 上游源码：[LiBwrt/LibWrt](https://github.com/LiBwrt/LibWrt)，分支 `25.12-nss`，内核 6.12
- 目标设备：`qualcommax/ipq60xx`，设备 `zn_m2`（唯一启用）
- 默认地址：`192.168.1.1`，用户 `root`，密码 `password`
- 固件在 [Releases](../../releases) 中，每月 1 号自动编译，也可手动触发 Actions

## 裁剪说明

上游会为 target 的 `DEFAULT_PACKAGES` 中每个包 `select DEFAULT_<pkg>`，选设备 profile 后，`.config` 里写 `=n` 也会被强制改回 `m`。所以 WiFi/USB 不能只靠配置文件关闭：

| 位置 | 作用 |
| --- | --- |
| [configs/zn_m2.config](configs/zn_m2.config) | 只启用 `zn_m2`，关闭 WiFi/USB 相关包，保留 HomeProxy、ZRAM、NSS、中文界面 |
| [diy.sh](diy.sh) | 在 `ipq60xx/target.mk` 末尾用 `filter-out` 去掉 `wpad-openssl`、`kmod-ath11k*`、`automount`、`kmod-usb3/dwc3` 等默认包，并移除 `ipq-wifi-zn_m2` 校准包 |
| workflow 的“校验裁剪结果” | `make defconfig` 后断言上述包没有残留，避免白跑几小时编译 |

设备树中未启用的硬件不需要额外补丁：没有 ath11k 驱动就不会加载无线，USB 控制器驱动也一并移除。

## 系统默认项

- `files/etc/uci-defaults/99-router-tuning`：首次启动设置 ZRAM 算法 `lzo-rle`、`vm.swappiness=100`、conntrack 上限、dnsmasq 不监听 WAN，并安装健康检查 cron
- `files/usr/sbin/hp-health.sh`：每 10 分钟检查 HomeProxy，清理 urltest 池里的悬空节点 id，sing-box 挂掉时自动拉起

## 本地编译

```sh
git clone --depth 1 -b 25.12-nss https://github.com/LiBwrt/LibWrt.git openwrt
cd openwrt
./scripts/feeds update -a && ./scripts/feeds install -a
cp /path/to/configs/zn_m2.config .config
/path/to/diy.sh
make defconfig
make -j$(nproc)
```

产物在 `bin/targets/qualcommax/ipq60xx/`：首次刷机用 `*factory.ubi`，升级用 `*sysupgrade.bin`。

## 免责声明

- 本人不对任何人因使用本固件所遭受的任何理论或实际的损失承担责任。
- 本固件禁止用于任何商业用途，请遵守当地互联网相关法律法规。
