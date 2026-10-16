# 阶段 0：准备 & Git 基线

## 目标

建立可复现、可留痕的工程骨架：本地 git 仓库、目录规范、上游 submodule、SSH 推送密钥、文档模板；与远程仓库 https://github.com/Intime123/leap-ros-2 对齐（推送在密钥添加后完成）。

## 步骤（命令/操作）

```bash
# 1. 生成本机 SSH 密钥（ed25519，注释为 Git 邮箱）
ssh-keygen -t ed25519 -C "3157657414@qq.com" -f ~/.ssh/id_ed25519 -N ""

# 2. 本地建库（远程已有默认 README，本地以同样内容初始化，便于后续 rebase 对齐）
mkdir -p ~/leap-ros-2 && cd ~/leap-ros-2
git init -b main
git config user.email "3157657414@qq.com"   # 仓库级，不动全局配置
git config user.name "Intime123"
printf '# leap-ros-2' > README.md           # 与远程默认 README 字节一致（12 字节）
git add README.md && git commit -m "chore: initial commit with default README"

# 3. 目录骨架
mkdir -p docs media/{firmware,slam,nav2,arch} bags maps scripts

# 4. 骨架文件：.gitignore / README.md / NOTICE / LICENSE / docs/template_phase.md / scripts/setup_env.sh

# 5. 引入上游 submodule 并 pin commit
git submodule add https://github.com/czu963889306-dev/leap_ros_ws src/upstream/leap_ros_ws
```

远程对齐（待用户把公钥添加到 GitHub 后执行）：

```bash
git remote add origin git@github.com:Intime123/leap-ros-2.git
git fetch origin
git rebase origin/main        # 初始提交与远程相同，自动丢弃；骨架提交落到远程历史之上
git push origin main
git tag -a phase0-repo -m "phase0: repo skeleton with upstream submodule"
git push origin phase0-repo
```

## 注意事项（坑）

- **沙箱执行限制（本阶段实际遇到）**：执行环境为沙箱容器，`/opt`、`/usr/local` 只读，`/var` 为无 dpkg 状态的临时 tmpfs，无 docker，sudo 损坏——**无法在执行环境内 apt 安装 ROS2**。因此阶段 1 改为交付一键脚本 `scripts/setup_env.sh`，由用户在本机执行。可写路径仅限 `~/` 与 `/tmp`。
- **HTTPS 克隆瞬时失败**：git over HTTPS 出现 `CONNECT tunnel failed, response 502`（本地代理抖动），改用 SSH 密钥路线；SSH 到 github.com:22 的 TCP 连接正常。
- **密钥属主**：沙箱内无法 chown（用户命名空间限制），私钥属主为 root；用户本机终端手动 push 时需自行 `sudo chown yaen:yaen ~/.ssh/id_ed25519*`，由我代推送则不受影响。
- **README 字节对齐**：远程默认 README 为 12 字节无换行；本地用 `printf` 精确复现，rebase 时初始提交自动作废，不产生空提交。
- **submodule 而非 copy**：保留上游 license 边界（上游禁止商用），且可跟随上游更新。

## 问题与解决

| 问题 | 原因 | 解决 | 状态 |
|---|---|---|---|
| HTTPS clone 502 | 本地代理瞬时故障 | 改 SSH 路线；apt 不可用问题独立记录 | 已解决 |
| chown 无效的参数 | 沙箱用户命名空间限制 | 保持 root 属主，推送由我执行；已提示用户本机手动修复命令 | 已解决 |
| apt/sudo 不可用 | 沙箱安全策略（/opt、/usr/local 只读，/var 无 dpkg 状态） | 环境安装改为一键脚本交付 | 已解决（策略性规避） |
| 远程仓库非空（默认 README） | GitHub 建仓自动生成 | 本地以相同内容初始化，rebase 对齐 | 已解决 |
| micro-ROS agent apt 包是否存在 | 未实测 | 脚本内置 apt→源码回退双路径 | 待验证（阶段 1） |
| HTTPS submodule 前两次失败（GnuTLS/502） | 本地代理抖动 | 重试第 3 次成功，pin @3f352d5 | 已解决 |
| 提权 shell HOME=/root 导致 ssh 找不到密钥 | 环境身份差异 | 仓库级 `core.sshCommand` 显式指定 `-i /home/yaen/.ssh/id_ed25519` | 已解决 |

## 总结

阶段 0 除「远程 push」外的全部本地工作已完成：仓库骨架、目录规范、文档模板、上游 submodule、SSH 密钥、一键环境脚本均已就位。**远程 push 的唯一前置是用户把公钥添加到 GitHub**（公钥已在对话中给出）。阶段 1 因沙箱限制无法代装，已转为脚本交付，用户执行一条命令即可完成环境搭建。

## 验收清单

- [x] SSH 密钥已生成，公钥已交付（待用户添加到 GitHub）
- [x] 本地仓库初始化，仓库级身份为 Intime123 <3157657414@qq.com>
- [x] 目录骨架（docs/media/bags/maps/scripts）就位
- [x] .gitignore / README.md / NOTICE / LICENSE / 模板就位
- [x] `scripts/setup_env.sh` 一键环境脚本就位
- [x] 上游 submodule 添加成功（pin @3f352d5，`git submodule status` 可查）
- [ ] 远程 push 与 tag phase0-repo 完成（用户添加公钥后执行；仓库级 core.sshCommand 已配好）
