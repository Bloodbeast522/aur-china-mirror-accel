#!/usr/bin/env bash
# aur-china-mirror-accel 一键安装脚本 (AUR 国内镜像加速 + 安全审查)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
MAKEPKG_CONF="$HOME/.config/pacman/makepkg.conf"
PIP_CONF="$HOME/.config/pip/pip.conf"
GITCONFIG_SYS="/etc/makepkg.d/gitconfig"

echo "==> 0/8 检查/安装依赖 aria2 + git(pacman -U 不自动装依赖,这里自管)"
for dep in aria2 git; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo "    未安装 $dep,现在自动安装(需要输入 sudo 密码)..."
        if sudo -n true 2>/dev/null; then
            sudo pacman -S --noconfirm "$dep"
        else
            echo "    无法免密执行 sudo,请手动运行: sudo pacman -S $dep"
            exit 1
        fi
    fi
done
command -v aria2c >/dev/null 2>&1 || { echo "错误: aria2 安装失败"; exit 1; }
echo "    ✓ aria2 + git 就绪"

echo "==> 1/8 安装脚本到 $BIN_DIR"
mkdir -p "$BIN_DIR"
for s in git aria2-ghproxy curl-ghproxy ghproxy-git-speedtest aur-audit; do
    install -m 755 "$SCRIPT_DIR/bin/$s" "$BIN_DIR/$s"
    echo "    ✓ $s"
done

case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) echo "    ⚠ $BIN_DIR 不在 PATH,请加入: export PATH=\"$BIN_DIR:\$PATH\"" ;;
esac

echo "==> 2/8 部署 AUR 安全审查包装(按你的 shell 自动选择)"
if [[ "$SHELL" == *fish* ]] && command -v fish >/dev/null 2>&1; then
    mkdir -p "$HOME/.config/fish/functions"
    if [[ -f "$HOME/.config/fish/functions/paru.fish" ]]; then
        echo "    已存在 ~/.config/fish/functions/paru.fish,覆盖为新版"
    fi
    install -m 644 "$SCRIPT_DIR/templates/paru.fish" "$HOME/.config/fish/functions/paru.fish"
    echo "    ✓ fish 包装已安装(新开终端生效)"
elif [[ -f "$HOME/.bashrc" ]]; then
    if grep -q "AUR 安全审查包装" "$HOME/.bashrc"; then
        echo "    已存在,跳过"
    else
        cat >> "$HOME/.bashrc" <<'EOF'

# >>> aur-china-mirror-accel: AUR 安全审查包装(防投毒) >>>
EOF
        cat "$SCRIPT_DIR/templates/paru.bash" >> "$HOME/.bashrc"
        cat >> "$HOME/.bashrc" <<'EOF'
# <<< aur-china-mirror-accel: AUR 安全审查包装 >>>
EOF
        echo "    ✓ bash 包装已追加到 ~/.bashrc(重新打开终端生效)"
    fi
else
    echo "    ⚠ 未识别的 shell($SHELL),审查包装未自动安装:"
    echo "      fish 用户: 复制 templates/paru.fish 到 ~/.config/fish/functions/"
    echo "      bash 用户: 把 templates/paru.bash 追加到 ~/.bashrc"
fi

echo "==> 3/8 配置 makepkg DLAGENT(源码下载走 aria2 镜像)"
mkdir -p "$(dirname "$MAKEPKG_CONF")"
if [[ -f "$MAKEPKG_CONF" ]] && grep -q "aria2-ghproxy" "$MAKEPKG_CONF"; then
    echo "    已存在,跳过"
else
    cat >> "$MAKEPKG_CONF" <<EOF

# aur-china-mirror-accel: AUR 源码下载走 aria2 + ghproxy 镜像 (https://github.com/Bloodbeast522/aur-china-mirror-accel)
'https::$BIN_DIR/aria2-ghproxy -UWget -s16 -x16 -o %o %u'
'http::$BIN_DIR/aria2-ghproxy -UWget -s16 -x16 -o %o %u'
EOF
    echo "    ✓ DLAGENT 已追加"
fi

