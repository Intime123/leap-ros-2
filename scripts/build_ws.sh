#!/usr/bin/env bash
# 阶段 3：构建 ROS2 工作空间 ~/leap_ws
# 用法: bash scripts/build_ws.sh           # 同步源码 + 构建核心包
#       bash scripts/build_ws.sh --clean   # 清理 build/install/log 后全量重建
#       bash scripts/build_ws.sh --rosdep  # 构建前先装依赖（需要 sudo）

set -e

WS="${WS:-$HOME/leap_ws}"
UPSTREAM="${UPSTREAM:-$HOME/leap-ros-2/src/upstream/leap_ros_ws}"
# 只构建阶段 3 需要的包：gmapping 系在 Jazzy 下无维护（openslam_gmapping/slam_gmapping 跳过），
# cartographer / navigation2 / camera / mavlink_bridge 在阶段 4-6 按需另建。
PKGS="leap_interfaces xuegecar_description xuegecar_bringup camsense_lidar"
# 与 apt 安装的 ROS 一致（/opt/ros/jazzy/lib/python3.12）。避免被 PATH 里的第三方 Python 抢走。
ROS_PY=/usr/bin/python3

DO_CLEAN=0
DO_ROSDEP=0
for arg in "$@"; do
  case "$arg" in
    --clean) DO_CLEAN=1 ;;
    --rosdep) DO_ROSDEP=1 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

echo "[1/4] 同步源码 $UPSTREAM -> $WS/src"
mkdir -p "$WS/src"
for p in $PKGS; do
  if [ ! -d "$UPSTREAM/$p" ]; then
    echo "  缺失上游包: $UPSTREAM/$p" >&2
    exit 1
  fi
  rsync -a --delete "$UPSTREAM/$p/" "$WS/src/$p/"
  echo "  synced: $p"
done

# shellcheck disable=SC1091
source /opt/ros/jazzy/setup.bash

if [ "$DO_CLEAN" = "1" ]; then
  echo "[2/4] 清理 build/install/log"
  rm -rf "$WS/build" "$WS/install" "$WS/log"
else
  echo "[2/4] 保留缓存（--clean 可全量重建）"
fi

if [ "$DO_ROSDEP" = "1" ]; then
  echo "[3/4] rosdep 安装依赖"
  cd "$WS"
  rosdep install --from-paths src --ignore-src -y --rosdistro jazzy
else
  echo "[3/4] 跳过 rosdep（--rosdep 开启）"
fi

echo "[4/4] colcon build: $PKGS"
cd "$WS"
colcon build --packages-select $PKGS --cmake-args -DPython3_EXECUTABLE="$ROS_PY"
echo "BUILD_EXIT=$?"
echo "下一步: source $WS/install/setup.bash"
