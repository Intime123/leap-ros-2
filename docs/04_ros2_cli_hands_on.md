# 阶段 3 配套：ROS2 命令行实操课（CLI 先行，循序渐进）

> 授课方式：B 站实操教程节奏。**先跑命令看输出，再讲概念；CLI 与代码 API 一一对照；每节末尾有练习，你做完后回复，再进下一节。**
> 语言：C++（rclcpp），沿用 `xuegecar_bringup` 的技术栈。
> 所有"预期输出"均为本机实测（2026-10-17，Ubuntu 24.04 + ROS2 Jazzy），不是凭记忆写的样稿。

## 课程地图（只列标题，不剧透内容）

| 节 | 主题 | 主要命令 | 对应代码概念 |
|---|---|---|---|
| 0 | 环境与终端约定 | `source` | — |
| **1** | **节点：谁在跑** | `ros2 node list / info` | `rclcpp::Node` |
| 2 | 话题：数据在流动 | `ros2 topic list / echo / hz / info / pub` | publisher / subscriber |
| 3 | 服务与参数：问答与旋钮 | `ros2 service` / `ros2 param` | service server / client、参数 |
| 4 | launch：一次起一堆 | `ros2 launch` | launch.py 写法 |
| 5 | 写第一个 publisher（C++） | 建包 + `colcon build` | 对照 `ros2 topic pub` |
| 6 | 写第一个 subscriber（C++） | 订阅 `/scan` | 对照 `ros2 topic echo` |
| 7 | QoS 实测：为什么收不到数据 | `ros2 topic info -v` | `SensorDataQoS()` |
| 8 | bag 录制回放 | `ros2 bag record / play` | 离线复现 |
| 9 | TF 坐标树 | `tf2_echo` / `view_frames` | TF broadcaster / listener |
| 10 | 综合：避障节点（阶段 5 主线） | — | 发布 `/cmd_vel` |

---

## 第 0 节：环境与终端约定（之后每节都默认已做）

### 目标

建立一套不会互相干扰的终端分工，避免"命令对了但看不到结果"。

### 约定

| 终端 | 用途 | 工作目录 |
|---|---|---|
| **A（系统终端）** | 跑被测系统：`ros2 launch` / `ros2 run`，日志实时打印 | `~/leap_ws` |
| **B（观察终端）** | 跑观察命令：`ros2 node/topic/...`，随时 Ctrl-C | 任意（`~` 即可） |
| **C（练习终端）** | 跑你自己的实验进程 | 任意 |

**每个新开终端都要先 source 两条**（原因见下）：

```bash
source /opt/ros/jazzy/setup.bash          # 提供 ros2 命令 + 系统包
source ~/leap_ws/install/setup.bash       # 把我们编译的 4 个包加进可发现路径
```

> 为什么第二条必须做：`ros2 launch xuegecar_bringup ...` 靠 `AMENT_PREFIX_PATH` 找包，不 source 工作区就报
> `Package 'xuegecar_bringup' not found: "package 'xuegecar_bringup' not found, searching: [...]"`

省事做法（可选，一次性写入 `~/.bashrc`）：

```bash
echo 'source /opt/ros/jazzy/setup.bash' >> ~/.bashrc
echo 'source ~/leap_ws/install/setup.bash' >> ~/.bashrc
```

---

## 第 1 节：节点 —— 先看看系统里"谁在跑"

### 本节目标

用 3 条命令看清：这台机器上现在有哪些 ROS2 节点、每个节点在收什么发什么。先建立直观印象，**不讲概念**。

### 步骤 1.1：在终端 A 起被测系统

```bash
cd ~/leap_ws
ros2 launch xuegecar_bringup xuegecar_bringup.launch.py
```

预期：终端 A 打印三行 `[INFO] [launch]: All log files...` + 各节点启动日志，然后停住（进程常驻）。**这一步不需要小车开机**——bringup 离线也能起，只是 `/odom` 没有数据。

### 步骤 1.2：在终端 B 看节点列表

```bash
ros2 node list
```

预期输出（本机实测）：

```
/joint_state_publisher
/robot_state_publisher
/xuegecar_bringup
```

### 步骤 1.3：看单个节点的"接线图"

```bash
ros2 node info /xuegecar_bringup
```

预期输出（本机实测，参数服务部分已折叠说明）：

```
/xuegecar_bringup
  Subscribers:
    /odom: nav_msgs/msg/Odometry
    /parameter_events: rcl_interfaces/msg/ParameterEvent
  Publishers:
    /parameter_events: rcl_interfaces/msg/ParameterEvent
    /rosout: rcl_interfaces/msg/Log
    /tf: tf2_msgs/msg/TFMessage
  Service Servers:
    /xuegecar_bringup/describe_parameters: rcl_interfaces/srv/DescribeParameters
    /xuegecar_bringup/get_parameters: rcl_interfaces/srv/GetParameters
    /xuegecar_bringup/set_parameters: rcl_interfaces/srv/SetParameters
    ... (共 7 个，都是参数相关)
  Action Servers:
  Action Clients:
```

### 步骤 1.4：看看隐藏节点

```bash
ros2 node list -a
```

预期：`-a` 比默认多出一行类似

```
/_ros2cli_daemon_0_f34bc238c59c4dffac286098f2c62fef
```

