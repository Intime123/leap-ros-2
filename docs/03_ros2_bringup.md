# 阶段 3：ROS2 工作空间编译与 bringup

> 填写时间：2026-10-17 23:50（GMT+8） · 执行环境：本机 Ubuntu 24.04 + ROS2 Jazzy（`/opt/ros/jazzy`）
> 结论先行：**4 个核心包编译通过（8.00s），bringup launch 离线自测正常，TF 树 `odom→base_footprint→base_link→laser_frame/imu_link` 完整**；实车遥控需小车在线后由本人执行（本阶段最后一步）。

## 目标

1. 建 `~/leap_ws` 工作空间，编译上游 4 个包：`leap_interfaces` / `xuegecar_description` / `xuegecar_bringup` / `camsense_lidar`。
2. `ros2 launch xuegecar_bringup xuegecar_bringup.launch.py` 能起：URDF 加载、TF 树闭合、`/odom` 订阅就绪。
3. 沉淀可复现脚本（`scripts/build_ws.sh` / `start_stack.sh` / `check_bringup.sh`），为阶段 4（Cartographer）打底。

验收标准：colcon 零失败；三节点在线；`odom→base_footprint` TF 有输出；`teleop_twist_keyboard` 发 `/cmd_vel` 能驱动车轮（实车）。

## 步骤（命令/操作）

```bash
# 1) 一键同步源码 + 构建（推荐，脚本已验证）
cd ~/leap-ros-2 && bash scripts/build_ws.sh --clean
#   等价手工步骤：
#   mkdir -p ~/leap_ws/src
#   rsync -a --delete ~/leap-ros-2/src/upstream/leap_ros_ws/<pkg>/ ~/leap_ws/src/<pkg>/
#   source /opt/ros/jazzy/setup.bash && cd ~/leap_ws
#   colcon build --packages-select leap_interfaces xuegecar_description xuegecar_bringup camsense_lidar \
#     --cmake-args -DPython3_EXECUTABLE=/usr/bin/python3

# 2) 离线自测（不接小车）
source /opt/ros/jazzy/setup.bash && source ~/leap_ws/install/setup.bash
ros2 launch xuegecar_bringup xuegecar_bringup.launch.py

# 3) 实车联调（小车开机、连同一热点、笔记本 IP 已写入 NVS）
bash scripts/start_stack.sh                 # agent 后台 + bringup 前台
#   另开终端：
ros2 run teleop_twist_keyboard teleop_twist_keyboard
bash scripts/check_bringup.sh               # 体检：话题/频率/QoS/TF
```

非命令类说明：

- 工作空间 `~/leap_ws` 与仓库解耦（源码由 `src/upstream/leap_ros_ws` submodule 单向 rsync 进来），阶段 5 起的自研包会同时落盘到仓库 `src/leap_ros_pkgs/` 以便入库。
- 未构建：`slam_gmapping` / `openslam_gmapping`（Jazzy 无维护，直接弃用，改走 Cartographer）；`xuegecar_cartographer` / `xuegecar_navigation2` / `xuegecar_camera` / `xuegecar_mavlink_bridge` 留到阶段 4–6 按需构建。

## 结果（实测数据）

| 指标 | 期望 | 实测 | 证据 |
|---|---|---|---|
| colcon 构建 | 4 包成功 | `Summary: 4 packages finished [8.00s]`，`BUILD_EXIT=0` | `bash scripts/build_ws.sh --clean` 输出 |
| 启动节点数 | 3 | `joint_state_publisher` / `robot_state_publisher` / `xuegecar_bringup` | `ros2 node list` |
| 话题 | — | `/joint_states /odom /parameter_events /robot_description /rosout /tf /tf_static` | `ros2 topic list` |
| TF `odom→base_footprint` | 广播 | 有输出；离线（无 `/odom` 数据）时为零位姿 | `ros2 run tf2_ros tf2_echo odom base_footprint` |
| 依赖包 | 齐全 | `teleop_twist_keyboard` / `robot_state_publisher` / `xacro` / `rviz2` 已装；`joint_state_publisher_gui` 缺失（不影响 launch） | `ros2 pkg list` |
| rclpy | 可用 | `/opt/ros/jazzy/lib/python3.12/site-packages/rclpy` | source 后 import 成功 |

### 实车实测（2026-10-18 00:20，`~/leap_ws/bags/20261018_002001/`）

