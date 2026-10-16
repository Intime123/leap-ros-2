#!/usr/bin/env bash
# ============================================================
# LEAP ROS2 一键环境搭建脚本
# 适用：Ubuntu 24.04 (noble) → ROS2 Jazzy Jalisco
# 内容：ROS2 desktop + Cartographer + Nav2 + teleop + micro-ROS agent
# 用法：bash scripts/setup_env.sh
# 注意：需要 sudo 权限；磁盘预留 ≥10GB；全程约 10–30 分钟（视网速）
# ============================================================
set -euo pipefail

echo "==> [1/7] 确保 UTF-8 locale（en_US.UTF-8，不切换系统默认语言）"
sudo apt update
sudo apt install -y locales
sudo locale-gen en_US.UTF-8

echo "==> [2/7] 添加 ROS2 apt 软件源"
sudo apt install -y software-properties-common curl
sudo add-apt-repository -y universe
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
  -o /usr/share/keyrings/ros-archive-keyrings.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyrings.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) main" \
  | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null

echo "==> [3/7] 安装 ROS2 Jazzy desktop（含 rviz2/teleop/robot_state_publisher 等）"
sudo apt update
sudo apt install -y ros-jazzy-desktop
grep -q "/opt/ros/jazzy/setup.bash" ~/.bashrc || echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc
source /opt/ros/jazzy/setup.bash

echo "==> [4/7] 安装 SLAM / 导航 / 遥控 / 构建工具"
sudo apt install -y \
  ros-jazzy-cartographer-ros \
  ros-jazzy-navigation2 \
  ros-jazzy-nav2-bringup \
  ros-jazzy-teleop-twist-keyboard \
  python3-colcon-common-extensions \
  python3-rosdep

echo "==> [5/7] rosdep 初始化（已初始化过则跳过）"
sudo rosdep init 2>/dev/null || echo "rosdep 已初始化，跳过"
rosdep update

echo "==> [6/7] micro-ROS agent（apt 优先，无包则走 jazzy 分支源码）"
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

echo "==> [7/7] 安装完成。请逐条验证："
echo "  printenv ROS_DISTRO                                    # 应输出 jazzy"
echo "  ros2 pkg list | grep -E 'cartographer_ros|navigation2'  # 应有两个包"
echo "  ros2 run micro_ros_agent micro_ros_agent --help          # 应打印用法"
echo ""
echo "下一步（阶段 2）：按 B 站教程 BV1nNNb6cER7 烧录 ESP32-S3 固件，"
echo "并在配网页面把 micro-ROS agent 地址改成本机 IP:8888。"
