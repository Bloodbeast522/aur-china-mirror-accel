#!/usr/bin/env bash
# aur-ghproxy-accel 一键安装脚本
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
MAKEPKG_CONF="$HOME/.config/pacman/makepkg.conf"

echo "==> 检查依赖"
command -v aria2c >/dev/null || { echo "错误: 需要 aria2 (sudo pacman -S aria2)"; exit 1; }
command -v git >/dev/null || { echo "错误: 需要 git"; exit 1; }

echo "==> 1/4 拷贝脚本到 $BIN_DIR"
mkdir -p "$BIN_DIR"
for s in git aria2-ghproxy curl-ghproxy ghproxy-git-speedtest; do
    install -m 755 "$SCRIPT_DIR/bin/$s" "$BIN_DIR/$s"
    echo "    ✓ $s"
done

# 确保 ~/.local/bin 在 PATH 最前(否则 git 包装器不生效)
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) echo "    ⚠ $BIN_DIR 不在 PATH 中,请加入: export PATH=\"$BIN_DIR:\$PATH\"" ;;
esac

echo "==> 2/4 配置 makepkg DLAGENT"
mkdir -p "$(dirname "$MAKEPKG_CONF")"
if [[ -f "$MAKEPKG_CONF" ]] && grep -q "aria2-ghproxy" "$MAKEPKG_CONF"; then
    echo "    已存在 aria2-ghproxy 配置,跳过"
else
    cat >> "$MAKEPKG_CONF" <<EOF

# aur-ghproxy-accel: AUR 源码下载走 aria2 + ghproxy 镜像 (https://github.com/Bloodbeast522/aur-ghproxy-accel)
'https::$BIN_DIR/aria2-ghproxy -UWget -s16 -x16 -o %o %u'
'http::$BIN_DIR/aria2-ghproxy -UWget -s16 -x16 -o %o %u'
EOF
    echo "    已追加 DLAGENT"
fi

echo "==> 3/4 运行镜像测速,设置 git insteadOf"
"$BIN_DIR/ghproxy-git-speedtest" || echo "    ⚠ 测速失败(可能全部镜像暂时不可用),可稍后重试"
git config --global --get-regexp 'url.*insteadof' || true

echo "==> 4/4 完成"
echo ""
echo "验证:"
echo "  grep -E 'https::|http::' ~/.config/pacman/makepkg.conf"
echo "  git config --global --get-regexp 'url.*insteadof'"
echo "  ~/.local/bin/aria2-ghproxy -UWget -s16 -x16 -o /tmp/x.part https://github.com/foo/bar/releases/download/v1/x.tar.gz"
echo ""
echo "下次 paru -S 任意 -git / -bin 包即自动走镜像。"
