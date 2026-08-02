# aur-ghproxy-accel

国内网络环境下,让 **AUR 构建全自动走 GitHub 加速镜像**的组合方案。
覆盖 AUR 构建的两条下载链路,无需代理,一次配置永久生效。

## 解决的问题

`paru -S` / `makepkg` 构建 AUR 包时,有两类下载在无代理的国内网络下会卡死或极慢:

| 场景 | 根因 | 本方案 |
|---|---|---|
| **`-git` 包克隆**(如 `searxng-git`、`rtw89-dkms-git`) | makepkg 用 `git clone --mirror` 拉取全部 refs(含数百个 PR refs),包体积膨胀到数百 MB,CN 镜像直接卡死 | `bin/git` 包装器自动加 `--filter=blob:none`(partial clone),体积缩小 ~10 倍,秒级完成 |
| **`-bin` 包下载**(release 文件) | `github.com/*/releases/download/*` 直连被墙 | `bin/aria2-ghproxy` 作为 makepkg DLAGENT,16 线程 aria2 + 多镜像自动回退 |

> 2026-08-02 实测:searxng(117MB 仓库)的 `--mirror` 克隆在 ghfast.top 上 2 分钟+ 无法完成;
> 加 `--filter=blob:none` 后 **17MB / 18 秒**,工作副本 989/989 文件全部检出。

## 组件

```
aur-ghproxy-accel/
├── bin/
│   ├── git                      # git 包装器:--mirror 克隆自动加 partial clone filter
│   │                            #   + 修复 makepkg shared-clone 的 promisor 配置
│   ├── aria2-ghproxy            # DLAGENT:GitHub release 下载走镜像(gh-proxy.com → ghproxy.net → 直连)
│   ├── curl-ghproxy             # 同上,curl 版
│   └── ghproxy-git-speedtest    # 自动测速 3 个镜像,把最快的设为 git insteadOf
├── config/
│   ├── makepkg-dlagent.conf.template   # makepkg.conf DLAGENT 配置片段
│   └── git-insteadof.conf.template     # git insteadOf 规则说明
├── install.sh                   # 一键安装
└── README.md
```

### 两条链路,分开配置(关键设计)

单一镜像无法同时服务两种传输类型:
- **git 克隆(大包)** → `ghfast.top` 最快(全量克隆 43M/9s 实测)
- **release 文件下载(小包)** → `gh-proxy.com` 最快(4.1s vs 13.4s 实测)

所以 `bin/ghproxy-git-speedtest`(git 克隆)和 `bin/aria2-ghproxy`(release 下载)
各自维护独立的镜像列表,互不干扰。

## 安装

```bash
git clone https://github.com/Bloodbeast522/aur-ghproxy-accel
cd aur-ghproxy-accel
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

## 依赖

- `aria2`(DLAGENT 用)
- `git`(≥2.19,partial clone 支持;实测 2.55)
- Arch 系发行版(makepkg/paru/yay)

## 已知限制

- `aria2-ghproxy` 只重写 `github.com/*/releases/download/*` 格式的 URL;
  其他源站(官网直链、gitlab 等)直接透传,不走镜像
- 若 GitHub 服务器不支持 partial clone filter(极少数),wrapper 会透传,
  fallback 到原始的 `--mirror` 克隆——此时建议改用 tarball 方案
- 镜像站本身会挂会换,`ghproxy-git-speedtest` 就是为此设计的;镜像失效时
  删掉缓存 `rm -f /tmp/.ghproxy-git-speed` 重新测速

## 背景故事

这个组合源于实际踩坑:searxng-git 的 `--mirror` 克隆在国内网络下卡死,
网上现成的加速方案(dev-sidecar、fetch-github-hosts、ghproxy 等)都只解决
通用 GitHub 访问(网页/DNS/hosts/文件下载),**没有一个专门处理
makepkg 的 `--mirror` 克隆 refs 爆炸 + DLAGENT 组合**这个特定痛点。
于是把 partial clone 包装器 + 多镜像 DLAGENT + 镜像分工组合成了这套方案,
验证后开源。

## License

MIT
