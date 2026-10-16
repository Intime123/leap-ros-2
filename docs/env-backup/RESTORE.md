# ESP-IDF 环境存档与恢复指南

> 快照时间：2026-10-17 00:35。本文档是 ESP-IDF 开发环境的存档记录：项目做完后可安全清理 `~/.espressif`，需要时按本文恢复。

## 当前环境状态

- 位置：`~/.espressif`（共 2.7G）
- 管理方式：EIM v0.20.0 + VS Code 扩展 `espressif.esp-idf-extension-2.3.0`
- ESP-IDF 版本：**v6.1**（`~/.espressif/v6.1/esp-idf`，147 个 components，完整）
- 目标：`esp32s3`（eim_config.toml 已从 `["all"]` 收窄）
- Python venv：`~/.espressif/tools/python/v6.1/venv`（3.12.3）
- S3 编译器：`tools/xtensa-esp-elf/esp-15.2.0_20251204/xtensa-esp-elf/bin/xtensa-esp32s3-elf-gcc`（crosstool-NG esp-15.2.0_20251204，GCC 15.2.0，已验证可运行）

> **版本差异警示（排错首选）**：教程视频（B 站 BV1nNNb6cER7）使用 ESP-IDF **5.5.3**，本机为 **v6.1**，major 版本差异。v6 移除 legacy ADC/I2C 等驱动、cJSON/wifi_provisioning 移出、MbedTLS4/PSA、默认 libc 换 Picolibc、warnings 视为 errors。leap_ros_mcu_driver 固件的电池 ADC（GPIO3 采样）与 I2C（IMU/手柄）正好踩中已移除驱动——**后续编译报错首选排查版本差异**。计划补装 v5.5.3（EIM 多版本并存，target 仅 esp32s3）与本项目对齐。

## 磁盘保留组件（2.7G，均有用）

| 组件 | 大小 | 用途 |
|---|---|---|
| `v6.1/esp-idf` | 734M | IDF 框架本体 |
| `tools/xtensa-esp-elf` | 1.1G | xtensa 统一 toolchain（含 S3 编译器） |
| `tools/components` | 485M | 组件注册缓存 |
| `tools/python` | 107M | IDF Python 环境 |
| `tools/xtensa-esp-elf-gdb` | 123M | S3 JTAG 调试 |
| `tools/esp-clangd` | 75M | VS Code IntelliSense |
| `tools/esp32ulp-elf` | 31M | ULP 低功耗实验 |
| `tools/openocd-esp32` / `esp-rom-elfs` / `ninja` / `shims` | 19M | 烧录调试辅助 |
| `eim/` | 32M | 安装管理器本体 |

## 已删除组件（2026-10-17，释放 7.1G）

均为 ESP32-S3 项目用不到的工具链；删除前完整清单见同目录 `pre_delete_inventory.txt`：

| 组件 | 大小 | 原用途 |
|---|---|---|
| `tools/riscv32-esp-elf` | 2.8G | RISC-V 芯片（C3/C5/C6/H2） |
| `tools/esp-clang` | 2.6G | P4 等 clang 目标 |
| `tools/esp-clang-libs` | 336M | clang 运行库 |
| `tools/riscv32-esp-elf-gdb` | 124M | RISC-V 调试器 |
| `dist/` | 1.2G | 工具下载缓存（tools/ 已解压，属可再生数据） |

> 说明：删除的是 Espressif 公开构建产物（非个人数据），可随时完整重装，故未做字节级备份；配置快照（`eim_config.toml` / `eim_idf.json`）已随本文档存档。

## 恢复方法

```bash
# 方式 1：EIM 官方 fix 命令（重装工具，约 1 小时，走已配置的国内镜像）
~/.espressif/eim/eim_v0.20.0 fix -p /home/yaen/.espressif -i v6.1 -t all -n

# 方式 2：VS Code → ESP-IDF Explorer 面板 → 管理工具（图形界面，更稳妥）
```

恢复后如需与存档一致，可对照本目录 `eim_config.toml` 修正工具列表。

## 项目结束后的清理

```bash
rm -rf ~/.espressif                    # 约 2.7G，可按本文完整重建
rm -rf ~/esp_env_backup_20261017       # 临时备份目录
```

## 关联待办

- [ ] 补装 ESP-IDF v5.5.3（`eim install -i v5.5.3 -t esp32s3` 或扩展向导，target 只选 esp32s3，约 1G），本项目固件以 5.5.3 编译
- [ ] 阶段 2 固件烧录按 B 站 BV1nNNb6cER7 执行，检查点：配网 / agent IP 改本机 / 5 话题上线
