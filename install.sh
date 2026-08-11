#!/usr/bin/env bash
# aur-china-mirror-accel 一键安装脚本 (AUR 国内镜像加速)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
MAKEPKG_CONF="$HOME/.config/pacman/makepkg.conf"
PIP_CONF="$HOME/.config/pip/pip.conf"
GITCONFIG_SYS="/etc/makepkg.d/gitconfig"

echo "==> 0/6 检查/安装依赖 aria2"
if ! command -v aria2c >/dev/null 2>&1; then
    echo "    未安装 aria2,现在自动安装(需要输入 sudo 密码)..."
    if sudo -n true 2>/dev/null; then
        sudo pacman -S --noconfirm aria2
    else
        echo "    无法免密执行 sudo,请手动运行: sudo pacman -S aria2"
        exit 1
    fi
fi
command -v aria2c >/dev/null 2>&1 || { echo "错误: aria2 安装失败"; exit 1; }
echo "    ✓ aria2 就绪"

echo "==> 1/6 安装脚本到 $BIN_DIR"
mkdir -p "$BIN_DIR"
for s in git aria2-ghproxy curl-ghproxy ghproxy-git-speedtest; do
    install -m 755 "$SCRIPT_DIR/bin/$s" "$BIN_DIR/$s"
    echo "    ✓ $s"
done

case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) echo "    ⚠ $BIN_DIR 不在 PATH,请加入: export PATH=\"$BIN_DIR:\$PATH\"" ;;
esac

echo "==> 2/6 配置 makepkg DLAGENT(源码下载走 aria2 镜像)"
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

echo "==> 3/6 配置 /etc/makepkg.d/gitconfig(git 克隆走镜像,需要 sudo)"
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

echo "==> 4/6 配置 pip 镜像(解决 Python 包 pip 下载被墙)"
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

echo "==> 5/6 运行镜像测速,设置用户级 git insteadOf(手动 clone 也加速)"
"$BIN_DIR/ghproxy-git-speedtest" || echo "    ⚠ 测速失败,可稍后重试"

echo "==> 6/6 完成"
echo ""
echo "✅ 安装完成!现在 paru -S 任意包都会自动加速:"
echo "  - -git 包    → partial clone + ghfast.top 镜像"
echo "  - -bin 包    → aria2 + gh-proxy.com 镜像"
echo "  - 源码 tar.gz → aria2 多线程"
echo "  - Python 依赖 → 清华 pip 镜像"
echo ""
echo "验证:"
echo "  git config --global --get-regexp 'url.*insteadof'"
echo "  grep -E 'https::|http::' ~/.config/pacman/makepkg.conf"
echo "  cat /etc/makepkg.d/gitconfig"
echo "  cat ~/.config/pip/pip.conf"
