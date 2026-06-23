# tests

建议测试顺序：

1. `make clean`
2. `make`
3. `make run`
4. 观察串口输出是否与 README 中的预期一致

当前环境如果缺少 LoongArch 交叉工具链或 QEMU，`make`/`make run` 会失败。
