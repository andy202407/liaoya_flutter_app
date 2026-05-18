# 洽聊 (QiaLiao) iOS 上架配置清单

## 进度追踪

| # | 项目 | 状态 | 备注 |
|---|------|------|------|
| 1 | Apple Developer 账号 | ✅ 已完成 | Team ID: `LQSSK5FMF9` |
| 2 | App ID 注册 | ✅ 已完成 | Bundle ID: `com.qialiao.app` |
| 3 | 开启 Push Notifications 能力 | ✅ 已完成 | 创建 App ID 时已勾选 |
| 4 | APNs Auth Key (.p8) | ✅ 已完成 | 复用已有 Key ID: `TQ6XKA5DHX` |
| 5 | 极光后台 iOS 推送配置 | ✅ 已完成 | 新 AppKey: `bdd50c89b81aa79f54fc5ffd` |
| 6 | Provisioning Profile | ⬜ 待完成 | Mac 上 Xcode 自动管理即可 |
| 7 | iOS 项目代码配置 | ✅ 已完成 | entitlements / Info.plist / AppDelegate / Bundle ID |
| 8 | App 图标 + 启动图 | ✅ 已完成 | 所有 iOS 尺寸已生成 |
| 9 | App Store 上架信息 | ⬜ 待完成 | 截图、描述、隐私政策等 |

---

## 详细说明

### 1. Apple Developer 账号
- 确认你有有效的 Apple Developer Program 会员资格（$99/年）
- 提供给我：**Team ID**（10位字母数字，Membership 页面可看到）

### 2. App ID 注册
- 登录 https://developer.apple.com/account
- Certificates, Identifiers & Profiles → Identifiers → 点 "+"
- 选 App IDs → App
- Bundle ID 填：`com.liaoya.liaoyaApp`
- Description 填：QiaLiao

### 3. 开启 Push Notifications
- 在刚创建的 App ID 配置页面
- Capabilities 列表中勾选 **Push Notifications**
- 保存

### 4. APNs Auth Key (.p8 文件)
- 如果和 liaoya_cs 共用同一个极光应用，可以复用已有的 Key（Key ID: `TQ6XKA5DHX`）
- 如果需要新建：Keys → 点 "+" → 勾选 Apple Push Notifications service (APNs) → 下载 .p8 文件
- ⚠️ .p8 文件只能下载一次，妥善保存
- 提供给我：**Key ID** 和 **Team ID**

### 5. 极光推送后台配置
- 登录 https://www.jiguang.cn/
- 当前 AppKey：`3d906a6c5cea9851c961db1d`
- 应用设置 → iOS → 上传 APNs Auth Key
- 填入：Key ID、Team ID、Bundle ID (`com.liaoya.liaoyaApp`)

### 6. Provisioning Profile
- Certificates, Identifiers & Profiles → Profiles → 点 "+"
- 类型选 iOS App Development（开发）或 App Store Distribution（发布）
- 选择上面创建的 App ID
- 选择证书和设备
- 下载 .mobileprovision 文件

### 7. iOS 项目代码配置（我来做）
等上面都完成后，我会帮你配置：
- `Runner.entitlements` — 添加 aps-environment
- `Info.plist` — 添加后台模式、权限描述
- `AppDelegate.swift` — 添加 prefs channel
- `project.pbxproj` — 签名配置

### 8. App 图标
- 需要 1024x1024 PNG 图标（无透明度）
- 参考 liaoya_cs 已有 `1024x1024ia.png`

### 9. App Store 上架（后续）
- App 名称、副标题
- 截图（6.7寸 + 5.5寸）
- 描述文字
- 隐私政策 URL
- 分类选择

---

## 操作顺序建议

先做 1 → 2 → 3 → 4 → 5，这些都是在网页上操作的。
每完成一个告诉我，我标记进度并告诉你下一步。
全部准备好后我帮你改代码配置（第7步）。
