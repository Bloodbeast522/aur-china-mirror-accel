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

## 安装

```bash
git clone https://github.com/Bloodbeast522/aur-keikaku-dori
cd aur-keikaku-dori
./install.sh
```

install.sh 会自动:
1. 拷贝 4 个脚本到 `~/.local/bin/`(需已在 PATH 最前)
2. 追加 DLAGENT 到 `~/.config/pacman/makepkg.conf`
3. 运行测速,设置 git insteadOf 到最快镜像

### 手动安装(不想跑脚本)

```bash
# 1. 脚本
cp bin/* ~/.local/bin/

# 2. makepkg DLAGENT(把 __USER__ 换成你的用户名)
#    追加到 ~/.config/pacman/makepkg.conf
cat config/makepkg-dlagent.conf.template | sed 's/__USER__/'$USER'/'

# 3. git insteadOf(自动测速版)
~/.local/bin/ghproxy-git-speedtest
#    或手动指定大包镜像:
git config --global url."https://ghfast.top/https://github.com/".insteadOf "https://github.com/"
```

## 验证

```bash
# 1) DLAGENT 生效(makepkg 先读 /etc/makepkg.conf,用户级再覆盖)
grep -E 'https::|http::' ~/.config/pacman/makepkg.conf   # 应看到 aria2-ghproxy
grep -E 'https::|http::' /etc/makepkg.conf               # 系统级 curl(被覆盖,正常)

# 2) git 走镜像
git config --global --get-regexp 'url.*insteadof'        # 应有一条 url.*.insteadOf
git ls-remote https://github.com/git/git.git | head -3   # 应快速返回

# 3) DLAGENT 包装器(404 是正常的,看的是镜像重写是否生效)
~/.local/bin/aria2-ghproxy -UWget -s16 -x16 -o /tmp/x.part \
  https://github.com/foo/bar/releases/download/v1/x.tar.gz
# 应输出 "[aria2-ghproxy] Trying https://gh-proxy.com ..."

# 4) partial clone 生效(makepkg 克隆 -git 包时)
#    日志里 clone 命令应带 --filter=blob:none;大仓库应秒级完成
```

## 已知限制

- `aria2-ghproxy` 只重写 `github.com/*/releases/download/*` 格式的 URL;
  其他源站(官网直链、gitlab 等)直接透传,不走镜像
- 若 GitHub 服务器不支持 partial clone filter(极少数),wrapper 会透传,
  fallback 到原始的 `--mirror` 克隆——此时建议改用 tarball 方案
- 镜像站本身会挂会换,`ghproxy-git-speedtest` 就是为此设计的;镜像失效时
  删掉缓存 `rm -f /tmp/.ghproxy-git-speed` 重新测速

## License

MIT
