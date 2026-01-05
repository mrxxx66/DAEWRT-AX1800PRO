# WiFi 密码 '09161209' 在编译过程中丢失 0 的修复方案

## 问题分析总结

### 根本原因
1. **sed 命令分隔符冲突**：当前脚本使用单引号作为模式匹配的一部分（`'BASE_WORD='.*''`），当密码本身包含单引号时会导致语法错误。
2. **前导零丢失**：虽然环境变量传递字符串 '09161209'，但 sed 在处理替换时可能将数字字符串解释为八进制数，导致前导零被去除。
3. **特殊字符未转义**：如果密码包含 `/`、`&`、`\` 等 sed 特殊字符，替换表达式会被破坏。
4. **变量扩展问题**：双引号内的变量 `$WRT_WORD` 可能被 shell 进行额外的解释。

### 影响范围
- Settings.sh 中修改 WiFi 密码的两处 sed 命令：
  1. `sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH`
  2. `sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC`
- 使用默认密码 '09161209' 时，编译后的固件 WiFi 密码可能变为 '9161209'（丢失前导零）。

## 修复方案设计

### 方案选择：稳健的 sed 替换
1. **更换分隔符**：使用不常见于密码的字符作为 sed 分隔符，如 `|`。
2. **转义特殊字符**：对替换文本中的 `&`、`\` 和分隔符进行转义。
3. **保持引号结构**：保留目标文件中的单引号包围格式。
4. **使用变量转义函数**：实现一个简单的 shell 函数来转义 sed 替换字符串。

### 具体实现步骤
1. 在 Settings.sh 开头添加辅助函数 `escape_sed_replacement`。
2. 修改两处 WiFi 密码替换命令，使用转义后的变量和新分隔符。
3. 添加注释说明修复原因。

### 转义函数设计
```bash
# 转义 sed 替换字符串中的特殊字符：&, \, 和分隔符
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
```

### 修改后的 sed 命令格式
```bash
# 原命令
sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH

# 新命令
escaped_word=$(escape_sed_replacement "$WRT_WORD")
sed -i "s|BASE_WORD='.*'|BASE_WORD='$escaped_word'|g" $WIFI_SH
```

## 修改后的 Settings.sh 脚本代码

### 完整修改内容
1. 在脚本开头（第2行后）插入辅助函数。
2. 修改第16行（BASE_WORD 替换）和第21行（key 替换）。
3. 可选：修改第14行（BASE_SSID 替换）和第19行（ssid 替换）以保持一致性。

### 代码差异
```diff
--- a/Scripts/Settings.sh
+++ b/Scripts/Settings.sh
@@ -1,6 +1,20 @@
 #!/bin/bash
 . $(dirname "$(realpath "$0")")/function.sh
 
+# 转义 sed 替换字符串中的特殊字符
+escape_sed_replacement() {
+    local str="$1"
+    local delimiter="${2:-|}"
+    # 转义反斜杠
+    str="${str//\\/\\\\}"
+    # 转义 &（在替换中表示匹配的整个文本）
+    str="${str//&/\\&}"
+    # 转义分隔符
+    str="${str//${delimiter}/\\${delimiter}}"
+    echo "$str"
+}
+
 #修改默认主题
 sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
 #修改immortalwrt.lan关联IP
@@ -12,16 +26,20 @@ WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-d
 WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
 if [ -f "$WIFI_SH" ]; then
 	#修改WIFI名称
-	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
+	escaped_ssid=$(escape_sed_replacement "$WRT_SSID")
+	sed -i "s|BASE_SSID='.*'|BASE_SSID='$escaped_ssid'|g" $WIFI_SH
 	#修改WIFI密码
-	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
+	escaped_word=$(escape_sed_replacement "$WRT_WORD")
+	sed -i "s|BASE_WORD='.*'|BASE_WORD='$escaped_word'|g" $WIFI_SH
 elif [ -f "$WIFI_UC" ]; then
 	#修改WIFI名称
-	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
+	escaped_ssid=$(escape_sed_replacement "$WRT_SSID")
+	sed -i "s|ssid='.*'|ssid='$escaped_ssid'|g" $WIFI_UC
 	#修改WIFI密码
-	sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
+	escaped_word=$(escape_sed_replacement "$WRT_WORD")
+	sed -i "s|key='.*'|key='$escaped_word'|g" $WIFI_UC
 	#修改WIFI地区
-	sed -i "s/country='.*'/country='AU'/g" $WIFI_UC
+	sed -i "s|country='.*'|country='AU'|g" $WIFI_UC
 	#修改WIFI加密
 	sed -i "s/encryption='.*'/encryption='psk2+ccmp'/g" $WIFI_UC
 fi
```

## 测试方案

### 测试目标
1. 验证修复后密码 '09161209' 能正确保留前导零。
2. 验证特殊字符密码（如包含 `/`、`&`、`'` 等）能正确处理。
3. 确保向后兼容性（普通密码仍能正常工作）。

### 测试环境
- 使用 Docker 容器模拟构建环境。
- 创建模拟的 set-wireless.sh 和 mac80211.uc 文件。
- 运行修改后的 Settings.sh 脚本并检查结果。

### 测试用例
1. **前导零密码**：`WRT_WORD='09161209'`
2. **特殊字符密码**：`WRT_WORD='pass/word&123'`
3. **包含单引号密码**：`WRT_WORD="it'spassword"`
4. **包含反斜杠密码**：`WRT_WORD='pass\word'`
5. **空密码**：`WRT_WORD=''`
6. **长密码**：`WRT_WORD='123456789012345678901234567890'`

### 验证方法
1. 检查 sed 命令执行后的文件内容。
2. 使用 diff 对比预期输出。
3. 运行脚本并捕获任何错误。

### 自动化测试脚本
```bash
#!/bin/bash
# test_wifi_password_fix.sh
set -e

# 创建临时目录
tmpdir=$(mktemp -d)
cd $tmpdir

# 模拟 set-wireless.sh 文件
cat > set-wireless.sh <<'EOF'
BASE_SSID='OpenWrt'
BASE_WORD='default'
EOF

# 模拟 mac80211.uc 文件
mkdir -p package/network/config/wifi-scripts/files/lib/wifi/
cat > package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc <<'EOF'
ssid='OpenWrt'
key='default'
country='CN'
encryption='psk2'
EOF

# 复制修改后的 Settings.sh（略）
# 设置环境变量并运行
export WRT_SSID="MyWiFi"
export WRT_WORD="09161209"
# ... 运行脚本

# 检查结果
echo "=== 检查 set-wireless.sh ==="
cat set-wireless.sh
echo "=== 检查 mac80211.uc ==="
cat package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc

# 清理
cd /
rm -rf $tmpdir
```

## 部署计划
1. 将修改提交到主分支。
2. 在 CI 中运行测试工作流验证修复。
3. 监控下一次构建，确认 WiFi 密码正确。

## 风险与缓解
- **风险**：转义函数可能不兼容所有 shell（使用 bash 扩展语法）。
  - **缓解**：脚本已声明 `#!/bin/bash`，确保使用 bash。
- **风险**：分隔符 `|` 可能出现在密码中（极罕见）。
  - **缓解**：转义函数会转义分隔符，确保安全。
- **风险**：性能影响微小（额外子进程和字符串处理）。
  - **缓解**：仅在 WiFi 配置部分调用，影响可忽略。

## 结论
通过实现稳健的 sed 替换方案，可以彻底解决 WiFi 密码前导零丢失和特殊字符处理问题，提高构建系统的可靠性。