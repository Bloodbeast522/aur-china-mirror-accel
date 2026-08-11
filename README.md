# AUR 更新加速 (aur-update-accel)

> 計画通り。纯 AI 编写,作者毫无经验,基本不会更新,对项目不承担任何责任。
> (此简介也是 AI 编写)

English: A China-friendly helper for Arch/CachyOS that makes `paru -S` work
without a proxy — partial-clone + multi-mirror for `-git` packages, aria2
multi-mirror DLAGENT for releases, TUNA pip mirror for Python deps.
Works everywhere, designed for mainland China.

## 这个项目是干嘛的

一句话:**让 CachyOS / Arch 在国内没有代理的情况下,`paru -S` 更新和安装 AUR 包不再卡死。**

AUR 构建其实有 4 条下载链路,每条都被墙或龟速,本方案全部覆盖:

| # | 链路 | 问题 | 解决方案 |
|---|---|---|---|
| 1 | **`-git` 包克隆** | makepkg 用 `git clone --mirror` 拉全部 refs(含几百个 PR refs),几百 MB 在 GitHub 直连/镜像下卡死 | git 包装器自动加 partial clone(`--filter=blob:none`,体积缩到 1/10)+ **多镜像容错**(ghfast.top → gh-proxy.com → ghproxy.net → 直连,失败自动切换) |
| 2 | **`-bin` 包 release 下载** | GitHub release 文件被墙 | DLAGENT 换成 aria2-ghproxy:16 线程 + 多镜像自动回退(gh-proxy.com → ghproxy.net → 直连) |
| 3 | **源码 tar.gz 下载** | GitHub 源码归档慢 | 同一个 DLAGENT,aria2 16 线程 |
| 4 | **Python 依赖(pip)** | AUR Python 包 package() 里 pip 直连 PyPI 被重置(ConnectionResetError 104) | 用户级 `~/.config/pip/pip.conf` 指向清华镜像,所有 venv 的 pip 自动生效 |

另外还有一个**隐藏坑**:makepkg 主动屏蔽 `~/.gitconfig`(`GIT_CONFIG_GLOBAL=/dev/null`),
所以 git 镜像规则写在用户级对 `-git` 包克隆**无效**——必须写进
`/etc/makepkg.d/gitconfig`(makepkg 官方支持的 `GIT_CONFIG_SYSTEM` 入口)。
本方案自动处理。

四条链路互不干扰,一次配置永久生效,每个环节都有镜像兜底。

## 为什么要开源

这个项目存在的意义,就是**解决我自己 CachyOS 系统在国内无代理情况下 AUR 更新和安装包的问题**。踩坑踩出来的组合方案,网上没找到现成的,就开源出来——万一有同样处境的人,能省点事。

## 郑重声明

- **纯 AI 编写**:本项目由 AI 生成,作者本人对 Arch、AUR、Shell 脚本**毫无经验**,代码能跑全靠 AI 和反复试错,里面可能有你看不懂的怪写法。
- **基本不会更新**:能用就行,坏了大概率也不会修。镜像站变动、makepkg 改版……一切后果自负。
- **不承担任何责任**:用这个项目导致系统损坏、数据丢失、包坏掉,作者概不负责。**用之前请先读代码**,别盲信。
- **此简介也是 AI 编写。**

---

# 安装指南(新手向,一步一步来)

> 本文假设你用的是 Arch / CachyOS / EndeavourOS 等 Arch 系系统。
> 全程只需要一个终端窗口,跟着做就行。

## 方法一:AUR 安装(⚠️ 当前不可用,跳过)

```bash
paru -S aur-update-accel
```

> **⚠️ 暂不可用**:AUR 的开放注册目前是关闭状态(注册页返回 503),
> 作者没有 AUR 账号,所以这个包还没能提交上去。
> **别等了,直接用下面的方法二**,效果完全一样。

## 方法二:GitHub Release 直接安装(预编译包,推荐)

不用克隆仓库、不用等 AUR、不用手动装依赖。3 步全搞定:

