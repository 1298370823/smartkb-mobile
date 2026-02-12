[app]
title = 智能运维问答系统
package.name = smartkb
package.domain = org.smartkb

source.dir = .
source.include_exts = py,png,jpg,kv,atlas,txt,json

version = 1.0.0
version.regex = __version__ = ['"](.*)['"]
version.filename = %(source.dir)s/main.py

requirements = python3,kivy,jieba

android.permissions = INTERNET, READ_EXTERNAL_STORAGE

android.api = 33
android.minapi = 21
android.ndk = 25b
android.sdk = 33

android.gradle_dependencies = 'com.android.support:support-annotations:28.0.0'

# 添加数据文件
source.include_exts = py,png,jpg,kv,atlas,txt,json
source.include_patterns = data/*.json

# 颜色主题
android.accept_sdk_license = True

[buildozer]
log_level = 2

[requirements]
# 已在上方 requirements 中指定