# awesome-j: Custom Awesome WM

基于 awesome WM master 分支 (v4.3-1739-gc104846a) 的个人定制版本。

## 与原版的区别

### 1. Tag 颜色分组（核心功能）

为每个 tag 提供独立的**类别色**：7 色相 × 明/暗两档 = **14 个类别色**。颜色只表达标签
类别，**不表达激活状态**——激活指示由 taglist 上的白色实心方块承担（2026-09-25 改造，
将颜色与激活状态解耦）。

**快捷键**（均作用于当前聚焦的 tag，在 Xephyr 嵌套环境中使用，避免 Mod4 被宿主 WM 拦截）：
- `Ctrl+Shift+Z`：循环色相（none → red → orange → … → purple → none）
- `Ctrl+Shift+X`：切换明/暗档（与 Z 键紧邻成对，左手原地操作）

**颜色定义**（`awesomerc.lua` 中 `tag_colors` 表）：

```lua
local tag_colors = {
    [0] = nil,  -- 无覆盖，使用主题默认色（无明暗维度）
    [1] = { bright = "#e74c3c", dim = "#743c3c", fg = "#fff0f0" },  -- red
    [2] = { bright = "#e67e22", dim = "#74583c", fg = "#fff3ea" },  -- orange
    [3] = { bright = "#f1c40f", dim = "#756a3c", fg = "#fffff0" },  -- yellow
    [4] = { bright = "#2ecc71", dim = "#3c7551", fg = "#f0fff5" },  -- green
    [5] = { bright = "#1abc9c", dim = "#3c655e", fg = "#f0fffb" },  -- teal
    [6] = { bright = "#3498db", dim = "#3c5875", fg = "#f0f5ff" },  -- blue
    [7] = { bright = "#9b59b6", dim = "#5a3c75", fg = "#f5f0ff" },  -- purple
}
```

每个颜色组包含三个属性：
- **bright**：亮档背景色（类别默认档）
- **dim**：暗档背景色（同一色相的低亮度版）
- **fg**：tag 文字的前景色（明暗两档共用，接近白色的浅色调）

**激活方块**（`themes/default/theme.lua`）：taglist 方块尺寸 `dpi(5)`（原 4px；8px 过大，
取 2/3 ≈ 5px，~82dpi HDMI 面板实际渲染 4px 已接受），选中色为纯白 `#ffffff`，未选中保持
暗色空心轮廓；明暗两态共用同一画布尺寸，切换 tag 时 taglist 布局不抖动（2026-09-23）。

**实现原理**：包装 `awful.widget.common.list_update`，在默认渲染完成后按 `t.color_index`
（色相）与 `t.color_bright`（明暗，默认亮档）重新应用 per-tag 颜色到 `cache.bgb`。颜色属性
为运行时状态，重启后复位。

**修改颜色**：编辑 `awesomerc.lua` 中的 `tag_colors` 表。每组颜色的 bright/dim/fg 均为标准十六进制色值。

### 2. 30 个 Tag

从原版 9 个 tag 扩展到 30 个，使用数字 + 字母 + F 键的组合：

| 序号 | 1-9 | 10-18 | 19-27 | 28-30 |
|------|-----|-------|-------|-------|
| 显示 | 1-9 | a b d e g i v y z | F1-F9 | F10-F12 |
| 按键 | #10-#18 (数字键) | 字母键 | F1-F9 | F10-F12 |

每个 tag 绑定四组快捷键：
- `Mod4 + key`：跳转到该 tag
- `Mod4 + Ctrl + key`：切换该 tag 的显示
- `Mod4 + Shift + key`：将当前窗口移动到该 tag
- `Mod4 + Ctrl + Shift + key`：切换当前窗口在该 tag 的显示

### 3. 壁纸

使用 `gears.wallpaper.maximized()` 拉伸填充屏幕，壁纸文件位于项目内：
```
themes/default/black_flower.png
```

屏幕分辨率变化时自动重新设置（`property::geometry` 信号）。

### 4. 终端与编辑器

- 终端：`xfce4-terminal`（原版为 `xterm`）
- 编辑器：`$EDITOR` 环境变量，fallback 为 `editor`（原版为 `nano`）

### 5. 布局

精简布局列表，禁用了以下布局：
- floating、spiral、spiral.dwindle、max.fullscreen、magnifier、corner.*

保留的布局：
- tile、tile.left、tile.bottom、tile.top、fair、fair.horizontal、max

### 6. 标题栏

全局关闭标题栏（`titlebars_enabled = false`）。

### 7. 菜单

集成 debian 菜单和 freedesktop 菜单（需要 `awesome-extra` 包）。优先使用 freedesktop 菜单，不可用时回退到 debian 菜单。

### 8. 其他

- Sloppy focus：鼠标移入窗口自动聚焦
- 边框颜色：焦点切换时改变边框色（`beautiful.border_focus` / `border_normal`）
- 窗口管理：防止屏幕数量变化后窗口不可达
- Debug 日志：输出到 `/tmp/awesome_debug.log`

