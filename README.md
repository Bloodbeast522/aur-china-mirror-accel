# aur计划通 (aur-keikaku-dori)

> 計画通り。纯 AI 编写,作者毫无经验,基本不会更新,对项目不承担任何责任。
> (此简介也是 AI 编写)

English: A China-friendly helper for Arch/CachyOS that makes `paru -S` work
without a proxy — auto partial-clone for `-git` packages, multi-mirror aria2
DLAGENT for `-bin` releases. Works everywhere, designed for mainland China.

## 这个项目是干嘛的

一句话:**让 CachyOS / Arch 在国内没有代理的情况下,`paru -S` 更新和安装 AUR 包不再卡死。**

具体解决两类问题:

1. **`-git` 包克隆卡死** — makepkg 用 `git clone --mirror` 拉全部 refs(含几百个 PR refs),几百 MB 的包在 GitHub 直连/镜像下直接卡死。本项目用包装器自动加 partial clone(`--filter=blob:none`),体积缩到 1/10,秒级完成。
2. **`-bin` 包下载被墙** — GitHub release 文件走不了。本项目把 makepkg 的下载器换成 aria2 + 多镜像自动回退。

两条链路分开配,互不干扰,一次配置永久生效。

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

## 方法一:AUR 安装(最简单,推荐)

如果 `aur-keikaku-dori` 已经提交到 AUR(见文末状态),那么:

```bash
# 第 1 步:装包(aria2 会自动一起装好,不用手动装)
paru -S aur-keikaku-dori

# 第 2 步:完成用户配置(只需要跑一次)
aur-keikaku-setup
```

完成。两条命令,之后 `paru -S` 任何包都会自动走加速。

> 没有 paru?用 yay 也行:`yay -S aur-keikaku-dori`。
> 两个都没有?先装一个:`sudo pacman -S --needed git base-devel && git clone https://aur.archlinux.org/paru.git && cd paru && makepkg -si`

## 方法二:GitHub Release 直接安装(预编译包)

不用克隆仓库、不用等 AUR。包已经打好了,直接下载安装:

```bash
# 第 1 步:装 aria2(本项目唯一的依赖)
sudo pacman -S aria2

# 第 2 步:下载预编译包(约 17KB,极快)
wget https://github.com/Bloodbeast522/aur-keikaku-dori/releases/download/v1.0.0/aur-keikaku-dori-1.0.0-1-any.pkg.tar.zst

# 第 3 步:安装
sudo pacman -U aur-keikaku-dori-1.0.0-1-any.pkg.tar.zst

# 第 4 步:完成用户配置(只需要跑一次)
aur-keikaku-setup
```

完成。第 4 步会提示你如果 `~/.local/bin` 不在 PATH,加一行配置(照它说的做)。

> 国内下载 GitHub Release 慢?用镜像前缀:
> `wget https://gh-proxy.com/https://github.com/Bloodbeast522/aur-keikaku-dori/releases/download/v1.0.0/aur-keikaku-dori-1.0.0-1-any.pkg.tar.zst`

## 方法三:GitHub 手动安装(源码)

如果你不想等 AUR 审核,或者想先看看代码,用这个:

### 第 1 步:装 aria2(下载加速工具)

```bash
sudo pacman -S aria2
```

> 这一步必须做。`aria2` 是实际干活的多线程下载器,本项目只是指挥它。

### 第 2 步:下载本项目

```bash
git clone https://github.com/Bloodbeast522/aur-keikaku-dori
cd aur-keikaku-dori
```

### 第 3 步:运行安装脚本

```bash
./install.sh
```

它会自动做三件事:
- 把 4 个脚本复制到 `~/.local/bin/`(git 包装器、aria2-ghproxy 等)
- 往 `~/.config/pacman/makepkg.conf` 里追加加速配置
- 测试 3 个镜像站的速度,自动选最快的

### 第 4 步:确认 `~/.local/bin` 在 PATH 里

install.sh 会提示你。如果它说"不在 PATH 中",执行:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

> 这一步很关键:git 包装器放在 `~/.local/bin`,必须比系统自带的 `/usr/bin/git` 优先被找到,才能生效。

### 第 5 步:验证(可选,但建议)

```bash
# 看 git 是否走镜像(应输出一条 url.*.insteadOf)
git config --global --get-regexp 'url.*insteadof'

# 看 makepkg 下载器是否换成 aria2(应看到 aria2-ghproxy)
grep -E 'https::|http::' ~/.config/pacman/makepkg.conf

# 随便下载一个 GitHub release 测试(404 是正常的,看有没有镜像尝试)
~/.local/bin/aria2-ghproxy -UWget -s16 -x16 -o /tmp/x.part \
  https://github.com/foo/bar/releases/download/v1/x.tar.gz
```

看到类似 `[aria2-ghproxy] Trying https://gh-proxy.com ...` 就说明生效了。

### 第 6 步:以后怎么用

什么都不用做。以后 `paru -S` 更新 / 安装任何包:
- **`-git` 包** → 自动 partial clone,不再卡死
- **`-bin` 包** → 自动走镜像下载

## 已知限制

- `aria2-ghproxy` 只重写 `github.com/*/releases/download/*` 格式的 URL;
  其他源站(官网直链、gitlab 等)直接透传,不走镜像
- 若 GitHub 服务器不支持 partial clone filter(极少数),wrapper 会透传,
  fallback 到原始的 `--mirror` 克隆——此时建议改用 tarball 方案
- 镜像站本身会挂会换,`ghproxy-git-speedtest` 就是为此设计的;镜像失效时
  删掉缓存 `rm -f /tmp/.ghproxy-git-speed` 重新测速

## License

MIT
