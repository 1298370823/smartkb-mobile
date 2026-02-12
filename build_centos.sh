#!/bin/bash
set -e

echo "========================================"
echo "智能运维问答系统 - 麒麟 V10 最终打包版"
echo "（适配 Java 11 + 手动安装 pip）"
echo "========================================"

# 1. 安装麒麟源中已有的依赖
echo "[1/6] 安装编译依赖（麒麟官方源）..."
sudo dnf install -y git zip unzip java-11-openjdk-devel \
    autoconf libtool pkgconfig zlib-devel ncurses-devel cmake \
    libffi-devel openssl-devel wget which

# 2. 手动安装 pip（麒麟源无 python3-pip 时）
echo "[2/6] 安装 pip..."
if ! command -v pip3 &> /dev/null; then
    sudo dnf install -y python3-pip || {
        echo "python3-pip 包不存在，使用 ensurepip 安装..."
        python3 -m ensurepip --upgrade
        python3 -m pip install --upgrade pip
    }
fi

# 3. 设置 JAVA_HOME（使用 Java 11）
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk
echo "export JAVA_HOME=$JAVA_HOME" >> ~/.bashrc

# 4. 安装 Python 打包工具
echo "[3/6] 安装 buildozer..."
pip3 install --user --upgrade pip
pip3 install --user --upgrade Cython buildozer
export PATH=$PATH:~/.local/bin
echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc

# 5. 创建项目目录并下载源码
echo "[4/6] 获取项目源码..."
mkdir -p ~/smart_kb_mobile
cd ~/smart_kb_mobile

# 使用国内镜像加速下载（若 GitHub 慢，替换为网盘链接）
wget https://github.com/smartkb/mobile-package/archive/refs/heads/main.zip -O smartkb.zip || {
    echo "GitHub 下载失败，尝试网盘备用链接（需手动下载）"
    echo "请手动下载 https://pan.baidu.com/s/1xxx 后解压到当前目录"
    exit 1
}
unzip -o smartkb.zip
cd mobile-package-main

# 6. 修改 buildozer.spec，降低 Java 版本要求
sed -i 's/android.api = 33/android.api = 30/' buildozer.spec
sed -i 's/android.ndk = 25b/android.ndk = 23c/' buildozer.spec
sed -i 's/requirements = .*/requirements = python3,kivy,jieba/' buildozer.spec

# 7. 执行打包
echo "[5/6] 开始打包 APK（首次运行自动下载 SDK/NDK，耗时约15分钟）..."
buildozer android debug

# 8. 导出 APK
echo "[6/6] 打包完成！"
cp bin/*.apk ~/smart_kb_mobile/
echo "✅ APK 位置: ~/smart_kb_mobile/smartkb-1.0.0-*-debug.apk"
