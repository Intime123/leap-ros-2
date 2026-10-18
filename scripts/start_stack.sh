#!/usr/bin/env bash
# 阶段 3：一键启动 micro-ROS agent + bringup
# 用法: bash scripts/start_stack.sh            # agent 后台 + bringup 前台（Ctrl-C 全停）
#       AGENT_PORT=8888 bash scripts/start_stack.sh
# 前提: 小车已上电并连上同一热点；笔记本 IP 已写入小车 NVS（固件默认 192.168.31.214:8888）

set -u
PORT="${AGENT_PORT:-8888}"
WS="${WS:-$HOME/leap_ws}"
LOGDIR="$WS/log"
mkdir -p "$LOGDIR"

# ROS2 setup.bash 引用未赋值变量 AMENT_TRACE_SETUP_FILES，在 set -u 下会报“未绑定的变量”
set +u
# shellcheck disable=SC1091
source /opt/ros/jazzy/setup.bash
# shellcheck disable=SC1091
source "$WS/install/setup.bash"
set -u

AGENT_WS=""
for cand in "$HOME/microros_agent_ws" "$HOME/microros_ws"; do
  if [ -f "$cand/install/setup.bash" ]; then AGENT_WS="$cand"; break; fi
done
if [ -n "$AGENT_WS" ]; then
  # colcon 生成的 install/setup.bash 同样有未绑定变量（COLCON_TRACE 等），set +u 包裹
  set +u
  # shellcheck disable=SC1091
  source "$AGENT_WS/install/setup.bash"
  set -u
  echo "agent 工作区: $AGENT_WS"
else
  echo "未找到 micro_ros_agent 源码工作区，尝试用系统包" >&2
fi

cleanup() {
  echo "停止中..."
  [ -n "${AGENT_PID:-}" ] && kill "$AGENT_PID" 2>/dev/null || true
  exit 0
}
trap cleanup INT TERM

echo "启动 micro_ros_agent udp4 --port $PORT (日志: $LOGDIR/agent.log)"
ros2 run micro_ros_agent micro_ros_agent udp4 --port "$PORT" 2>&1 | tee "$LOGDIR/agent.log" &
AGENT_PID=$!
sleep 2

echo "启动 bringup（前台）..."
ros2 launch xuegecar_bringup xuegecar_bringup.launch.py
cleanup
