#!/bin/bash
# WiFi 密码修复测试脚本
# 用于验证 Settings.sh 中 sed 命令正确处理各种密码

set -e

echo "=== WiFi 密码修复测试开始 ==="

# 创建临时目录
tmpdir=$(mktemp -d)
cd "$tmpdir"
echo "测试目录: $tmpdir"

# 复制修改后的 Settings.sh（仅相关部分）
# 我们只测试 WiFi 配置部分，因此创建一个模拟脚本
cat > test_settings.sh <<'EOF'
#!/bin/bash
# 转义 sed 替换字符串中的特殊字符
escape_sed_replacement() {
    local str="$1"
    local delimiter="${2:-|}"
    # 转义反斜杠
    str="${str//\\/\\\\}"
    # 转义 &（在替换中表示匹配的整个文本）
    str="${str//&/\\&}"
    # 转义分隔符
    str="${str//${delimiter}/\\${delimiter}}"
    echo "$str"
}

# 模拟环境变量
WRT_SSID="$1"
WRT_WORD="$2"

# 模拟 set-wireless.sh 文件
WIFI_SH="./set-wireless.sh"
cat > $WIFI_SH <<'INNER'
BASE_SSID='OpenWrt'
BASE_WORD='default'
INNER

# 模拟 mac80211.uc 文件
mkdir -p package/network/config/wifi-scripts/files/lib/wifi/
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
cat > $WIFI_UC <<'INNER'
ssid='OpenWrt'
key='default'
country='CN'
encryption='psk2'
INNER

# 应用修改（模拟 Settings.sh 的逻辑）
if [ -f "$WIFI_SH" ]; then
    escaped_ssid=$(escape_sed_replacement "$WRT_SSID")
    sed -i "s|BASE_SSID='.*'|BASE_SSID='$escaped_ssid'|g" $WIFI_SH
    escaped_word=$(escape_sed_replacement "$WRT_WORD")
    sed -i "s|BASE_WORD='.*'|BASE_WORD='$escaped_word'|g" $WIFI_SH
fi

if [ -f "$WIFI_UC" ]; then
    escaped_ssid=$(escape_sed_replacement "$WRT_SSID")
    sed -i "s|ssid='.*'|ssid='$escaped_ssid'|g" $WIFI_UC
    escaped_word=$(escape_sed_replacement "$WRT_WORD")
    sed -i "s|key='.*'|key='$escaped_word'|g" $WIFI_UC
    sed -i "s|country='.*'|country='AU'|g" $WIFI_UC
    sed -i "s|encryption='.*'|encryption='psk2+ccmp'|g" $WIFI_UC
fi

# 输出结果
echo "=== set-wireless.sh 内容 ==="
cat $WIFI_SH
echo "=== mac80211.uc 内容 ==="
cat $WIFI_UC
EOF

chmod +x test_settings.sh

# 定义测试用例
test_cases=(
    "09161209"
    "pass/word&123"
    "it'spassword"
    'pass\word'
    ""
    "123456789012345678901234567890"
    "0"
    "0000"
    "password|withpipe"
    "special&char"
    "multi'line\"quotes"
)

# 运行每个测试用例
for password in "${test_cases[@]}"; do
    echo ""
    echo "--- 测试密码: '$password' ---"
    # 使用固定 SSID
    ./test_settings.sh "MyWiFi" "$password"
    
    # 验证 set-wireless.sh
    if grep -q "BASE_WORD='$password'" set-wireless.sh 2>/dev/null; then
        echo "✓ set-wireless.sh 密码匹配"
    else
        # 由于转义，可能需要检查转义后的版本
        escaped=$(./test_settings.sh "MyWiFi" "$password" 2>&1 | grep -o "BASE_WORD='.*'" | head -1)
        if [[ "$escaped" == *"$password"* ]]; then
            echo "✓ set-wireless.sh 密码包含（可能转义）"
        else
            echo "✗ set-wireless.sh 密码不匹配"
            echo "   实际: $escaped"
        fi
    fi
    
    # 验证 mac80211.uc
    if grep -q "key='$password'" package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc 2>/dev/null; then
        echo "✓ mac80211.uc 密码匹配"
    else
        escaped=$(./test_settings.sh "MyWiFi" "$password" 2>&1 | grep -o "key='.*'" | head -1)
        if [[ "$escaped" == *"$password"* ]]; then
            echo "✓ mac80211.uc 密码包含（可能转义）"
        else
            echo "✗ mac80211.uc 密码不匹配"
            echo "   实际: $escaped"
        fi
    fi
done

# 清理
cd /
rm -rf "$tmpdir"

echo ""
echo "=== 测试完成 ==="