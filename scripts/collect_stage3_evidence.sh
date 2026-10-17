#!/usr/bin/env bash
# 阶段 3 验收留痕：一键采集实测数据（约 90 秒，其中 60 秒需要你开车）
# 用法: bash scripts/collect_stage3_evidence.sh
# 前提: 终端 A 已跑 bash scripts/start_stack.sh（agent + bringup 在线，小车可遥控）
#
# 采集内容：
#   1) /odom /scan /imu 的实际频率
#   2) 三者的 QoS（验证固件端 reliable / best_effort 约定）
#   3) /odom 与 /scan 各取一帧（看 frame_id、量程、点数）
#   4) 60 秒 ros2 bag 全话题录制（录制期间请用键盘开车：直行约 1 米 → 停 → 原地转 90°）

set -u
WS="${WS:-$HOME/leap_ws}"
OUT="${OUT:-$WS/bags/$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$OUT"

# shellcheck disable=SC1091
source /opt/ros/jazzy/setup.bash
# shellcheck disable=SC1091
source "$WS/install/setup.bash"

echo "输出目录: $OUT"
echo "=== [1/4] 话题频率（每项 5 秒） ==="
for t in /odom /scan /imu; do
  echo "--- $t ---"
  timeout 6 ros2 topic hz "$t" 2>&1 | head -3 | tee "$OUT/hz$(echo "$t" | tr / _).txt"
done

echo "=== [2/4] QoS ==="
for t in /odom /scan /imu; do
  echo "--- $t ---"
  timeout 5 ros2 topic info "$t" --verbose 2>&1 | grep -iE "Publisher|Subscriber|reliability|durability|depth" | head -8 | tee "$OUT/qos$(echo "$t" | tr / _).txt"
done

echo "=== [3/4] 单帧内容 ==="
timeout 5 ros2 topic echo --once /odom 2>&1 | head -30 > "$OUT/odom_once.txt"; echo "saved odom_once.txt"
timeout 5 ros2 topic echo --once /scan 2>&1 | head -20 > "$OUT/scan_once.txt"; echo "saved scan_once.txt"
timeout 5 ros2 topic echo --once /battery_state 2>&1 | head -20 > "$OUT/battery_once.txt"; echo "saved battery_once.txt"

echo "=== [4/4] bag 录制 60 秒：请用键盘开车（直行 1 米 → 停 → 原地转 90°） ==="
timeout 60 ros2 bag record -o "$OUT/rosbag" /odom /scan /imu /tf /tf_static /cmd_vel /battery_state 2>&1 | tail -3

echo "完成: $OUT"
ls -la "$OUT"
