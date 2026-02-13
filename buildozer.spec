name: Build APK

on:
  push:
    branches: [ "main" ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-python@v5
        with:
          python-version: '3.10'
          
      - name: Install system dependencies
        run: |
          sudo apt update
          sudo apt install -y git zip unzip openjdk-17-jdk python3-pip autoconf libtool \
            pkg-config zlib1g-dev libncurses5-dev libncursesw5-dev libtinfo5 cmake \
            libffi-dev libssl-dev
          
      - name: Install Buildozer
        run: |
          pip install --upgrade pip
          pip install Cython buildozer
          
      - name: Clear NDK environment and build APK
        run: |
          # 彻底清除系统 NDK 环境变量（关键！）
          unset ANDROID_NDK
          unset ANDROID_NDK_HOME
          unset ANDROID_NDK_ROOT
          # 执行打包
          buildozer android debug
          
      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: smartkb-apk
          path: bin/*.apk
