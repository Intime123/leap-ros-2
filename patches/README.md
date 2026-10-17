# patches/

对上游 submodule（`src/upstream/leap_ros_mcu_driver`）所做的最小适配补丁。
submodule 本身指向上游仓库，无法直接推送，因此以 patch 形式留痕，重建环境时应用即可。

| 补丁 | 作用 | 触发场景 |
|---|---|---|
| `0001-mcu_driver-fix-abs-paths-for-v5.5.3.patch` | 把上游提交里写死的作者构建机绝对路径（`/root/maturo_project/...`、`/root/.espressif/...`）改成本机路径 | ESP-IDF v5.5.3 首次编译 `leap_low_v1` 时，CMake 报找不到 toolchain / 组件 |

应用方式：

```bash
cd src/upstream/leap_ros_mcu_driver
git apply ../../../patches/0001-mcu_driver-fix-abs-paths-for-v5.5.3.patch
# 若路径与补丁内记录不一致（不同机器的用户名/目录），改为手工替换：
grep -rl "/root/maturo_project" . | xargs sed -i 's#/root/maturo_project/leap_low_v1#<你的工程绝对路径>#g'
```

注意：补丁只覆盖 `dependencies.lock` 与 `esp32_toolchain.cmake` 两个文本文件；
`libmicroros.a` 是构建产物（二进制），不入库，编译时会由 `libmicroros.mk` 重新生成。
