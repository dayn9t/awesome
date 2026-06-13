# awesome-j: Custom Awesome WM

基于 awesome WM master 分支 (v4.3-1739-gc104846a) 的个人定制版本。

## 与原版的区别

### 1. Tag 颜色分组（核心功能）

为每个 tag 提供独立的颜色分组，支持 7 种颜色循环切换。

**快捷键**：`Ctrl+Shift+Z`（在 Xephyr 嵌套环境中使用，避免 Mod4 被宿主 WM 拦截）

**颜色定义**（`awesomerc.lua` 中 `tag_colors` 表）：

```lua
local tag_colors = {
    [0] = nil,  -- 无覆盖，使用主题默认色
    [1] = { focus = "#e74c3c", normal = "#743c3c", fg = "#fff0f0" },  -- red
    [2] = { focus = "#e67e22", normal = "#74583c", fg = "#fff3ea" },  -- orange
    [3] = { focus = "#f1c40f", normal = "#756a3c", fg = "#fffff0" },  -- yellow
    [4] = { focus = "#2ecc71", normal = "#3c7551", fg = "#f0fff5" },  -- green
    [5] = { focus = "#1abc9c", normal = "#3c655e", fg = "#f0fffb" },  -- teal
    [6] = { focus = "#3498db", normal = "#3c5875", fg = "#f0f5ff" },  -- blue
    [7] = { focus = "#9b59b6", normal = "#5a3c75", fg = "#f5f0ff" },  -- purple
}
```

每个颜色组包含三个属性：
- **focus**：tag 被选中时的背景色（高亮）
- **normal**：tag 未被选中时的背景色（暗色调）
- **fg**：tag 文字的前景色（接近白色的浅色调）

**实现原理**：包装 `awful.widget.common.list_update`，在默认渲染完成后重新应用 per-tag 颜色到 `cache.bgb`（背景）和 `cache.bgb:set_fg`（前景）。

**修改颜色**：编辑 `awesomerc.lua` 中的 `tag_colors` 表。每组颜色的 focus/normal/fg 均为标准十六进制色值。

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

## 文件结构

```
~/cc/sys/awesome/
├── awesomerc.lua                    # 主配置文件（本项目的核心产出）
├── build/awesome                    # 编译后的二进制
├── lib/                             # Lua 库（master 分支）
├── themes/default/
│   ├── theme.lua                    # 主题配置
│   ├── black_flower.png             # 壁纸图片
│   └── ...
├── docs/awesome-j.md                # 本文档
└── test_nested.sh                   # Xephyr 嵌套测试脚本

~/bin/awesome-j                      # 启动脚本（GDM 入口）
/usr/share/xsessions/awesome-j.desktop  # GDM 会话文件
```

## 与系统 awesome 共存

awesome-j 与系统 apt 安装的 awesome v4.3 完全隔离：

| 组件 | 系统 awesome (v4.3) | awesome-j (master) |
|------|---------------------|---------------------|
| 二进制 | `/usr/bin/awesome` | `~/cc/sys/awesome/build/awesome` |
| 配置 | `~/.config/awesome/rc.lua` | `~/cc/sys/awesome/awesomerc.lua` |
| 库 | `/usr/share/awesome/lib/` | `~/cc/sys/awesome/lib/` |
| 主题 | `/usr/share/awesome/themes/` | `~/cc/sys/awesome/themes/` |
| GDM 会话 | `awesome` | `awesome-j` |

GDM 登录界面的会话选择器中可切换两者。

## 测试

### Xephyr 嵌套测试

```bash
# 启动嵌套 X 会话
Xephyr :1 -ac -br -screen 1280x720 &
DISPLAY=:1 ~/cc/sys/awesome/build/awesome \
    -c ~/cc/sys/awesome/awesomerc.lua \
    -s ~/cc/sys/awesome/lib &
```

注意：在 Xephyr 中 Mod4（Win 键）被宿主 WM 拦截，因此颜色循环快捷键使用 `Ctrl+Shift+Z`。

### xdotool 自动化测试

```bash
# 测试颜色循环
DISPLAY=:1 xdotool key ctrl+shift+z
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
