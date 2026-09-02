# 上架合规改造清单（2026-09-03）

| # | 项目 | 状态 | 说明 |
|---|---|---|---|
| 1 | 账号删除（5.1.1v） | ✅ | `/api/delete_account` + 设置→注销账号（二次确认，删除资料/动态/聊天/会话） |
| 2 | 隐私政策 | ✅ | 站内「设置→隐私政策」内嵌页 + `https://tianruo.top/privacy.html`（商店政策 URL） |
| 3 | 用户协议 | ✅ | 站内页 + `https://tianruo.top/terms.html` |
| 4 | 审核账号 | ✅ | 330 / 902 白名单直登（DEV_MODE），备注模板见 APP_REVIEW_NOTES.md |
| 5 | 举报渠道 | ✅ | 站内举报已有 + 新增 `/api/report` 落库、`/api/admin/reports` 管理端查看 |
| 6 | 封禁能力 | ✅ | `/api/admin/ban` + 全局封禁中间件 + WS 断连（4003） |
| 7 | 敏感词过滤 | ✅ | 服务端 filterText：昵称/动态/评论/房间消息/私聊（约炮/裸聊等词库可扩展） |
| 8 | 年龄限制（17+） | ✅ | `/api/register_phone` 强制 age≥17；政策/协议注明；App 分级 17+ |
| 9 | 开发者联系 | ✅ | support@tianruo.top（站内 + 政策页 + 健康接口 review.contact） |
| 10 | IPv6 | ⚠️ 建议 | 服务器纯 IPv4（域名有 A 记录，NAT64 下可访问）；建议后续 Cloudflare/开通 IPv6 降低白屏风险 |
| 11 | 内购（3.1.1） | 未触发 | 无充值/打赏；后续加虚拟物品必须走 Apple IAP |
| 12 | Sign in with Apple | 未触发 | 仅手机号登录；后续加微信/QQ 登录须同时提供 Apple 登录 |
| 13 | ICP 备案（国区） | 待办 | 中国大陆区上架须在开发者后台提交 ICP 备案号 |
| 14 | App 图标/截图 | 待办 | 需 1024×1024 无透明图标 + 6.9″/6.5″/5.5″ 截图后上传商店 |

## 改动文件（服务器 /opt/wenrouxiang）

- `server.js`：+filterText/BANNED_WORDS、+封禁中间件、+/api/report、+/api/admin/reports、
  +/api/admin/ban、+/api/delete_account、+注册年龄门控、+/api/health 增加 review 信息
- `public/index.html`：设置→「合规与支持」区块（隐私/协议/联系/注销）、Legal 模块、s-legal 页面
- `public/privacy.html`、`public/terms.html`：独立政策页面（新增）
- 备份：`server.js.bak.compliance-*`、`index.html.bak.compliance-*`（/opt/wenrouxiang 下）
