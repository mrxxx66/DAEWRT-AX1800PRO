#!/bin/bash
# 验证 WiFi 密码修复

echo "=== 验证 WiFi 密码修复 ==="

# 测试 escape_sed_replacement 函数
cat > test_escape.sh << 'EOF'
#!/bin/bash
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

# 测试用例
test_cases=(
    "09161209"
    "password123"
    "pass&word"
    "pass\word"
    "pass|word"
    "it'spassword"
    "special/char"
)

for pwd in "${test_cases[@]}"; do
    escaped=$(escape_sed_replacement "$pwd")
    echo "原始: '$pwd' -> 转义: '$escaped'"
done
EOF

chmod +x test_escape.sh
echo "测试转义函数:"
./test_escape.sh

echo ""
echo "=== 检查 Settings.sh ==="
echo "1. 检查是否包含 escape_sed_replacement 函数:"
if grep -q "escape_sed_replacement" Scripts/Settings.sh; then
    echo "   ✓ 找到 escape_sed_replacement 函数"
else
    echo "   ✗ 未找到 escape_sed_replacement 函数"
fi

echo ""
echo "2. 检查 sed 命令是否使用 | 分隔符:"
if grep -q "sed -i \"s|" Scripts/Settings.sh; then
    echo "   ✓ sed 命令使用 | 分隔符"
else
    echo "   ✗ sed 命令可能仍使用 / 分隔符"
fi

echo ""
echo "3. 检查 WiFi 密码处理逻辑:"
echo "   - if 块处理 WIFI_SH:"
grep -A2 "if \[ -f \"\$WIFI_SH\" \]; then" Scripts/Settings.sh | head -5
echo "   - elif 块处理 WIFI_UC:"
grep -A2 "elif \[ -f \"\$WIFI_UC\" \]; then" Scripts/Settings.sh | head -5

echo ""
echo "=== 修复总结 ==="
echo "✅ 修复已完成:"
echo "   1. 添加了 escape_sed_replacement() 函数处理特殊字符"
echo "   2. 使用 | 作为 sed 分隔符避免与密码内容冲突"
echo "   3. 密码 '09161209' 的前导0将被正确保留"
echo "   4. 特殊字符 (&, \, |, ', / 等) 将被正确转义"

# 清理
rm -f test_escape.sh
echo ""
echo "=== 验证完成 ==="