| 指标 | 源码推断 | 实测 | 证据文件 |
|---|---|---|---|
| `/odom` 频率 | 50 Hz | **49.4 Hz**（min 0.010s / max 0.032s / σ 0.0045s） | `hz_odom.txt` |
| `/scan` 频率 | 10 Hz | **7.9–8.2 Hz**（min 0.090s / max 0.221s / σ 0.041s，抖动偏大） | `hz_scan.txt` |
| `/imu` 频率 | 50 Hz | **49.5 Hz**（min 0.009s / max 0.048s） | `hz_imu.txt` |
| `/odom` QoS | RELIABLE | **RELIABLE** ✅ | `qos_odom.txt` |
| `/scan` QoS | RELIABLE | **RELIABLE** ✅ | `qos_scan.txt` |
| `/imu` QoS | BEST_EFFORT | **BEST_EFFORT** ✅ | `qos_imu.txt` |
| `/odom` frame | `odom` → `base_link` | 一致 ✅ | `odom_once.txt` |
| `/scan` 规格 | 360 点 / 1° | `angle_min=0`、`angle_max=6.2657`（359°）、`increment=0.01745`、`range_min=0.02`、`range_max=12.0`、`scan_time=0.1` ✅ | `scan_once.txt` |
| 电池 | 2S 锂电 | `voltage=7.79V`、`percentage=0.75`、`power_supply_status=2`（放电中） | `battery_once.txt` |

结论：**源码推断的 QoS 约定全部被实测证实**——订阅 `/imu`（以及 `/ultrasonic`、`/battery_state`）必须用 `SensorDataQoS()`，用默认 QoS 会静默收不到。
`/scan` 实测约 8 Hz 而非标称 10 Hz，且抖动 σ=41 ms（`scan_once.txt` 的 `scan_time` 仍报 0.1，说明是传输侧抖动而非雷达转速）→ 阶段 4 Cartographer 的 `motion_filter` 与 `num_accumulated_range_data` 需按 8 Hz 估。

工具链事实：gcc 13.3.0、cmake 3.28.3、ROS `ros_environment 4.2.1`、Python 绑定 3.12。

## 注意事项（坑）

1. **Python 解释器被抢**：PATH 里有第三方 Python（本机为 WorkBuddy 托管的 3.13）时，CMake 用它执行 `package_xml_2_cmake.py` → `ModuleNotFoundError: No module named 'catkin_pkg'`，构建必失败。构建时固定 `-DPython3_EXECUTABLE=/usr/bin/python3`（apt 版 ROS 绑定 python3.12），**改 PATH 无效，因为 colcon 会复用 CMakeCache**——需 `rm -rf build install log` 或 `--cmake-clean-cache`。
2. **固件 QoS 不对称**（读固件源码 `main/tasks/network/microros_task.cpp:746-800` 得到的事实）：
   - `/odom`、`/scan`：默认 RELIABLE；`/imu`、`/battery_state`、`/ultrasonic`：`rmw_qos_profile_sensor_data`（BEST_EFFORT）。
   - → 后续订阅 `/imu`、`/ultrasonic` 的节点**必须**用 `rclcpp::SensorDataQoS()`，否则静默收不到数据（不报错，最难查）。
   - `/cmd_vel` 订阅端是 BEST_EFFORT，发布端用 RELIABLE（teleop 默认）**兼容**，不用改。
3. **不要同时启动 `camsense_lidar`**：雷达数据已由固件经 micro-ROS 发 `/scan`（frame_id=`laser_frame`），PC 端再起串口驱动会重复发布。该包只作为直连备选。
4. **速度单位**：固件 `handle_cmd_vel()` 把 `linear.x * 1000` 当 mm/s，`angular.z` 直接当 rad/s（`microros_task.cpp:399-407`）。写避障/导航节点时按 m/s 给值即可，别自己换算。
5. **`xuegecar_bringup` 节点是 1 kHz 忙等**（`WallRate(1000.0)` + `spin_some`，`xuegecar_bringup.cpp:62-67`），单核占用偏高；阶段 5 可改成定时器回调（推断：实测未量化，待 `top` 验证）。
6. **frame_id 对齐已确认**：固件发布 `odom.header.frame_id=odom`、`child_frame_id=base_link`，`/scan`=`laser_frame`，`/imu`=`imu_link`；URDF 根链 `base_footprint→base_link→{laser_frame, imu_link, ultrasonic_link}`，无悬空 frame。

## 问题与解决

| 问题 | 原因 | 解决 | 状态 |
|---|---|---|---|
| `ModuleNotFoundError: No module named 'catkin_pkg'`（xuegecar_description 失败，另 2 包 abort） | CMake 取到第三方 Python 3.13，无 ROS 依赖 | 显式 `-DPython3_EXECUTABLE=/usr/bin/python3` 并清缓存重建 | 已解决（实测 4 包全过） |
| 改 PATH 后仍复现同一错误 | colcon 复用 `build/*/CMakeCache.txt` 里缓存的解释器路径 | `rm -rf build install log`（脚本 `--clean`） | 已解决 |
| `joint_state_publisher_gui` 缺失 | 装的是 ros-base 变体，GUI 包未含 | 不影响：launch 用的是非 GUI 版；需要时 `sudo apt install ros-jazzy-joint-state-publisher-gui` | 已解决（无需处理） |
| gmapping 系包可能在 Jazzy 下编译失败 | 上游停止维护、依赖旧 API | 构建阶段用 `--packages-select` 显式排除，SLAM 改走 apt 版 Cartographer | 已规避（未实测 gmapping 构建） |