echo "==> 4/8 配置 /etc/makepkg.d/gitconfig(git 克隆走镜像,需要 sudo)"
if [[ -f "$GITCONFIG_SYS" ]] && grep -q "ghfast" "$GITCONFIG_SYS"; then
    echo "    已存在,跳过"
elif ! sudo -n true 2>/dev/null; then
    echo "    ⚠ 需要 sudo 写入 /etc/makepkg.d/gitconfig,但当前无法免密执行。"
    echo "      请手动运行: sudo tee $GITCONFIG_SYS <<'EOF'"
    echo "      [url \"https://ghfast.top/https://github.com/\"]"
    echo "          insteadOf = https://github.com/"
    echo "      EOF"
    echo "      (否则 -git 包克隆不会走镜像!)"
else
    sudo mkdir -p /etc/makepkg.d
    sudo tee "$GITCONFIG_SYS" > /dev/null <<'EOF'
# aur-china-mirror-accel: makepkg 构建时 git 走镜像 (makepkg 屏蔽 ~/.gitconfig,只读这里)
[url "https://ghfast.top/https://github.com/"]
	insteadOf = https://github.com/
EOF
    echo "    ✓ gitconfig 已写入(关键!否则 -git 包克隆无效)"
fi

echo "==> 5/8 配置 /etc/gai.conf 优先 IPv4(AUR 官方接口 IPv6 掐连接,需要 sudo)"
if grep -q "^precedence ::ffff:0:0/96" /etc/gai.conf 2>/dev/null; then
    echo "    已存在,跳过"
elif ! sudo -n true 2>/dev/null; then
    echo "    ⚠ 需要 sudo 写入 /etc/gai.conf,但当前无法免密执行。"
    echo "      请手动运行: sudo sed -i 's/^#precedence ::ffff:0:0\\/96/precedence ::ffff:0:0\\/96/' /etc/gai.conf"
    echo "      (否则 paru 查更新/拉 PKGBUILD 会随机失败,报 SSL unexpected eof)"
else
    sudo sed -i 's/^#precedence ::ffff:0:0\/96/precedence ::ffff:0:0\/96/' /etc/gai.conf
    if grep -q "^precedence ::ffff:0:0/96" /etc/gai.conf; then
        echo "    ✓ gai.conf 已启用 IPv4 优先"
    else
        echo "precedence ::ffff:0:0/96  100" | sudo tee -a /etc/gai.conf > /dev/null
        echo "    ✓ gai.conf 已追加 IPv4 优先规则"
    fi
fi

echo "==> 6/8 配置 pip 镜像(解决 Python 包 pip 下载被墙)"
mkdir -p "$(dirname "$PIP_CONF")"
if [[ -f "$PIP_CONF" ]] && grep -q "tuna" "$PIP_CONF"; then
    echo "    已存在,跳过"
else
    cat > "$PIP_CONF" <<'EOF'
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
EOF
    echo "    ✓ pip.conf 已写入"
fi

echo "==> 7/8 运行镜像测速,设置用户级 git insteadOf(手动 clone 也加速)"
"$BIN_DIR/ghproxy-git-speedtest" || echo "    ⚠ 测速失败,可稍后重试"

echo "==> 8/8 完成"
echo ""
echo "✅ 安装完成!现在 paru -S 任意包都会自动加速:"
echo "  - -git 包    → partial clone + ghfast.top 镜像"
echo "  - -bin 包    → aria2 + gh-proxy.com 镜像"
echo "  - 源码 tar.gz → aria2 多线程"
echo "  - Python 依赖 → 清华 pip 镜像"
echo "  - AUR 官方接口 → gai.conf 全局优先 IPv4(解决 IPv6 随机掐连接)"
echo "  - AUR 安全审查 → 装/更新前自动扫 PKGBUILD,高危拦截 (--noaudit 跳过)"
echo ""
echo "验证:"
echo "  git config --global --get-regexp 'url.*insteadof'"
echo "  grep -E 'https::|http::' ~/.config/pacman/makepkg.conf"
echo "  cat /etc/makepkg.d/gitconfig"
echo "  cat ~/.config/pip/pip.conf"
echo "  grep '^precedence' /etc/gai.conf"
echo "  ~/.local/bin/aur-audit --selftest"
