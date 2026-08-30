CROSS_COMPILE ?= loongarch64-linux-gnu-
CC      := $(CROSS_COMPILE)gcc
OBJCOPY := $(CROSS_COMPILE)objcopy
QEMU    ?= qemu-system-loongarch64
QEMU_MACHINE ?= virt
QEMU_MEM ?= 512M
QEMU_ARGS ?= -M $(QEMU_MACHINE) -m $(QEMU_MEM) -nographic -kernel $(TARGET)

BUILD_DIR := build
TARGET    := $(BUILD_DIR)/minios.elf
BIN       := $(BUILD_DIR)/minios.bin

CFLAGS  := -Wall -Wextra -O2 -g -ffreestanding -fno-builtin -fno-stack-protector
CFLAGS  += -nostdlib -mabi=lp64d -march=loongarch64
CFLAGS  += $(CFLAGS_EXTRA)
ASFLAGS := $(CFLAGS)
LDFLAGS := -T kernel/linker.ld -nostdlib -static

# 第 1–5 次课源文件（后续课次在对应 tag 中再追加，勿提前混入）
SRCS_C := \
	kernel/main.c \
	kernel/printk.c

SRCS_S := \
	boot/start.S \
	lib/string.S \
	lib/regs_alu.S \
	lib/mem_fp.S \
	lib/branch_loop.S

OBJS := $(patsubst %.c,$(BUILD_DIR)/%.o,$(SRCS_C))
OBJS += $(patsubst %.S,$(BUILD_DIR)/%.o,$(SRCS_S))

.PHONY: all run debug clean

all: $(TARGET) $(BIN)

$(TARGET): $(OBJS) kernel/linker.ld
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(OBJS)

$(BIN): $(TARGET)
	$(OBJCOPY) -O binary $< $@

$(BUILD_DIR)/%.o: %.c
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -Iinclude -c $< -o $@

$(BUILD_DIR)/%.o: %.S
	mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -Iinclude -c $< -o $@

run: $(TARGET)
	$(QEMU) $(QEMU_ARGS)

debug: $(TARGET)
	$(QEMU) $(QEMU_ARGS) -S -s

clean:
	rm -rf $(BUILD_DIR)