## 部署（源码树 ≠ 部署树）

部署产物安装到 FHS 标准位 `/opt/awesome-j`（2026-10-25 自 ~/opt 迁入，配置移 `/etc/xdg/awesome-j/rc.lua`），**不引用源码仓库路径**——源码树搬迁/改名不影响部署（2026-09-27 改造；起源：仓库从 `~/cc/sys/awesome` 迁到 `~/cc/accel/awesome/awesome` 后 GDM 会话启动失败）。

### 重新部署（源码改动 → 上线）

```bash
cd ~/cc/accel/awesome/awesome
cmake -S . -B build-release -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/opt/awesome-j \
    -DLUA_EXECUTABLE=/usr/bin/lua5.3 -DLUA_INCLUDE_DIR=/usr/include/lua5.3 -DLUA_LIBRARY=/usr/lib/x86_64-linux-gnu/liblua5.3.so \
    -DLUA_EXECUTABLE=/usr/bin/lua5.3 \
    -DLUA_INCLUDE_DIR=/usr/include/lua5.3 \
    -DLUA_LIBRARY=/usr/lib/x86_64-linux-gnu/liblua5.3.so \
    -DGENERATE_DOC=OFF -DGENERATE_MANPAGES=OFF
cmake --build build-release --parallel $(nproc)
cmake --install build-release
```

- **Lua 钉 5.3**：系统 lgi（lua-lgi deb）仅装了 5.3 版本，awesome 运行时硬依赖 lgi；`/usr/bin/lua` 现已指向 5.4，不显式钉住会链到 5.4 导致运行时找不到 lgi。
- 主题/壁纸路径统一走 `gears.filesystem.get_themes_dir()`（跟随二进制编译期 prefix），源码与部署产物均无硬编码绝对路径。
- 统一发布纪律：改动落在源码仓，集中 `cmake --install` 一次上线，不逐改动在线更新。

## 文件结构

```
~/cc/accel/awesome/awesome/          # 源码仓库（可自由搬迁）
├── awesomerc.lua                    # 主配置文件（本项目的核心产出，安装时生成到部署树）
├── build-release/                   # Release 构建目录（deploy 用）
├── lib/                             # Lua 库（master 分支）
├── themes/default/
│   ├── theme.lua                    # 主题配置
│   ├── black_flower.png             # 壁纸图片
│   └── ...
└── docs/awesome-j.md                # 本文档

/opt/awesome-j/                      # 部署树（FHS 标准位，稳定）
├── bin/awesome                      # 二进制
├── etc/xdg/awesome/rc.lua           # 安装版配置
└── share/awesome/{lib,themes,icons} # Lua 库 / 主题 / 图标

~/bin/awesome-j                      # 启动脚本（GDM 入口，指向部署树）
/usr/share/xsessions/awesome-j.desktop  # GDM 会话文件
```

## 与系统 awesome 共存

awesome-j 与系统 apt 安装的 awesome v4.3 完全隔离：

| 组件 | 系统 awesome (v4.3) | awesome-j (master) |
|------|---------------------|---------------------|
| 二进制 | `/usr/bin/awesome` | `/opt/awesome-j/bin/awesome` |
| 配置 | `~/.config/awesome/rc.lua` | `~/.config/awesome-j/rc.lua`（个人 XDG 区，经 /usr/local/bin/awesome-j 启动器 -c 指定） |
| 库 | `/usr/share/awesome/lib/` | `/opt/awesome-j/share/awesome/lib/` |
| 主题 | `/usr/share/awesome/themes/` | `/opt/awesome-j/share/awesome/themes/`（前缀编译进二进制，改前缀需重建） |
| GDM 会话 | `awesome` | `awesome-j` |

GDM 登录界面的会话选择器中可切换两者。

## 测试

### Xephyr 嵌套测试（直接走正式启动脚本）

```bash
Xephyr :2 -ac -br -screen 1280x720 &
DISPLAY=:2 ~/bin/awesome-j &
```

注意：在 Xephyr 中 Mod4（Win 键）被宿主 WM 拦截，因此颜色循环快捷键使用 `Ctrl+Shift+Z`。

### xdotool 自动化测试

```bash
# 测试色相循环
DISPLAY=:2 xdotool key ctrl+shift+z
# 测试明暗切换
DISPLAY=:2 xdotool key ctrl+shift+x
```

## 配置修改指南

### 修改 tag 颜色

编辑 `awesomerc.lua` 中的 `tag_colors` 表，修改对应色组的 focus/normal/fg 值。颜色格式为 `#RRGGBB`。

### 修改 tag 数量

1. 修改 `win_num` 变量
2. 在 `win_keys` 和 `win_tags` 中增删对应条目
3. 快捷键循环自动适配

### 切换壁纸

将新壁纸放入 `themes/default/` 目录，然后修改 `request::wallpaper` 信号中的路径。

### Debug 日志

```bash
tail -f /tmp/awesome_debug.log
```
