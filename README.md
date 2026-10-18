# LEAP ROS2 低成本自主避障小车

基于开源项目 [czu963889306-dev/leap_ros2](https://github.com/czu963889306-dev/leap_ros2)（约 200 元 ROS2 教学小车）构建的「雷达检测 + 自主避障」真机项目。目标：从零完成环境搭建、固件联通、SLAM 建图、自研避障节点、Nav2 自主导航的全链路落地，全过程留痕。

## 硬件平台

- 下位机：ESP32-S3（`leap_ros_mcu_driver` v1.5 固件，ESP-IDF，micro-ROS / MAVLink 双协议）
- 传感器：Camsense 单线激光雷达（360°/1°/0.02–12m）、IMU、HC-SR04 超声波、电池检测
- 底盘：差速底盘，kTrackWidth = 131.7 mm，2S 锂电（8.4V 满 / 6.0V 空）
- 图传：ESP32-S3 WiFi 摄像头（MJPEG，端口 81）

## 系统架构

```
机器小车（ESP32-S3 固件）──WiFi/UDP──▶ micro-ROS agent ──▶ ROS2 话题
   /cmd_vel ◀── 控制指令 ── Nav2 / 自研避障节点 ◀── /scan /odom /imu
```

- 固件发布：`/odom`(50Hz) `/imu`(50Hz) `/scan`(10Hz) `/battery_state`(10Hz) `/ultrasonic`(10Hz)
- 固件订阅：`/cmd_vel`
- 固件服务：`/set_speed_pid` `/get_speed_pid`

## 仓库结构

```
leap-ros-2/
├─ src/
│  ├─ upstream/leap_ros_ws/          # 上游 ROS2 工作空间（git submodule）
│  ├─ upstream/leap_ros_mcu_driver/  # 上游 ESP32-S3 固件（git submodule）
│  └─ leap_obstacle_avoidance/       # 自研避障节点（C++ rclcpp，阶段 5）
├─ maps/                             # SLAM 地图（阶段 4）
├─ bags/                             # 演示 rosbag
├─ media/                            # 截图 / 地图 / 视频
├─ docs/                             # 阶段留痕 00–07 + 参考文档 10–13
├─ scripts/                          # 一键环境搭建等脚本
├─ NOTICE / LICENSE / .gitignore
```

## 文档索引

| 文档 | 内容 |
|---|---|
| `docs/11_项目阶段框架.md` | **阶段 0–7 路线图**：目标/命令/验收/知识体系/坑位 |
| `docs/10_项目总览与架构.md` | 架构与数据流：仓库地图、硬件清单、三层架构、协议矩阵 |
| `docs/12_已完成阶段总结.md` | 已完成阶段的实测数据与根因链（含 v6.1 判定与 v5.5.3 迁移全记录） |
| `docs/02_firmware_build.md` | 阶段 2 完整留痕：v6.1 判定、v5.5.3 迁移、烧录与 agent 连通 |
| `docs/03_ros2_bringup.md` | 阶段 3：工作空间编译、bringup 自测、固件 QoS 与单位约定梳理 |
| `docs/05_camera_stream.md` | 阶段 6.5：WiFi 视觉模块编译/烧录/配网/看流 |
| `docs/13_简历与面试问答.md` | 简历三版描述 + 分模块面试答题库 |
| `docs/template_phase.md` | 阶段总结模板（每阶段完成后填写） |
| `docs/00_repo_setup.md` | 阶段 0 完整记录 |

## 进度

| 阶段 | 内容 | 状态 |
|---|---|---|
| 0 | Git 基线与仓库骨架 | ✅ 完成（`docs/00_repo_setup.md`） |
| 1 | Ubuntu 24.04 + ROS2 Jazzy 环境 | ✅ 完成（本机已核实：jazzy + colcon + agent 源码编译） |
| 2 | 固件烧录与 agent 连通 | ✅ 完成（2026-10-17：v6.1 判定不兼容迁移 v5.5.3，固件上板，五话题上线；`docs/02_firmware_build.md`） |
| 3 | 工作空间编译与 bringup | 🔶 编译/自测完成（2026-10-17，4 包 8s 通过，`docs/03_ros2_bringup.md`）；实车遥控待本人执行 |
| 4 | Cartographer SLAM 建图 | 未开始 |
| 5 | 自研避障节点（C++ rclcpp） | 未开始 |
| 6 | Nav2 自主导航 | 未开始 |
| 6.5 | （可选）相机图传接入 | 🔶 编译验证通过（2026-10-18，`gc0308_http_stream.bin` 990KB，submodule 已入库，`docs/05_camera_stream.md`）；烧录配网待本人执行 |
| 7 | 文档归总与简历版 README | 未开始 |

各阶段的目标/命令/验收/知识体系/坑位详见 **[docs/11_项目阶段框架.md](docs/11_项目阶段框架.md)**。

## 快速开始

```bash
# 1. 一键搭建 ROS2 环境（Ubuntu 24.04，需 sudo）
bash scripts/setup_env.sh

# 2. 拉取上游工作空间（已配置 submodule 时）
git submodule update --init --recursive

# 3. 编译工作空间（4 个核心包，跳过无 Jazzy 支持的 gmapping）
bash scripts/build_ws.sh            # 加 --clean 全量重建，--rosdep 装依赖

# 4. 启动（小车开机并连同一热点后）
bash scripts/start_stack.sh         # micro-ROS agent + bringup
bash scripts/check_bringup.sh       # 体检：话题/频率/QoS/TF
ros2 run teleop_twist_keyboard teleop_twist_keyboard
```

| 脚本 | 作用 |
|---|---|
| `scripts/setup_env.sh` | 阶段 1：一键装 ROS2 Jazzy + micro-ROS agent 依赖 |
| `scripts/build_ws.sh` | 阶段 3：同步上游源码 + colcon 构建核心包（幂等） |
| `scripts/start_stack.sh` | 阶段 3：agent 后台 + bringup 前台，Ctrl-C 全停 |
| `scripts/check_bringup.sh` | 阶段 3：话题/频率/QoS/TF 体检 |

分阶段详细操作与留痕见 [docs/](docs/)。

## 声明

- 上游项目声明「未经允许禁止商用」，本仓库整体仅限学习交流；自研部分（`leap_obstacle_avoidance` 与 docs）采用 MIT，详见 [NOTICE](NOTICE)。
- 致谢：上游作者 czu963889306-dev（B 站「出云科技2001」）与飞书手册。
