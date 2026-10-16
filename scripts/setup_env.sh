#!/usr/bin/env bash
# ============================================================
# LEAP ROS2 一键环境搭建脚本
# 适用：Ubuntu 24.04 (noble) → ROS2 Jazzy Jalisco
# 内容：ROS2 desktop + Cartographer + Nav2 + teleop + micro-ROS agent
# 用法：bash scripts/setup_env.sh
# 注意：需要 sudo 权限；磁盘预留 ≥10GB；全程约 10–30 分钟（视网速）
# 自愈：自动清理陈旧 ROS 源与过期密钥（EXPKEYSIG F42ED6FBAB17C654 / 无 Release 文件）
# ============================================================
set -euo pipefail

echo "==> [0/8] 清理陈旧的 ROS 源与过期密钥（修复 EXPKEYSIG / 无 Release 文件报错）"
# 旧教程遗留的 ROS1 源（/ros/ubuntu 无 noble 版本，必须删除）
sudo rm -f /etc/apt/sources.list.d/ros-latest.list /etc/apt/sources.list.d/ros.list
# 旧版 Open Robotics 密钥（本地副本已过期；当前 ros.key 中该密钥已续期至 2030-05-30）
sudo apt-key del F42ED6FBAB17C654 2>/dev/null || true
sudo rm -f /etc/apt/trusted.gpg.d/ros.gpg /etc/apt/trusted.gpg.d/ros2.gpg
sudo rm -f /usr/share/keyrings/ros-archive-keyring.gpg /usr/share/keyrings/ros-archive-keyrings.asc
# 时钟异常也会导致 EXPKEYSIG，顺带确认
timedatectl status | grep -E "synchronized|System clock" || true

echo "==> [1/8] 确保 UTF-8 locale（en_US.UTF-8，不切换系统默认语言）"
sudo apt update
sudo apt install -y locales
sudo locale-gen en_US.UTF-8

echo "==> [2/8] 添加 ROS2 apt 软件源（当前有效密钥，dearmor 为二进制 keyring）"
sudo apt install -y software-properties-common curl gnupg
sudo add-apt-repository -y universe
sudo mkdir -p /usr/share/keyrings
curl -fsSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
  | sudo gpg --dearmor -o /usr/share/keyrings/ros-archive-keyrings.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyrings.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) main" \
  | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null

echo "==> [3/8] 安装 ROS2 Jazzy desktop（含 rviz2/teleop/robot_state_publisher 等）"
sudo apt update
sudo apt install -y ros-jazzy-desktop
grep -q "/opt/ros/jazzy/setup.bash" ~/.bashrc || echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc
source /opt/ros/jazzy/setup.bash

echo "==> [4/8] 安装 SLAM / 导航 / 遥控 / 构建工具"
sudo apt install -y \
  ros-jazzy-cartographer-ros \
  ros-jazzy-navigation2 \
  ros-jazzy-nav2-bringup \
  ros-jazzy-teleop-twist-keyboard \
  python3-colcon-common-extensions \
  python3-rosdep

echo "==> [5/8] rosdep 初始化（已初始化过则跳过）"
sudo rosdep init 2>/dev/null || echo "rosdep 已初始化，跳过"
rosdep update

echo "==> [6/8] micro-ROS agent（apt 优先，无包则走 jazzy 分支源码）"
if sudo apt install -y ros-jazzy-micro-ros-agent; then
  echo "micro-ROS agent：apt 安装成功"
else
  echo "micro-ROS agent：apt 无可用包，改用源码编译（jazzy 分支）"
  mkdir -p ~/microros_agent_ws/src
  cd ~/microros_agent_ws/src
  git clone -b jazzy https://github.com/micro-ROS/micro-ROS-Agent.git
  cd ~/microros_agent_ws
  source /opt/ros/jazzy/setup.bash
  rosdep install --from-paths src --ignore-src -y
  colcon build --symlink-install
  grep -q "microros_agent_ws/install/setup.bash" ~/.bashrc || \
    echo "source ~/microros_agent_ws/install/setup.bash" >> ~/.bashrc
  echo "micro-ROS agent：源码编译完成"
fi

echo "==> [7/8] 安装完成。请逐条验证："
echo "  printenv ROS_DISTRO                                    # 应输出 jazzy"
echo "  ros2 pkg list | grep -E 'cartographer_ros|navigation2'  # 应有两个包"
echo "  ros2 run micro_ros_agent micro_ros_agent --help          # 应打印用法"
echo ""
echo "下一步（阶段 2）：按 B 站教程 BV1nNNb6cER7 烧录 ESP32-S3 固件，"
echo "并在配网页面把 micro-ROS agent 地址改成本机 IP:8888。"