这是 `ros2` 命令行自己的守护进程（daemon），默认隐藏，不用管它。

### 原理讲解（看完输出再读）

**节点（node）= 一个进程里的一项职责。** ROS2 程序不是"一个大程序"，而是若干节点各干各的事、靠话题互相通信：

| 节点 | 职责 | 证据 |
|---|---|---|
| `/joint_state_publisher` | 发布关节角度（本项目 URDF 全是固定关节，所以它基本空转） | 步骤 1.2 的列表 |
| `/robot_state_publisher` | 读 URDF，把 `base_footprint→base_link→laser_frame...` 发成 TF | 步骤 1.3 里它的 Publishers 含 `/tf`、`/tf_static`、`/robot_description` |
| `/xuegecar_bringup` | 订阅 `/odom` → 广播 `odom→base_footprint` | 步骤 1.3 的 `Subscribers: /odom` 与 `Publishers: /tf` |

三点必须记住：

1. **节点名以 `/` 开头 = 全局命名空间**。代码里写 `Node("xuegecar_bringup")`，命令行看到的就是 `/xuegecar_bringup`。
2. **没有中心服务器**。ROS1 靠 roscore，ROS2 靠 DDS 自动发现：节点起来后互相"喊一声"就发现了。所以你开新终端跑 `ros2 node list` 立刻能看到——这是分布式的前提，也是"为什么看不到"的排查入口（见下）。
3. **`node info` 里那 7 个参数服务 + `/parameter_events` + `/rosout` 是每个节点自带的**，不是业务代码写的。以后看 `node info` 时只关注业务那几行（本例就是 `/odom` 和 `/tf`）。

### CLI ↔ 代码对照（第 1 节只要记住这张表）

| 命令行 | 对应 C++ 代码（`~/leap_ws/src/xuegecar_bringup/src/xuegecar_bringup.cpp`） |
|---|---|
| `ros2 node list` 看到 `/xuegecar_bringup` | `rclcpp::init(argc, argv);`（第 58 行）+ `std::make_shared<TopicSubscribe01>("xuegecar_bringup")`（第 60 行） |
| `Subscribers: /odom: nav_msgs/msg/Odometry` | `create_subscription<nav_msgs::msg::Odometry>("odom", rclcpp::SensorDataQoS(), ...)`（第 12 行） |
| `Publishers: /tf` | `tf_broadcaster_->sendTransform(transform)`（第 52 行，TF 底层就是 `/tf` 话题） |

> 一句话：**命令行看到的每一个 Subscriber/Publisher，代码里都有一行 `create_subscription` / `create_publisher` 与之对应。** 第 5、6 节我们自己写节点时会反过来验证这一点。

### 常见报错与排查（第 1 节范围内）

| 现象 | 原因 | 处置 |
|---|---|---|
| `ros2：未找到命令` | 没 source `/opt/ros/jazzy/setup.bash` | 补 source；或写入 `~/.bashrc` |
| `Package 'xuegecar_bringup' not found` | 没 source `~/leap_ws/install/setup.bash`，或还没编译 | 补 source；没编译就跑 `bash ~/leap-ros-2/scripts/build_ws.sh` |
| `node list` 是空的，但 `ros2 node info /xuegecar_bringup` 能看到 | ros2 daemon 缓存异常（**本会话实测出现过一次**） | `ros2 daemon stop && ros2 daemon start`；或绕过缓存 `ros2 node list --no-daemon --spin-time 5` |
| `WARNING: ... nodes share an exact name` | 上一次 launch 没退干净，同名节点跑了两个 | 终端 A 用 Ctrl-C 正常退出；残留用 `pkill -f "xuege[x]ar_bringup"` 清掉（`[]` 是为了不让 pkill 匹配到它自己的命令行） |
| 只看得到自己终端起的节点，看不到别人的 | `ROS_DOMAIN_ID` 不同（默认 0） | 同一网络内统一 `export ROS_DOMAIN_ID=0` |

### 练习（做完再进第 2 节）

**练习 1（判断题）**：把终端 A 的 launch 用 Ctrl-C 停掉，只在终端 B 跑 `ros2 node list`。输出是什么？为什么是这个结果？

**练习 2（动手）**：开一个**真实交互终端 C**（不要用管道/重定向，见下方注意），跑：

```bash
ros2 run teleop_twist_keyboard teleop_twist_keyboard
```

回到终端 B 再跑 `ros2 node list` → 多出哪个节点？用 `ros2 node info <那个节点名>` 看它**发布**的话题叫什么、类型是什么？

> 注意：teleop 必须读键盘，非交互终端会直接崩（`saveTerminalSettings` 需要 tty，实测报错 `File ".../teleop_twist_keyboard.py", line 135, in main / settings = saveTerminalSettings()`）。必须在真终端里跑，看完用 Ctrl-C 退出。

**练习 3（自查，口述即可）**：`ros2 node list` 看不到预期节点时，你会按什么顺序排查？至少说出三条。

### 完成确认

把三个练习的答案/输出贴给我（或说"做完了"并附上练习 2 的 `node info` 输出），确认后我给第 2 节：话题（`ros2 topic list / echo / hz / info / pub`，含"为什么 `/imu` 用默认 QoS 会收不到"的实测）。
