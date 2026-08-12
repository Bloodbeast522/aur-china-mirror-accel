# paru 安全审查包装函数
# 作用: 安装/更新 AUR 包前,自动用 aur-audit.py 审查 PKGBUILD,
#       发现高风险项时拦下询问,确认后才继续。
# 跳过审查: 加 --noaudit 参数; 或 sudo paru(直接调用二进制,绕过本函数)
function paru --wraps=paru
    set -l skip 0
    set -l noconfirm 0
    set -l has_S 0
    set -l has_u 0
    set -l has_U 0
    set -l pkgs

    # ---- 解析参数 ----
    for a in $argv
        switch $a
            case '--noaudit'
                set skip 1
            case '--noconfirm'
                set noconfirm 1
            case '--sync' '--sysupgrade'
                set has_S 1
            case '-S*'
                set has_S 1
                string match -qr '^-[a-zA-Z]*u' -- $a; and set has_u 1
                # s=搜索 i=信息 g=获取 不涉及安装,跳过审查
                string match -qr '^-[a-zA-Z]*[sig]' -- $a; and set skip 1
            case '-U*'
                set has_U 1
            case '-*'
                # 其他选项,忽略
            case '*'
                set -a pkgs $a
        end
    end

    if test $skip -eq 1
        command paru (string match -v -- '--noaudit' $argv)
        return $status
    end

    # ---- 收集审查目标 ----
    set -l targets
    if test $has_u -eq 1
        # -Su/-Syu: 列出 AUR 更新包
        for line in (command paru -Qua 2>/dev/null)
            set -l name (string split ' ' -- $line)[1]
            test -n "$name"; and set -a targets $name
        end
    end
    if test (count $pkgs) -gt 0
        for p in $pkgs
            set -a targets $p
        end
    end
    if test (count $targets) -gt 0
        set targets (printf '%s\n' $targets | sort -u)
    end

    if test $has_U -eq 1
        set_color yellow; echo "⚠ -U 安装本地包文件,无法审查 PKGBUILD"; set_color normal
    end

    # ---- 逐个审查 ----
    for p in $targets
        ~/.local/bin/aur-audit $p
        switch $status
            case 1
                if test $noconfirm -eq 0
                    read -P '  检测到高风险项!仍要继续安装吗? [y/N] ' ans
                    if not string match -qr '^[yY]' -- "$ans"
                        set_color red; echo "已中止安装。"; set_color normal
                        return 1
                    end
                else
                    set_color red; echo "已中止(--noconfirm 模式下不允许带风险继续)。"; set_color normal
                    return 1
                end
            case 2
                set_color yellow; echo "⚠ 审查失败(网络?):放行 $p"; set_color normal
        end
    end

    # ---- 执行真正的 paru(过滤掉 --noaudit) ----
    command paru (string match -v -- '--noaudit' $argv)
    return $status
end
