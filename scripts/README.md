# Fork 部署脚本

`local-fix-pr570` 分支专用的三个脚本,管 install / update / uninstall。

## 命令总览

| 场景 | 一行命令 |
|------|---------|
| **新机器首装** / 已装官方版的机器替换 | `curl -fsSL https://raw.githubusercontent.com/C-ra-ZY/happy/local-fix-pr570/scripts/install-from-fork.sh \| bash` |
| **常规更新**(线性追加 commit,fast-forward 即可) | 同上 — `install-from-fork.sh` 自带 idempotent 行为,会 ff-pull 然后 rebuild |
| **强制更新**(我在 dev 机 rebase 了 fork) | `curl -fsSL https://raw.githubusercontent.com/C-ra-ZY/happy/local-fix-pr570/scripts/update-from-fork.sh \| bash` |
| **退回官方 happy** | `curl -fsSL https://raw.githubusercontent.com/C-ra-ZY/happy/local-fix-pr570/scripts/uninstall-from-fork.sh \| bash` |

## 三个脚本各干什么

### `install-from-fork.sh`
1. 克隆(或 ff-pull)fork 到 `$HOME/code/happy`
2. `pnpm install` + 构建 `@slopus/happy-wire`(必须先于 happy-cli)
3. `pnpm --filter happy cli:install` —— 内部自动:
   - `happy daemon stop`(allowFailure,允许之前没在跑)
   - `npm link`(把全局 `happy` 软链接指向 workspace,顺带替换掉 npm 装的官方版)
   - `happy daemon start`
   - `happy --version` 验证
4. 打印 daemon 视角下能找到的 `claude` / `codex` / `gemini` 路径

**关键细节**:脚本顶部 `export PATH=...` 显式 prepend 了一组常见 CLI 目录(`~/.local/bin`、`~/.bun/bin`、`~/.local/share/pnpm`、`/opt/homebrew/bin`、`/home/linuxbrew/.linuxbrew/bin`、`/usr/local/bin`),这样 daemon 起来后能稳定地通过 `command -v` 找到 agents,**避免在 WSL / 远程 SSH 等非交互环境下手机端报"claude not detected"**。

### `update-from-fork.sh`
处理"上游 rebase 后的 force-push"场景。`install-from-fork.sh` 用的 `git pull --ff-only` 会因为历史改写而失败,这时用这个脚本:

1. 检查 `$HAPPY_INSTALL_DIR` 工作树干净(否则中止,可用 `HAPPY_DISCARD_LOCAL=1` 强制丢弃)
2. `git fetch && git reset --hard origin/$BRANCH`
3. 把控制权 `exec` 给最新的 `install-from-fork.sh`

`install-from-fork.sh` 的 ff-pull 失败路径会**直接打印**这个脚本的 curl 命令,不用记。

### `uninstall-from-fork.sh`
退回官方 happy。

1. `happy daemon stop`(best-effort)
2. `npm unlink -g happy`(拆 workspace 软链接)
3. `npm i -g happy@latest`(装回官方版)
4. `happy daemon start`

**不会删**:`$HAPPY_INSTALL_DIR`(fork 仓库)、`~/.happy/`(auth + session 数据)。要彻底干净自己 `rm`。

## 环境变量(三个脚本通用)

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `HAPPY_FORK_URL` | `https://github.com/C-ra-ZY/happy.git` | fork 的 git URL |
| `HAPPY_FORK_BRANCH` | `local-fix-pr570` | 部署分支 |
| `HAPPY_INSTALL_DIR` | `$HOME/code/happy` | fork 检出目录 |
| `HAPPY_DISCARD_LOCAL` | `0` | `update-from-fork.sh` 专用,设 `1` 时会丢弃工作树未提交的改动 |

例:
```bash
HAPPY_INSTALL_DIR=$HOME/dev/happy-fork \
  curl -fsSL https://raw.githubusercontent.com/C-ra-ZY/happy/local-fix-pr570/scripts/install-from-fork.sh | bash
```

## 同步上游(在 dev 机做一次,推送后所有部署机用 update 拉)

```bash
git fetch upstream
git checkout main && git merge --ff-only upstream/main && git push origin main
git checkout local-fix-pr570
git rebase main                                # 把 PR #570 + 部署脚本叠到新 main 上
git push --force-with-lease origin local-fix-pr570

# 然后在每台部署机上:
curl -fsSL https://raw.githubusercontent.com/C-ra-ZY/happy/local-fix-pr570/scripts/update-from-fork.sh | bash
```

## 这个分支包含什么

```
chore: add uninstall-from-fork.sh                                 ← 部署脚本
chore: add update-from-fork.sh
chore: add install-from-fork.sh
fix: use exit tracking instead of child.killed (PR #570 follow-up) ← cherry-pick from upstream PR #570
fix: restore terminal state after remote→local mode switch (PR #570)
[upstream main commits...]
```

PR #570 上游链接:<https://github.com/slopus/happy/pull/570>(本仓库 cherry-pick,跟 upstream main 完全同步,合上去就退役这个分支)。