```bash
# 第 1 步:下载预编译包(约 17KB,极快)
wget https://github.com/Bloodbeast522/aur-update-accel/releases/download/v1.0.0/aur-update-accel-1.0.0-3-any.pkg.tar.zst

# 第 2 步:安装(aria2 不需要手动装,setup 会自动装)
sudo pacman -U aur-update-accel-1.0.0-3-any.pkg.tar.zst

# 第 3 步:一键配置(自动装 aria2 → 配全部 4 条链路 → 测速选镜像)
aur-update-accel-setup
```

`aur-update-accel-setup` 会自动完成:
1. 检测 aria2,没有就自动 `sudo pacman -S aria2`(会要你输 sudo 密码)
2. 装 4 个脚本到 `~/.local/bin`
3. 配置 makepkg DLAGENT(bin 包 + tar.gz 下载走镜像)
4. 写 `/etc/makepkg.d/gitconfig`(-git 包克隆走镜像,要 sudo)
5. 写 `~/.config/pip/pip.conf`(Python 依赖走清华镜像)
6. 测速选最快镜像,设置用户级 insteadOf

> 国内下载 GitHub Release 慢?用镜像前缀:
> `wget https://gh-proxy.com/https://github.com/Bloodbeast522/aur-update-accel/releases/download/v1.0.0/aur-update-accel-1.0.0-3-any.pkg.tar.zst`

## 方法三:GitHub 手动安装(源码)

如果你不想等 AUR 审核,或者想先看看代码,用这个:

```bash
# 第 1 步:下载 + 跑安装脚本(会自动装 aria2,提示 sudo 密码)
git clone https://github.com/Bloodbeast522/aur-update-accel
cd aur-update-accel
./install.sh
```

install.sh 做的事和 `aur-update-accel-setup` 完全一样(6 步)。

### 确认 `~/.local/bin` 在 PATH 里

install.sh 会提示你。如果它说"不在 PATH 中",执行:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

> 这一步很关键:git 包装器放在 `~/.local/bin`,必须比系统自带的 `/usr/bin/git` 优先被找到,才能生效。

### 验证(可选,但建议)

```bash
# 1) 用户级 git 镜像(手动 clone 加速)
git config --global --get-regexp 'url.*insteadof'

# 2) makepkg 下载器(应看到 aria2-ghproxy)
grep -E 'https::|http::' ~/.config/pacman/makepkg.conf

# 3) makepkg 环境 git 镜像(关键!-git 包靠这个)
cat /etc/makepkg.d/gitconfig

# 4) pip 镜像(Python 依赖)
cat ~/.config/pip/pip.conf

# 5) 镜像下载测试(404 是正常的,看有没有镜像尝试)
~/.local/bin/aria2-ghproxy -UWget -s16 -x16 -o /tmp/x.part \
  https://github.com/foo/bar/releases/download/v1/x.tar.gz
```

看到类似 `[aria2-ghproxy] Trying https://gh-proxy.com ...` 就说明生效了。

### 以后怎么用

什么都不用做。以后 `paru -S` 更新 / 安装任何包:
- **`-git` 包** → partial clone + 多镜像,不再卡死
- **`-bin` 包** → aria2 多镜像下载
- **源码 tar.gz** → aria2 16 线程
- **Python 依赖** → 清华 pip 镜像

## 已知限制

- `aria2-ghproxy`(v2)重写 `github.com/*/releases/download/*` 格式的 URL;
  其他源站会先探测 302 跳转,凡最终落到 GitHub releases 的(如官网下载
  API 跳转)也自动走镜像;其余直接透传
- 部分 ghproxy 镜像不支持 partial clone filter 协议(wrapper 会自动切换
  下一个镜像;全都不支持时回退全量克隆,仅大仓库会慢)
- 镜像站本身会挂会换,`ghproxy-git-speedtest` 就是为此设计的;镜像失效时
  删掉缓存 `rm -f /tmp/.ghproxy-git-speed` 重新测速

## License

MIT
