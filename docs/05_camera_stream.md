# 阶段 3.5：WiFi 视觉模块（esp32_s3_wifi_camera）

> 状态：**编译验证通过**（2026-10-18，本机 v5.5.3，8m22s，`gc0308_http_stream.bin` 0xf1b90 ≈ 990KB，app 分区余 37%）。
> 硬件烧录与配网待执行（需摄像头板在手）。

## 1. 模块概述

- 仓库：https://github.com/czu963889306-dev/esp32_s3_wifi_camera（已注册为本仓库第三个 submodule：`src/upstream/esp32_s3_wifi_camera` @ `551f39e`）
- 硬件：ESP32-S3 + GC0308 摄像头传感器
- 输出：**MJPEG HTTP 视频流**，端口固定 `81`（浏览器直接看，不需要任何客户端软件）
- 配网：默认进入配网模式，配网页 `http://192.168.1.88/`；连上路由器后用新 IP 访问
- 辅助：UDP 发现服务（端口 33333，`scripts/test_discovery.py` 可扫描设备 IP）+ I2C 指令交互
- 注意：仓库根目录的 `set_wifi.py` 是作者调试海思摄像头用的脚本，与本模块无关，忽略

## 2. 编译（已验证）

```bash
source ~/.espressif/tools/activate_idf_v5.5.3.sh
cd ~/leap-ros-2/src/upstream/esp32_s3_wifi_camera
idf.py build
```

产物：`build/gc0308_http_stream.bin`（app）+ `build/merged-binary.bin`（合并镜像，含 bootloader/分区表，0x0 起烧）。

无路径残留问题（本仓库 managed_components 干净，未踩 mcu_driver 的 `/root/` 坑）。

## 3. 烧录（待执行，需摄像头板接 USB）

```bash
ls /dev/ttyUSB*          # 确认端口；主控小车和摄像头板都插着时可能是 ttyUSB0/ttyUSB1 两个
idf.py -p /dev/ttyUSB0 flash monitor    # 端口以实际为准
```

- 下载模式同主控：**按住 BOOT，点按 RESET，松开 BOOT**
- 若嫌挑端口麻烦，也可直接烧合并镜像：`python -m esptool --chip esp32s3 -b 460800 write_flash 0x0 build/merged-binary.bin`
- monitor 里看到 WiFi 状态即成功；`Ctrl-]` 退出 monitor

## 4. 配网（手机热点方式，与主控同一热点）

1. 电脑/手机连接摄像头发出的配网热点
2. 浏览器打开 `http://192.168.1.88/`
3. 填入**与主控小车相同的** WiFi 名称和密码，保存
4. 摄像头重启后连上热点，串口 monitor 或 UDP 发现脚本可查到分配的 IP

## 5. 看流

```bash
# 找 IP（摄像头连上热点后）
python3 scripts/test_discovery.py        # UDP 33333 扫描
# 或去路由器/热点设备列表看
```

浏览器打开 `http://<摄像头IP>:81/` → MJPEG 实时画面。

## 6. 后续路线（阶段 5+）

- ROS 集成：MJPEG → ROS topic（`web_video_server` 或自写 C++ HTTP 拉流节点），再与 `/scan` 做视觉+雷达融合
- 摄像头 I2C 通道与主控的联动（仓库内置 I2C 指令交互，可用于云台/参数下发）

## 7. 坑位速查

| 现象 | 原因与处理 |
|---|---|
| 打不开 `192.168.1.88` | 未连接摄像头配网热点；或设备已存过 WiFi（先长按复位进配网，或清除 NVS） |
| 烧录 "No serial data received" | 未进下载模式（BOOT+RESET 组合） |
| 视频流打不开 | 确认端口是 81 不是 80；防火墙放行 |
| `idf.py flash` 找不到端口 | 用户需在 dialout 组（主控阶段已加过）；`ls /dev/ttyUSB*` 确认枚举 |
