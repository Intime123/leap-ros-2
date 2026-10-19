# 阶段 4：Cartographer 雷达建图

> 前置：阶段 2（五话题在线）、阶段 3（bringup + teleop 遥控）已验证。
> 视觉模块（阶段 6.5）已看流验证，ROS 集成推迟到阶段 5 融合时进行。

## 0. 配置选型（本阶段第一个关键决策，已定）

上游有两份 lua，**必须用 `xuegecar_2d.lua`**：

| 配置项 | `xuegecar_2d.lua`（用这个） | `xuegecar_laser_2d.lua`（默认，**不能用**） |
|---|---|---|
| tracking_frame | base_link | laser_frame |
| published_frame | odom | laser_frame |
| provide_odom_frame | **false** | true |
| use_odometry | **true**（消费固件 /odom） | false |

原因：launch 默认的 laser 版会让 Cartographer 自己发布 `odom→laser_frame`，与固件的 `odom→base_footprint→…→laser_frame` 形成 **laser_frame 双父 TF 冲突**（RViz TF 树报错、地图抖动）。2d 版只发布 `map→odom`（SLAM 校正层），`odom→base_footprint` 仍由固件提供——这是 ROS 导航的标准分层布局（REP-105）。

启动方式：`ros2 launch xuegecar_cartographer xuegecar_cartographer.launch.py configuration_basename:=xuegecar_2d.lua`

## 1. 终端分工与启动顺序

**终端 1**（系统底座）：
```bash
bash ~/leap-ros-2/scripts/start_stack.sh
```
等五话题出现（`/odom /scan /imu /battery_state /ultrasonic`）。

**终端 2**（建图，三个节点一起起，含 RViz）：
```bash
source /opt/ros/jazzy/setup.bash && source ~/leap_ws/install/setup.bash
ros2 launch xuegecar_cartographer xuegecar_cartographer.launch.py configuration_basename:=xuegecar_2d.lua
```

**终端 3**（键盘，先降速再动）：
```bash
source /opt/ros/jazzy/setup.bash && source ~/leap_ws/install/setup.bash
ros2 run teleop_twist_keyboard teleop_twist_keyboard
```

**RViz 设置**（终端 2 会自动打开 RViz）：
1. 左侧 Displays 面板 → Fixed Frame 改为 `map`
2. Add → Map → topic `/map`；Add → LaserScan → topic `/scan`
3. 或直接 Open Config：`~/leap_ws/install/xuegecar_cartographer/share/xuegecar_cartographer/config/cartographer.rviz`

**预期输出**（终端 2）：cartographer_node 打印 I0 日志流，RViz 出现雷达点云；开车后逐渐长出地图和轨迹。

## 2. 开车建图要领（决定成败的三条）

1. **速度压到底**：先按 `z` 约十次（speed≈0.25 m/s）、`s` 约五次（turn≈0.5 rad/s）。超速 = 帧间失配 = 墙壁重影，雷达 10Hz 下帧间转向超过 ~15° 匹配就开始不可靠。
2. **路线像画洋葱**：绕房间外圈一整圈 → 内圈小圈 → 最后**回到起点附近**（闭环，触发后端优化把累积误差抹平）。
3. **转速要慢而匀**，避免原地急转（可回看 teleop 速度刻度：turn 0.5 rad/s ≈ 29°/s）。

自查（开车过程中随时在终端 4 跑）：
```bash
ros2 topic echo /tracked_pose --once    # Cartographer 估计的位姿，走直线时 x/y 应单调平滑
```

## 3. 保存地图（建完先别停 Cartographer）

**方式 A：pbstream（Cartographer 原生，保留全部状态）**
```bash
ros2 service call /write_state cartographer_ros_msgs/srv/WriteState "{filename: '/home/yaen/maps/room1.pbstream'}"
mkdir -p ~/maps   # 目录不存在先建
```

**方式 B：pgm+yaml（Nav2 要用的格式）**
```bash
source /opt/ros/jazzy/setup.bash
mkdir -p ~/maps
ros2 run nav2_map_server map_saver_cli -f ~/maps/room1
```
产出 `room1.pgm`（灰度图）+ `room1.yaml`（分辨率/原点），阶段 6 Nav2 直接用。

> 首次保存若遇到 `~/maps` 权限报错（root 属主残留），执行一次：
> `sudo chown -R $USER:$USER ~/leap_ws ~/maps`，之后不再需要。

## 4. 坑位速查

| 现象 | 原因与处理 |
|---|---|
| RViz Fixed Frame 报 TF 错误 | 忘传 `configuration_basename:=xuegecar_2d.lua`（用了默认 laser 版） |
| 地图不动 | `/scan` 没数据——确认终端 1 五话题在线；没起 camsense_lidar（正确，固件已发 /scan） |
| 墙壁重影/拖影 | 车速过快（见 2.1），降速重扫 |
| map→odom 与 odom→base_footprint 断裂 | bringup 没跑（固件 TF 缺失），检查终端 1 |
| 保存 pbstream 报目录不存在 | 先 `mkdir -p ~/maps` |

## 5. 自查题（建图完成后回答）

1. 为什么 Cartographer 只发 `map→odom` 而不直接发 `map→base_footprint`？（提示：轮式里程计短时平滑、SLAM 长时无漂移，两者如何分工）
2. `use_odometry=true` 时，如果轮子打滑严重，地图会怎么坏？哪个参数可以降低里程计权重？
3. `provide_odom_frame=true` 的配置在什么场景才合理？（提示：没有底层里程计的底盘）

## 6. 本阶段产物

- `~/maps/room1.pgm + yaml`（Nav2 用）+ `room1.pbstream`（可重开继续建）
- 截图留档：建图完成时的 RViz 画面（放 docs/img/，简历素材）
