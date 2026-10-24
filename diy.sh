#!/bin/sh
# ZN-M2 专用裁剪，在 feeds 安装后、make defconfig 前执行。
#
# 上游 device profile 会为 DEFAULT_PACKAGES 里的每个包 select DEFAULT_<pkg>，
# 光在 .config 里写 =n 会被强制改回 m，所以必须从 target 默认包里删。
# 裁剪行必须插在 $(eval $(call BuildTarget)) 之前：dumpinfo 在 eval 时就展开了
# DEFAULT_PACKAGES，之后再赋值不会反映到生成的 target 元数据里。
set -eu

PARENT_MK=target/linux/qualcommax/Makefile
IMAGE_MK=target/linux/qualcommax/image/ipq60xx.mk

if [ ! -f "$PARENT_MK" ] || [ ! -f "$IMAGE_MK" ]; then
	echo "上游 qualcommax 目录结构已变化，裁剪中止" >&2
	exit 1
fi

# WiFi / USB / 板上不存在的硬件，以及只给外接存储用的组件
if ! grep -q 'filter-out wpad-openssl' "$PARENT_MK"; then
	sed -i '/^[[:space:]]*\$(eval \$(call BuildTarget))/i DEFAULT_PACKAGES := $(filter-out wpad-openssl kmod-ath11k kmod-ath11k-ahb kmod-ath11k-pci ath11k-firmware-ipq6018 ath11k-firmware-ipq6018-ddwrt kmod-qca-nss-drv-wifi-meshmgr automount kmod-usb3 kmod-usb-dwc3 kmod-usb-dwc3-qcom kmod-dsa-qca8k kmod-phy-aquantia kmod-phy-qca83xx kmod-leds-pwm e2fsprogs f2fs-tools losetup kmod-fs-ext4 kmod-fs-f2fs,$(DEFAULT_PACKAGES))' "$PARENT_MK"
fi

grep -q 'filter-out wpad-openssl' "$PARENT_MK"

# ZN-M2 没有无线，不再打包 ath11k 校准文件
sed -i '/^define Device\/zn_m2$/,/^endef$/s/^\([[:space:]]*DEVICE_PACKAGES[[:space:]]*:=[[:space:]]*\).*/\1/' "$IMAGE_MK"

if sed -n '/^define Device\/zn_m2$/,/^endef$/p' "$IMAGE_MK" | grep -q ipq-wifi; then
	echo "警告：zn_m2 仍带 ipq-wifi 校准包（不影响无 WiFi 运行）" >&2
fi
