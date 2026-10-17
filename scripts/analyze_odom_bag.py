#!/usr/bin/env python3
"""里程计标定分析：读 rosbag 中的 /odom 与 /cmd_vel，算「命令 vs 实测」标定系数。

用法（必须先 source ROS，否则 import 失败）：
    source /opt/ros/jazzy/setup.bash
    python3 ~/leap-ros-2/scripts/analyze_odom_bag.py ~/leap_ws/bags/<bag目录>

输出：
  - 时长、消息数、实际频率
  - 里程计路径总长 / 净位移 / 累计转角
  - cmd_vel 积分出的「期望平移、期望旋转」与 odom 实测对比 → 标定系数 k_trans、k_rot
  - 自动分段列出旋转段与直行段（用于人工核对动作序列）
"""

import math
import os
import sys

import rosbag2_py
from nav_msgs.msg import Odometry
from geometry_msgs.msg import Twist
from rclpy.serialization import deserialize_message


def yaw_of(q):
    return math.atan2(2.0 * (q.w * q.z + q.x * q.y), 1.0 - 2.0 * (q.y * q.y + q.z * q.z))


def unwrap(prev, cur):
    d = cur - prev
    while d > math.pi:
        d -= 2 * math.pi
    while d < -math.pi:
        d += 2 * math.pi
    return d


def pick_storage(bag_path):
    """按目录内文件扩展名选存储插件（Jazzy 默认 mcap，旧版/手动指定可能是 sqlite3）。"""
    try:
        names = os.listdir(bag_path)
    except FileNotFoundError:
        raise SystemExit(f"bag 目录不存在：{bag_path}")
    if any(n.endswith(".mcap") for n in names):
        return "mcap"
    if any(n.endswith(".db3") for n in names):
        return "sqlite3"
    raise SystemExit(
        f"bag 目录里没有 .mcap/.db3 文件，bag 可能没录成：{bag_path}（内容：{names[:5]}）"
    )


