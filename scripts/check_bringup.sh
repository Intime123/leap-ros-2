#!/usr/bin/env bash
# 阶段 3：bringup 体检——话题、频率、QoS、TF 树
# 用法: bash scripts/check_bringup.sh            # 全量检查（约 15s）
#       bash scripts/check_bringup.sh --short     # 只看话题与节点
# 前提: 已 source ROS + 工作区，agent 与 bringup 正在运行

set -u
SHORT=0
[ "${1:-}" = "--short" ] && SHORT=1

# shellcheck disable=SC1091
source /opt/ros/jazzy/setup.bash
# shellcheck disable=SC1091
source "${WS:-$HOME/leap_ws}/install/setup.bash"

echo "=== node list ==="
ros2 node list

echo "=== topic list ==="
ros2 topic list

if [ "$SHORT" = "1" ]; then exit 0; fi

for t in /odom /scan /imu /battery_state /ultrasonic; do
  echo "=== topic hz $t (3s) ==="
  timeout 4 ros2 topic hz "$t" 2>&1 | head -3
done

echo "=== QoS: /cmd_vel ==="
timeout 4 ros2 topic info /cmd_vel --verbose 2>&1 | grep -A6 -i "reliability\|durability" | head -12

echo "=== TF: odom -> base_footprint -> base_link -> laser_frame ==="
timeout 6 ros2 run tf2_ros tf2_echo odom laser_frame 2>&1 | head -8

echo "=== 提示 ==="
echo "遥控: ros2 run teleop_twist_keyboard teleop_twist_keyboard"
RVIZ_CFG="$(ros2 pkg prefix xuegecar_description 2>/dev/null)/share/xuegecar_description/rviz/display.rviz"
echo "可视化: rviz2 -d $RVIZ_CFG"
