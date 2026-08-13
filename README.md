# UPXEX

> **English first · 中文随后**

---

## English

### Project overview

**UPXEx** is a customized UPX build focused on reducing the startup overhead of packed applications. It keeps the standard UPX workflow and adds [misa77](https://github.com/welcome-to-the-sunny-side/misa77), a codec designed for very fast decompression.

The recommended profile is **misa77 level 1**. It targets the best startup-time balance while keeping packed size close to classic UPX `--fast`.

### Summary

The data shows that **misa77 substantially reduces decompression-related startup delay compared with UPX `--fast`**. Across test1–test7, misa77 level 1 reduces mean startup time by **21.4–326.4 ms** relative to `--fast`.

Packed size remains close to `--fast`: level 1 trades a modest size increase for a much lower startup penalty. The advantage is especially clear for larger executables. For example, compared with `--fast`, test2 and test3 reduce mean startup time by **183.2 ms** and **326.4 ms** respectively.

### Test method

- **Method:** `CreateProcess(CREATE_SUSPENDED)` → `WaitForInputIdle`
- **Sampling:** 15 randomized, interleaved launches per variant
- **Unit:** milliseconds (ms)
- **Note:** test5 uses window-handle detection; all other tests use `WaitForInputIdle`.

### Quick comparison

Only the original executable, UPX `--fast`, and recommended misa77 level 1 are shown here. The complete data follows below.

| Test | Variant | File size | Median (ms) | Mean (ms) |
|---|---|---:|---:|---:|
| test1 | Original (uncompressed) | 28.1 MB | 196.7 | 198.3 |
| test1 | UPX `--fast` | 14.7 MB | 315.5 | 317.1 |
| test1 | misa77 level 1 (recommended) | 16.4 MB | 223.6 | 224.2 |

| Test | Variant | File size | Median (ms) | Mean (ms) |
|---|---|---:|---:|---:|
| test2 | Original (uncompressed) | 61.8 MB | 208.4 | 208.7 |
| test2 | UPX `--fast` | 30.5 MB | 450.5 | 451.9 |
| test2 | misa77 level 1 (recommended) | 34.2 MB | 269.3 | 268.7 |

| Test | Variant | File size | Median (ms) | Mean (ms) |
|---|---|---:|---:|---:|
| test3 | Original (uncompressed) | 136.0 MB | 86.7 | 87.3 |
| test3 | UPX `--fast` | 75.9 MB | 476.1 | 476.5 |
| test3 | misa77 level 1 (recommended) | 77.6 MB | 149.3 | 150.1 |

| Test | Variant | File size | Median (ms) | Mean (ms) |
|---|---|---:|---:|---:|
| test4 | Original (uncompressed) | 22.7 MB | 30.4 | 43.1 |
| test4 | UPX `--fast` | 13.3 MB | 108.0 | 108.3 |
| test4 | misa77 level 1 (recommended) | 13.8 MB | 50.4 | 50.4 |

| Test | Variant | File size | Median (ms) | Mean (ms) |
|---|---|---:|---:|---:|
| test5 | Original (uncompressed) | 17.7 MB | 30.5 | 30.4 |
| test5 | UPX `--fast` | 13.2 MB | 92.5 | 92.3 |
| test5 | misa77 level 1 (recommended) | 13.3 MB | 61.1 | 59.0 |

| Test | Variant | File size | Median (ms) | Mean (ms) |
|---|---|---:|---:|---:|
| test6 | Original (uncompressed) | 6.4 MB | 228.5 | 242.8 |
| test6 | UPX `--fast` | 3.0 MB | 259.5 | 263.8 |
| test6 | misa77 level 1 (recommended) | 3.3 MB | 243.3 | 242.4 |

| Test | Variant | File size | Median (ms) | Mean (ms) |
|---|---|---:|---:|---:|
| test7 | Original (uncompressed) | 18.4 MB | 17.1 | 17.3 |
| test7 | UPX `--fast` | 10.7 MB | 91.7 | 92.4 |
| test7 | misa77 level 1 (recommended) | 11.3 MB | 34.9 | 34.8 |

### How to use

Use the customized `upx.exe` and choose a misa77 level from `-1` to `4`:

```powershell
upx.exe --misa77-level=<level> <program-path>
```

Recommended level 1 example:

```powershell
upx.exe --misa77-level=1 C:\test.exe
```

You can also use **UPXEx GUI (UPXEXGUI)** for drag-and-drop packing, algorithm and level selection, unpacking, and Windows startup comparison. It will be published in **Releases**.

---

## 中文

### 项目简介

**UPXEx** 是基于 UPX 定制的增强版本，目标是降低程序压缩后的启动额外开销。在保留 UPX 常规使用方式的基础上，增加了 [misa77](https://github.com/welcome-to-the-sunny-side/misa77) 算法支持；该算法以极快解压为设计重点。

推荐使用 **misa77 等级 1**。它在启动速度、压缩率之间提供较好的平衡，压缩体积也与传统 UPX `--fast` 较为接近。

### 结论摘要

数据表明，相比 UPX `--fast`，**misa77 能明显降低解压带来的启动延迟**。在 test1–test7 中，misa77 等级 1 的平均启动时间相对 `--fast` 缩短 **21.4–326.4 ms**。

在压缩体积方面，等级 1 与 `--fast` 差距较小：以少量体积增加换取明显更低的启动额外耗时。程序越大，这一优势通常越明显；例如 test2 与 test3 相比 `--fast` 的平均启动时间分别缩短 **183.2 ms** 与 **326.4 ms**。

### 测试方法

- **测试方式：** `CreateProcess(CREATE_SUSPENDED)` → `WaitForInputIdle`
- **测试轮数：** 每个变体随机交错启动 15 次
- **时间单位：** 毫秒（ms）
- **说明：** test5 使用窗口句柄检测；其余测试使用 `WaitForInputIdle`。

### 简单对比数据

此处仅展示每组最有代表性的三行：原版、UPX `--fast` 与推荐的 misa77 等级 1；完整数据见下方。

| 测试 | 版本 | 文件大小 | 中位数（ms） | 平均值（ms） |
|---|---|---:|---:|---:|
| test1 | 原版（未压缩） | 28.1 MB | 196.7 | 198.3 |
| test1 | UPX `--fast` | 14.7 MB | 315.5 | 317.1 |
| test1 | misa77 等级 1（推荐） | 16.4 MB | 223.6 | 224.2 |

| 测试 | 版本 | 文件大小 | 中位数（ms） | 平均值（ms） |
|---|---|---:|---:|---:|
| test2 | 原版（未压缩） | 61.8 MB | 208.4 | 208.7 |
| test2 | UPX `--fast` | 30.5 MB | 450.5 | 451.9 |
| test2 | misa77 等级 1（推荐） | 34.2 MB | 269.3 | 268.7 |

| 测试 | 版本 | 文件大小 | 中位数（ms） | 平均值（ms） |
|---|---|---:|---:|---:|
| test3 | 原版（未压缩） | 136.0 MB | 86.7 | 87.3 |
| test3 | UPX `--fast` | 75.9 MB | 476.1 | 476.5 |
| test3 | misa77 等级 1（推荐） | 77.6 MB | 149.3 | 150.1 |

| 测试 | 版本 | 文件大小 | 中位数（ms） | 平均值（ms） |
|---|---|---:|---:|---:|
| test4 | 原版（未压缩） | 22.7 MB | 30.4 | 43.1 |
| test4 | UPX `--fast` | 13.3 MB | 108.0 | 108.3 |
| test4 | misa77 等级 1（推荐） | 13.8 MB | 50.4 | 50.4 |

| 测试 | 版本 | 文件大小 | 中位数（ms） | 平均值（ms） |
|---|---|---:|---:|---:|
| test5 | 原版（未压缩） | 17.7 MB | 30.5 | 30.4 |
| test5 | UPX `--fast` | 13.2 MB | 92.5 | 92.3 |
| test5 | misa77 等级 1（推荐） | 13.3 MB | 61.1 | 59.0 |

| 测试 | 版本 | 文件大小 | 中位数（ms） | 平均值（ms） |
|---|---|---:|---:|---:|
| test6 | 原版（未压缩） | 6.4 MB | 228.5 | 242.8 |
| test6 | UPX `--fast` | 3.0 MB | 259.5 | 263.8 |
| test6 | misa77 等级 1（推荐） | 3.3 MB | 243.3 | 242.4 |

| 测试 | 版本 | 文件大小 | 中位数（ms） | 平均值（ms） |
|---|---|---:|---:|---:|
| test7 | 原版（未压缩） | 18.4 MB | 17.1 | 17.3 |
| test7 | UPX `--fast` | 10.7 MB | 91.7 | 92.4 |
| test7 | misa77 等级 1（推荐） | 11.3 MB | 34.9 | 34.8 |

### 使用方法

使用定制版 `upx.exe`，并在 `-1` 到 `4` 之间选择 misa77 等级：

```powershell
upx.exe --misa77-level=<等级> <软件路径>
```

例如，推荐的等级 1 用法：

```powershell
upx.exe --misa77-level=1 C:\test.exe
```

也可以使用 **UPXEx GUI（UPXEXGUI）**：支持拖放压缩、算法与等级选择、脱壳，以及 Windows 启动时间对比。后续将在 **Releases** 页面发布。

---

## Complete Test Data / 完整测试数据

The complete raw measurements are retained below.  
以下保留全部原始测试数据。

### test1

| File / 文件名 | File size / 文件大小 | Compression method / 压缩算法 | Median (ms) / 中位数 | Mean (ms) / 平均值 | Min (ms) / 最快 | Max (ms) / 最慢 |
|---|---|---|---|---|---|---|
| test1.exe | 29,503,488 B (28.1 MB) | Original (uncompressed) / 原版（未压缩） | 196.7 | 198.3 | 190.3 | 209.4 |
| test1defaultFast.exe | 15,450,112 B (14.7 MB) | UPX `--fast` | 315.5 | 317.1 | 309.8 | 333.4 |
| test1Misa77--1.exe | 18,434,048 B (17.6 MB) | misa77 level -1 / 等级 -1 | 227.7 | 227.5 | 215.9 | 235.3 |
| test1Misa77-0.exe | 17,641,472 B (16.8 MB) | misa77 level 0 / 等级 0 | 227.1 | 225.6 | 218.6 | 234.1 |
| test1Misa77-1.exe | 17,239,040 B (16.4 MB) | misa77 level 1 / 等级 1 | 223.6 | 224.2 | 219.5 | 229.9 |
| test1Misa77-2.exe | 16,439,296 B (15.7 MB) | misa77 level 2 / 等级 2 | 224.7 | 225.2 | 219.3 | 231.7 |
| test1Misa77-3.exe | 15,829,504 B (15.1 MB) | misa77 level 3 / 等级 3 | 225.8 | 226.1 | 219.9 | 232.7 |
| test1Misa77-4.exe | 15,245,312 B (14.5 MB) | misa77 level 4 / 等级 4 | 227.7 | 227.1 | 220.1 | 239.9 |

### test2

| File / 文件名 | File size / 文件大小 | Compression method / 压缩算法 | Median (ms) / 中位数 | Mean (ms) / 平均值 | Min (ms) / 最快 | Max (ms) / 最慢 |
|---|---|---|---|---|---|---|
| test2.exe | 64,822,272 B (61.8 MB) | Original (uncompressed) / 原版（未压缩） | 208.4 | 208.7 | 201.5 | 216.6 |
| test2defaultFast.exe | 31,978,496 B (30.5 MB) | UPX `--fast` | 450.5 | 451.9 | 443.1 | 462.0 |
| test2Misa77--1.exe | 38,468,608 B (36.7 MB) | misa77 level -1 / 等级 -1 | 265.6 | 266.4 | 260.8 | 270.1 |
| test2Misa77-0.exe | 36,748,288 B (35.0 MB) | misa77 level 0 / 等级 0 | 266.2 | 268.0 | 261.8 | 281.7 |
| test2Misa77-1.exe | 35,890,688 B (34.2 MB) | misa77 level 1 / 等级 1 | 269.3 | 268.7 | 255.9 | 281.4 |
| test2Misa77-2.exe | 34,360,832 B (32.8 MB) | misa77 level 2 / 等级 2 | 269.1 | 268.3 | 261.4 | 275.5 |
| test2Misa77-3.exe | 33,014,784 B (31.5 MB) | misa77 level 3 / 等级 3 | 264.0 | 265.5 | 260.3 | 275.4 |
| test2Misa77-4.exe | 31,529,984 B (30.1 MB) | misa77 level 4 / 等级 4 | 273.1 | 273.6 | 264.5 | 289.7 |

### test3

| File / 文件名 | File size / 文件大小 | Compression method / 压缩算法 | Median (ms) / 中位数 | Mean (ms) / 平均值 | Min (ms) / 最快 | Max (ms) / 最慢 |
|---|---|---|---|---|---|---|
| test3.exe | 142,639,616 B (136.0 MB) | Original (uncompressed) / 原版（未压缩） | 86.7 | 87.3 | 84.7 | 95.7 |
| test3defaultFast.exe | 79,564,288 B (75.9 MB) | UPX `--fast` | 476.1 | 476.5 | 468.0 | 487.1 |
| test3Misa77--1.exe | 86,403,072 B (82.4 MB) | misa77 level -1 / 等级 -1 | 150.5 | 151.2 | 147.7 | 159.9 |
| test3Misa77-0.exe | 83,384,832 B (79.5 MB) | misa77 level 0 / 等级 0 | 150.3 | 151.2 | 146.9 | 158.4 |
| test3Misa77-1.exe | 81,413,120 B (77.6 MB) | misa77 level 1 / 等级 1 | 149.3 | 150.1 | 145.5 | 158.3 |
| test3Misa77-2.exe | 78,155,264 B (74.5 MB) | misa77 level 2 / 等级 2 | 150.1 | 150.4 | 146.5 | 156.5 |
| test3Misa77-3.exe | 75,218,944 B (71.7 MB) | misa77 level 3 / 等级 3 | 151.0 | 150.9 | 147.8 | 156.5 |
| test3Misa77-4.exe | 73,704,448 B (70.3 MB) | misa77 level 4 / 等级 4 | 166.1 | 166.9 | 160.8 | 184.0 |

### test4

| File / 文件名 | File size / 文件大小 | Compression method / 压缩算法 | Median (ms) / 中位数 | Mean (ms) / 平均值 | Min (ms) / 最快 | Max (ms) / 最慢 |
|---|---|---|---|---|---|---|
| test4.exe | 23,813,632 B (22.7 MB) | Original (uncompressed) / 原版（未压缩） | 30.4 | 43.1 | 27.9 | 224.6 |
| test4defaultFast.exe | 13,950,976 B (13.3 MB) | UPX `--fast` | 108.0 | 108.3 | 105.5 | 111.5 |
| test4Misa77--1.exe | 15,245,312 B (14.5 MB) | misa77 level -1 / 等级 -1 | 50.9 | 50.8 | 48.6 | 54.6 |
| test4Misa77-0.exe | 14,775,808 B (14.1 MB) | misa77 level 0 / 等级 0 | 50.4 | 50.5 | 49.1 | 51.7 |
| test4Misa77-1.exe | 14,458,368 B (13.8 MB) | misa77 level 1 / 等级 1 | 50.4 | 50.4 | 47.7 | 54.4 |
| test4Misa77-2.exe | 13,802,496 B (13.2 MB) | misa77 level 2 / 等级 2 | 50.7 | 50.6 | 48.3 | 53.1 |
| test4Misa77-3.exe | 13,328,896 B (12.7 MB) | misa77 level 3 / 等级 3 | 51.2 | 60.8 | 49.0 | 192.3 |
| test4Misa77-4.exe | 13,131,776 B (12.5 MB) | misa77 level 4 / 等级 4 | 53.5 | 76.8 | 51.1 | 404.8 |

### test5

| File / 文件名 | File size / 文件大小 | Compression method / 压缩算法 | Median (ms) / 中位数 | Mean (ms) / 平均值 | Min (ms) / 最快 | Max (ms) / 最慢 |
|---|---|---|---|---|---|---|
| test5.exe | 18,540,544 B (17.7 MB) | Original (uncompressed) / 原版（未压缩） | 30.5 | 30.4 | 28.6 | 31.8 |
| test5defaultFast.exe | 13,883,904 B (13.2 MB) | UPX `--fast` | 92.5 | 92.3 | 90.5 | 93.6 |
| test5Misa77--1.exe | 14,308,352 B (13.6 MB) | misa77 level -1 / 等级 -1 | 61.6 | 57.7 | 31.0 | 62.7 |
| test5Misa77-0.exe | 14,043,136 B (13.4 MB) | misa77 level 0 / 等级 0 | 61.6 | 59.5 | 31.3 | 62.4 |
| test5Misa77-1.exe | 13,900,800 B (13.3 MB) | misa77 level 1 / 等级 1 | 61.1 | 59.0 | 31.5 | 62.2 |
| test5Misa77-2.exe | 13,381,632 B (12.8 MB) | misa77 level 2 / 等级 2 | 61.7 | 61.6 | 60.4 | 63.2 |
| test5Misa77-3.exe | 13,127,680 B (12.5 MB) | misa77 level 3 / 等级 3 | 61.1 | 61.2 | 59.0 | 62.7 |
| test5Misa77-4.exe | 12,973,568 B (12.4 MB) | misa77 level 4 / 等级 4 | 61.1 | 61.2 | 59.7 | 63.7 |

### test6

| File / 文件名 | File size / 文件大小 | Compression method / 压缩算法 | Median (ms) / 中位数 | Mean (ms) / 平均值 | Min (ms) / 最快 | Max (ms) / 最慢 |
|---|---|---|---|---|---|---|
| test6.exe | 6,701,568 B (6.4 MB) | Original (uncompressed) / 原版（未压缩） | 228.5 | 242.8 | 217.0 | 460.0 |
| test6defaultFast.exe | 3,118,080 B (3.0 MB) | UPX `--fast` | 259.5 | 263.8 | 254.0 | 284.8 |
| test6Misa77--1.exe | 3,654,656 B (3.5 MB) | misa77 level -1 / 等级 -1 | 243.2 | 245.4 | 241.0 | 258.1 |
| test6Misa77-0.exe | 3,492,864 B (3.3 MB) | misa77 level 0 / 等级 0 | 242.4 | 245.2 | 237.6 | 269.3 |
| test6Misa77-1.exe | 3,432,448 B (3.3 MB) | misa77 level 1 / 等级 1 | 243.3 | 242.4 | 233.4 | 255.4 |
| test6Misa77-2.exe | 3,266,048 B (3.1 MB) | misa77 level 2 / 等级 2 | 243.3 | 245.8 | 235.9 | 260.0 |
| test6Misa77-3.exe | 3,144,704 B (3.0 MB) | misa77 level 3 / 等级 3 | 244.3 | 247.4 | 237.7 | 260.6 |
| test6Misa77-4.exe | 3,130,368 B (3.0 MB) | misa77 level 4 / 等级 4 | 247.3 | 251.3 | 240.4 | 268.8 |

### test7

| File / 文件名 | File size / 文件大小 | Compression method / 压缩算法 | Median (ms) / 中位数 | Mean (ms) / 平均值 | Min (ms) / 最快 | Max (ms) / 最慢 |
|---|---|---|---|---|---|---|
| test7.exe | 19,246,592 B (18.4 MB) | Original (uncompressed) / 原版（未压缩） | 17.1 | 17.3 | 16.2 | 20.0 |
| test7defaultFast.exe | 11,252,224 B (10.7 MB) | UPX `--fast` | 91.7 | 92.4 | 89.9 | 97.3 |
| test7Misa77--1.exe | 12,676,608 B (12.1 MB) | misa77 level -1 / 等级 -1 | 35.8 | 36.1 | 34.3 | 39.6 |
| test7Misa77-0.exe | 12,034,048 B (11.5 MB) | misa77 level 0 / 等级 0 | 35.2 | 35.4 | 33.6 | 38.1 |
| test7Misa77-1.exe | 11,816,960 B (11.3 MB) | misa77 level 1 / 等级 1 | 34.9 | 34.8 | 33.2 | 37.8 |
| test7Misa77-2.exe | 11,163,648 B (10.6 MB) | misa77 level 2 / 等级 2 | 35.6 | 35.6 | 34.0 | 37.6 |
| test7Misa77-3.exe | 10,702,336 B (10.2 MB) | misa77 level 3 / 等级 3 | 35.8 | 35.9 | 33.7 | 38.7 |
| test7Misa77-4.exe | 10,768,896 B (10.3 MB) | misa77 level 4 / 等级 4 | 37.8 | 38.1 | 36.8 | 42.1 |