def read_topic(bag_path, topic, msg_type, storage_id):
    storage_opts = rosbag2_py.StorageOptions(uri=bag_path, storage_id=storage_id)
    converter_opts = rosbag2_py.ConverterOptions(
        input_serialization_format="cdr", output_serialization_format="cdr"
    )
    reader = rosbag2_py.SequentialReader()
    reader.open(storage_opts, converter_opts)
    reader.set_filter([topic])
    out = []
    while reader.has_next():
        _topic, data, t = reader.read_next()
        try:
            msg = deserialize_message(data, msg_type)
        except Exception:
            continue
        out.append((t * 1e-9, msg))
    del reader
    return out


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    bag = sys.argv[1]

    storage_id = pick_storage(bag)
    odom = read_topic(bag, "/odom", Odometry, storage_id)
    cmd = read_topic(bag, "/cmd_vel", Twist, storage_id)
    if not odom:
        print(f"bag 中没有 /odom：{bag}")
        return 2

    t0, t1 = odom[0][0], odom[-1][0]
    dur = t1 - t0
    print(f"bag: {bag}")
    print(f"[基本] 时长 {dur:.1f}s  /odom {len(odom)} 帧 → {len(odom)/dur:.1f} Hz"
          f"  /cmd_vel {len(cmd)} 帧")

    # 里程计统计
    path = 0.0
    yaw = yaw_of(odom[0][1].pose.pose.orientation)
    total_yaw = 0.0
    for (t_a, m_a), (t_b, m_b) in zip(odom, odom[1:]):
        dx = m_b.pose.pose.position.x - m_a.pose.pose.position.x
        dy = m_b.pose.pose.position.y - m_a.pose.pose.position.y
        path += math.hypot(dx, dy)
        yb = yaw_of(m_b.pose.pose.orientation)
        total_yaw += unwrap(yaw, yb)
        yaw = yb
    net = math.hypot(
        odom[-1][1].pose.pose.position.x - odom[0][1].pose.pose.position.x,
        odom[-1][1].pose.pose.position.y - odom[0][1].pose.pose.position.y,
    )
    print(f"[里程计] 路径总长 {path:.3f} m  净位移 {net:.3f} m  "
          f"累计转角 {math.degrees(total_yaw):+.1f}°")

    # cmd_vel 积分（梯形法）
    exp_lin, exp_ang = 0.0, 0.0
    for (t_a, m_a), (t_b, m_b) in zip(cmd, cmd[1:]):
        dt = t_b - t_a
        exp_lin += 0.5 * (m_a.linear.x + m_b.linear.x) * dt
        exp_ang += 0.5 * (m_a.angular.z + m_b.angular.z) * dt
    print(f"[命令积分] 期望平移 {abs(exp_lin):.3f} m  期望旋转 {math.degrees(exp_ang):+.1f}°")

    # 用动作段（旋转段/直行段）分别标定更准：只统计「纯旋转」与「纯直行」
    # 分段：|ω| > 0.25 rad/s 视为旋转，否则 |v| > 0.02 视为直行
    segs, cur = [], None
    for (t_a, m_a), (t_b, m_b) in zip(odom, odom[1:]):
        dt = max(t_b - t_a, 1e-6)
        yb = yaw_of(m_b.pose.pose.orientation)
        ya = yaw_of(m_a.pose.pose.orientation)
        w = unwrap(ya, yb) / dt
        v = math.hypot(m_b.pose.pose.position.x - m_a.pose.pose.position.x,
                       m_b.pose.pose.position.y - m_a.pose.pose.position.y) / dt
        kind = "rot" if abs(w) > 0.25 else ("lin" if v > 0.02 else "idle")
        if cur is None or cur["kind"] != kind:
            if cur and (cur["t1"] - cur["t0"]) > 0.8:
                segs.append(cur)
            cur = {"kind": kind, "t0": t_a, "t1": t_b, "v": 0.0, "w": 0.0, "dt": 0.0}
        cur["t1"] = t_b
        cur["dt"] += dt
        cur["v"] += v * dt
        cur["w"] += w * dt
    if cur and (cur["t1"] - cur["t0"]) > 0.8:
        segs.append(cur)

    print("[动作段] (仅列出 >0.8s 的段)")
    rot_meas = rot_exp = lin_meas = lin_exp = 0.0
    for s in segs:
        ang = math.degrees(s["w"])
        if s["kind"] == "rot":
            rot_meas += abs(s["w"])
            print(f"  旋转 {s['t1']-s['t0']:5.1f}s  实测 {ang:+7.1f}°  "
                  f"均值ω {s['w']/(s['t1']-s['t0']):+.2f} rad/s")
        elif s["kind"] == "lin":
            lin_meas += s["v"]
            print(f"  直行 {s['t1']-s['t0']:5.1f}s  实测 {s['v']:6.3f} m  "
                  f"均值v {s['v']/(s['t1']-s['t0']):+.3f} m/s")

    # 命令侧同期积分
    for t_c0, t_c1, kind in [(s["t0"], s["t1"], s["kind"]) for s in segs]:
        for (t_a, m_a), (t_b, m_b) in zip(cmd, cmd[1:]):
            if t_c0 <= t_a <= t_c1:
                dt = t_b - t_a
                if kind == "rot":
                    rot_exp += m_a.angular.z * dt
                elif kind == "lin":
                    lin_exp += abs(m_a.linear.x) * dt

    print("[标定] (实测 / 期望，1.0=理想)")
    if abs(rot_exp) > 1e-3:
        print(f"  k_rot   = {abs(rot_meas/rot_exp):.3f}   "
              f"(旋转实测 {math.degrees(rot_meas):.1f}° / 期望 {math.degrees(abs(rot_exp)):.1f}°)")
    else:
        print("  k_rot   = 无命令数据可比")
    if lin_exp > 1e-3:
        print(f"  k_trans = {lin_meas/lin_exp:.3f}   "
              f"(直行实测 {lin_meas:.3f} m / 期望 {lin_exp:.3f} m)")
    else:
        print("  k_trans = 无命令数据可比")
    return 0


if __name__ == "__main__":
    sys.exit(main())
