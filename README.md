# 相机水印 · CameraWatermark

系统相机拍照保存时，自动在照片底部合成水印。

- 左侧：机型（自动识别）、日期时间
- 右侧：苹果 Logo、分隔线、焦距 / 光圈 / 快门 / ISO、经纬度
- 样式：底部圆角半透明信息条（按效果图还原）

只注入 `com.apple.camera`，第三方 App 保存的照片不受影响。

## 安装

Sileo 添加源：

```
https://gh-proxy.com/https://raw.githubusercontent.com/darenni86-svg/CameraWatermark/main/docs/
```

刷新后搜索「相机水印」安装，Respring，然后把相机从后台划掉重开。

## 说明

- 水印在照片写入相册前合成，相册里就是成片
- 只处理最大边 ≥ 1600 像素的照片，缩略图不处理
- 经纬度来自照片 EXIF，相机没开定位时这一行会留空
- 关闭水印：编辑 `/var/mobile/Library/Preferences/com.dsh.camerawatermark.plist`，把 `Enabled` 设为 `false`
