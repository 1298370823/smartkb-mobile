[app]
title = 智能运维问答系统
package.name = smartkb
package.domain = org.smartkb
source.dir = .
source.include_exts = py,png,jpg,kv,atlas,txt,json
version = 1.0.0
requirements = python3,kivy,jieba
android.permissions = INTERNET, READ_EXTERNAL_STORAGE
android.api = 30
android.minapi = 21
android.ndk = 23c
android.sdk = 30
android.gradle_dependencies = 'com.android.support:support-annotations:28.0.0'
source.include_patterns = data/*.json
android.accept_sdk_license = True

[buildozer]
log_level = 2