## 知识体系

- 理论：TF 树与 frame 约定（`odom`→`base_footprint`→`base_link`，REP-105）；URDF 固定关节建模；ROS2 QoS 兼容矩阵（RELIABLE pub → BEST_EFFORT sub 兼容，反之不兼容）**【本阶段新掌握】**；差速底盘速度指令单位约定。
- **teleop 速度刻度【实测澄清】**：`teleop_twist_keyboard` 的 `speed` 是**绝对速度基准**（m/s，按 `i` 即发该值），`z/x` 每次仅 ±10%。默认 1.0 m/s = 3.6 km/h 对 65mm 轮小车已是冲刺速度。固件换算链已核实无放大（`linear.x×1000`→mm/s→`×0.2938`→RPM，轮径 65mm，`motion_controller.cpp:11-16`）。**建图推荐刻度：speed≈0.25 m/s、turn≈0.5 rad/s**（≈29°/s），超速会导致 Cartographer 激光帧间失配。
- 工具：colcon（`--packages-select` / `--cmake-args` / 缓存行为）、rosdep、`ros2 node|topic|pkg` 系列、tf2_echo、rsync 单向同步、URDF+RViz 可视化。**【colcon 缓存行为为本阶段新掌握】**
- 工程：工作空间与仓库解耦 + 单向同步（避免 submodule 与构建产物互相污染）；把踩过的坑固化成幂等脚本（`build_ws.sh` 可重复执行）；先离线自测再上实车（降低硬件依赖的调试成本）。

## 简历要点

- 基于 ROS2 Jazzy 搭建差速小车软件栈，梳理并构建 4 个功能包（接口/URDF/bringup/雷达驱动），从零建立工作空间与可复现构建脚本，构建耗时 8s、零失败。
- 定位并修复 ROS2 构建期 Python 解释器冲突导致的 `catkin_pkg` 缺失故障（CMake 缓存复用），固化为一键脚本，消除团队复现成本。
- 通过阅读固件源码梳理 micro-ROS 端 QoS 与单位约定（`/imu` 等为 BEST_EFFORT、`cmd_vel` 以 mm/s 传递），提前规避订阅端静默丢数据问题。

## 面试问答准备

| 问题 | 答题要点 |
|---|---|
| ROS2 QoS 什么时候会"静默不通"？ | 发布 BEST_EFFORT + 订阅 RELIABLE → 不兼容，且无报错；传感器话题常用 sensor_data；本项目 `/imu`/`/ultrasonic` 就是 BEST_EFFORT，订阅端必须 `SensorDataQoS()` |
| colcon 构建失败后改了环境为什么还复现？ | CMakeCache 缓存 `Python3_EXECUTABLE` 等变量；必须 `--cmake-clean-cache` 或删 build/install/log |
| 为什么不用 gmapping 用 Cartographer？ | gmapping 在 Jazzy 无维护版本（依赖已移除接口），Cartographer 有 apt 官方二进制且支持回环检测，适合后续 Nav2 全流程 |
| TF 树为什么要有 base_footprint？ | REP-105：odom 是漂移的里程计系，base_footprint 是地面投影（z=0），base_link 是车体中心；分层便于 SLAM/导航复用 |
| bringup 节点 1 kHz 忙等有什么问题？ | 单核 CPU 占用高、无必要（里程计 50 Hz）；应改为定时器/`spin` 回调（本阶段仅读码发现，未改，留作优化项） |

## 总结

达成：工作空间编译、bringup 离线自测、TF 树闭合、三份可复现脚本落库。**超出预期的收获**是提前把固件 QoS 与单位约定查清（源码级证据），可直接避免阶段 4/5 的隐性丢数据坑；同时发现 bringup 节点 1 kHz 忙等这一可优化项（阶段 5 顺手改）。差异：实车遥控未做（需小车在线，环境侧无法代跑），列为待办。

## 验收清单

- [x] `colcon build` 4 包成功（`BUILD_EXIT=0`，8.00s）
- [x] `scripts/build_ws.sh` 幂等可复现（含 `--clean`）
- [x] launch 起 3 节点，`/robot_description`、`/tf`、`/tf_static` 正常
- [x] TF `odom→base_footprint` 有广播
- [x] 文档/脚本入库 + 进度更新（本次 commit）
- [x] 实车：`teleop_twist_keyboard` 发 `/cmd_vel`，车轮响应（2026-10-18 00:20 用户确认）
- [x] 实车：`/odom` 49.4 Hz / `/scan` 7.9 Hz / `/imu` 49.5 Hz；QoS 与源码推断一致（`bags/20261018_002001/`）
- [ ] 里程计标定：直行 1 m、旋转 360° 的实测误差（bag 补录后分析）
- [ ] RViz 加载 `display.rviz` 显示模型 + 雷达点
