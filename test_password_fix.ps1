# PowerShell 测试脚本
Write-Host "=== WiFi 密码修复测试 ==="

# 创建临时目录
$tempDir = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path ($_.DirectoryName + "\" + $_.BaseName) }
Write-Host "测试目录: $tempDir"

# 创建测试文件
$testScript = @'
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

# 测试密码
WRT_WORD="09161209"
escaped_word=$(escape_sed_replacement "$WRT_WORD")
echo "原始密码: $WRT_WORD"
echo "转义后密码: $escaped_word"

# 测试 sed 命令
echo "BASE_WORD='default'" > test.txt
sed -i "s|BASE_WORD='.*'|BASE_WORD='$escaped_word'|g" test.txt
echo "文件内容: $(cat test.txt)"

# 验证
if grep -q "BASE_WORD='09161209'" test.txt; then
    echo "✓ 测试通过：密码正确保留前导0"
else
    echo "✗ 测试失败：密码可能丢失前导0"
    echo "实际内容: $(cat test.txt)"
fi
'@

# 保存测试脚本
$testScriptPath = Join-Path $tempDir "test.sh"
$testScript | Out-File -FilePath $testScriptPath -Encoding UTF8

# 在 WSL 或 Git Bash 中运行（如果可用）
if (Get-Command wsl -ErrorAction SilentlyContinue) {
    Write-Host "使用 WSL 运行测试..."
    wsl bash $testScriptPath
} elseif (Get-Command bash -ErrorAction SilentlyContinue) {
    Write-Host "使用 Git Bash 运行测试..."
    bash $testScriptPath
} else {
    Write-Host "无法找到 bash 环境，跳过测试"
    Write-Host "但修复已经应用："
    Write-Host "1. 添加了 escape_sed_replacement() 函数"
    Write-Host "2. 使用 | 作为 sed 分隔符"
    Write-Host "3. 密码 '09161209' 应该能正确保留前导0"
}

# 清理
Remove-Item -Path $tempDir -Recurse -Force
Write-Host "=== 测试完成 ==="