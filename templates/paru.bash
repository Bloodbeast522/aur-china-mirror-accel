# ============================================================
# aur-china-mirror-accel: AUR 安全审查包装 (bash 版)
# 安装方式:把本文件内容追加到 ~/.bashrc,然后执行 source ~/.bashrc
#           (install.sh 会自动完成,无需手动操作)
# 作用:每次 paru -S 安装 / -Syu 更新 AUR 包前,自动审查 PKGBUILD,
#       发现高风险项(curl|bash 远程脚本、base64 混淆、后门等)时拦下询问。
# 跳过审查:paru --noaudit ...
# 注意:sudo paru 会直接调用二进制,绕过本函数(paru 自己会 sudo,正常用不到)
# ============================================================
paru() {
    local skip=0 noconfirm=0 has_u=0 has_U=0
    local a ans
    local -a pkgs=() targets=() realargs=()

    # ---- 解析参数 ----
    for a in "$@"; do
        case "$a" in
            --noaudit) skip=1 ;;
            --noconfirm) noconfirm=1 ;;
            --sync|--sysupgrade)
                [[ "$a" == "--sysupgrade" ]] && has_u=1 ;;
            -S*)
                [[ "$a" =~ ^-[a-zA-Z]*u ]] && has_u=1
                # s=搜索 i=信息 g=获取 不涉及安装,跳过审查
                [[ "$a" =~ ^-[a-zA-Z]*[sig] ]] && skip=1
                ;;
            -U*) has_U=1 ;;
            -*) ;;
            *) pkgs+=("$a") ;;
        esac
    done
    # 过滤 --noaudit(paru 不认这个参数,必须去掉)
    for a in "$@"; do
        [[ "$a" != "--noaudit" ]] && realargs+=("$a")
    done

    if (( skip )); then
        command paru "${realargs[@]}"
        return $?
    fi

    # ---- 收集审查目标 ----
    if (( has_u )); then
        # -Su/-Syu: 列出 AUR 更新包
        while IFS= read -r line; do
            local name="${line%% *}"
            [[ -n "$name" ]] && targets+=("$name")
        done < <(command paru -Qua 2>/dev/null)
    fi
    targets+=("${pkgs[@]}")
    if (( ${#targets[@]} > 0 )); then
        mapfile -t targets < <(printf '%s\n' "${targets[@]}" | sort -u)
    fi

    if (( has_U )); then
        echo "⚠ -U 安装本地包文件,无法审查 PKGBUILD" >&2
    fi

    # ---- 逐个审查 ----
    for p in "${targets[@]}"; do
        "$HOME/.local/bin/aur-audit" "$p"
        local rc=$?
        case $rc in
            1)
                if (( noconfirm )); then
                    echo "已中止(--noconfirm 模式下不允许带风险继续)。" >&2
                    return 1
                fi
                read -r -p "  检测到高风险项!仍要继续安装吗? [y/N] " ans
                if [[ ! "$ans" =~ ^[yY] ]]; then
                    echo "已中止安装。" >&2
                    return 1
                fi
                ;;
            2)
                echo "⚠ 审查失败(网络?):放行 $p" >&2
                ;;
        esac
    done

    # ---- 执行真正的 paru ----
    command paru "${realargs[@]}"
    return $?
}
