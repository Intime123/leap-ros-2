# ESP-IDF 环境存档与恢复指南

> 快照时间：2026-10-17 14:40（阶段 2 编译通过后更新）。本文档是 ESP-IDF 开发环境的存档记录：项目做完后可安全清理 `~/.espressif`，需要时按本文恢复。

## 当前环境状态

- 位置：`~/.espressif`（约 3.4G：v5.5.3 657M + 共享工具链）
- 管理方式：EIM v0.20.0 + VS Code 扩展 `espressif.esp-idf-extension-2.3.0`
- **主力版本：v5.5.3**（`~/.espressif/v5.5.3/esp-idf`）——固件编译已验证通过（BUILD_EXIT=0，66 包，leap_low_v1.bin 1.1MB），与教程视频一致
- 目标：`esp32s3`
- Python venv：`~/.espressif/tools/python/v5.5.3/venv`（已补装 catkin_pkg / empy==3.3.4 / lark，主机端 colcon 构建必需）
- 激活脚本：`source ~/.espressif/tools/activate_idf_v5.5.3.sh`
- VS Code 扩展已直连 v5.5.3：`~/.config/Code/User/settings.json`（idf.espIdfPath / toolsPath / pythonInstallPath / openOcdScriptsPath）
- v6.1：**待删除**（实编译判定不兼容：cJSON 组件移出 + legacy I2C 驱动移除；`eim remove v6.1` 曾挂起，待重执行，可释放约 2.4G）

> **版本结论（阶段 2 实证）**：v6.1 编译上游固件必败（配置阶段 `Failed to resolve component 'json'`；源码 3 文件用 legacy `driver/i2c.h`）。本项目一律用 **v5.5.3**。完整排错过程见 `docs/02_firmware_build.md`。

## 磁盘组件清单

| 组件 | 大小 | 用途 |
|---|---|---|
| `v5.5.3/esp-idf` | 657M | IDF 框架本体（主力，编译已验证） |
| `v6.1/esp-idf` | 734M | ⏳ 待删除（不兼容判定完成） |
| `tools/xtensa-esp-elf` | 1.1G | xtensa 统一 toolchain（v5.5.3 用 esp-14.2.0_20251107，含 S3 编译器） |
| `tools/components` | 485M | 组件注册缓存 |
| `tools/python/v5.5.3/venv` | ~150M | IDF Python 环境（含 colcon 依赖） |
| `tools/xtensa-esp-elf-gdb` | 123M | S3 JTAG 调试 |
| `tools/esp-clangd` | 75M | VS Code IntelliSense |
| `tools/esp32ulp-elf` | 31M | ULP 低功耗实验 |
| `tools/openocd-esp32` / `esp-rom-elfs` / `ninja` / `cmake` 等 | ~50M | 烧录调试辅助 |
| `eim/` | 32M | 安装管理器本体 |

## 已删除组件（2026-10-17，累计释放 ~9.5G）

均为本项目用不到的产物；删除前完整清单见同目录 `pre_delete_inventory.txt`：

| 组件 | 大小 | 原用途 |
|---|---|---|
| `tools/riscv32-esp-elf` | 2.8G | RISC-V 芯片（C3/C5/C6/H2） |
| `tools/esp-clang` + `esp-clang-libs` | 2.9G | P4 等 clang 目标 |
| `tools/riscv32-esp-elf-gdb` | 124M | RISC-V 调试器 |
| `dist/` | 1.2G | 工具下载缓存（可再生） |
| `v6.1` 专属工具链（待删） | ~2.4G | GCC 15.2 等，v5.5.3 用 14.2 |

> 说明：删除的是 Espressif 公开构建产物（非个人数据），可随时完整重装，故未做字节级备份；配置快照（`eim_config.toml` / `eim_idf.json`）已随本文档存档。

## 恢复方法

```bash
# 方式 1：EIM 官方命令（走已配置的国内镜像，约 1 小时）
~/.espressif/eim/eim_v0.20.0 install -i v5.5.3 -t esp32s3 -p /home/yaen/.espressif \
  --skip-prerequisites-check true -m https://dl.espressif.cn/github_assets \
  --idf-mirror https://git.espressif.com.cn --pypi-mirror https://pypi.tuna.tsinghua.edu.cn/simple

# 方式 2：VS Code → ESP-IDF Explorer 面板 → 管理工具（图形界面）

# 主机端构建依赖（colcon 生成 libmicroros.a 必需，重装后必补）：
~/.espressif/tools/python/v5.5.3/venv/bin/pip install catkin_pkg "empy==3.3.4" lark
```

## 项目结束后的清理

```bash
rm -rf ~/.espressif                    # 约 3.4G，可按本文完整重建
rm -rf ~/esp_env_backup_20261017       # 临时备份目录
```

## 关联待办

- [ ] 删除 v6.1（`eim remove v6.1`，或直接 `rm -rf ~/.espressif/v6.1` + `eim fix` 刷新注册）
- [ ] 阶段 2 固件烧录按 B 站 BV1nNNb6cER7 执行，检查点：配网 / agent IP 改本机 / 5 话题上线
