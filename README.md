# Quoter

Quoter 是一个 iPad 优先的装修现场报价 App：销售或设计人员可以在 iPad 上创建客户、项目、手绘草图、结构化产品对象和标注，然后生成报价与合同 PDF 记录。后端使用自建 Go/Gin API、PostgreSQL、JWT/refresh token，不依赖 Supabase/Firebase 等 BaaS。

## 当前完成状态

- Auth：注册、登录、刷新 token、退出登录、Keychain token 保存。
- Customer CRUD：客户列表、新建、编辑、软删除，后端按 `company_id` 隔离。
- Project CRUD：项目列表、新建、编辑、软删除，新建项目时自动准备 drawing 记录。
- Drawing CRUD：项目画布加载/保存，drawing objects 与 annotations 可新增、编辑、删除。
- Product Catalog CRUD：品牌、分类、产品列表/搜索/新增/编辑/软删除，产品价格快照来源为 `product_prices`。
- Product recommendations：后端规则推荐接口与 Swift `ProductMatcher` 本地规则逻辑。
- Quote：按 drawing objects 生成预览，未绑定对象明确 warning，创建 quote 时写入 `quote_items` 价格快照，支持确认 quote。
- Contract：从 quote 创建 contract，登记 PDF file asset，iOS 本地生成/预览/分享合同 PDF。
- Files：开发期提供后端本地 `uploads/` 上传入口，同时保留 S3 object key 模型，后续可替换为真正 S3 pre-signed URL。
- 数据库：`0001_init.sql` 包含核心业务表、company scope 字段和索引。
- Docker：根目录 `docker-compose.yml` 可启动 PostgreSQL 与 API。

## 本地后端运行

```powershell
docker compose up --build
```

API 地址：

```text
http://localhost:8080/api/v1
```

健康检查：

```powershell
Invoke-RestMethod http://localhost:8080/healthz
Invoke-RestMethod http://localhost:8080/readyz
```

注册示例：

```powershell
Invoke-RestMethod -Method Post http://localhost:8080/api/v1/auth/register `
  -ContentType "application/json" `
  -Body '{"company_name":"Reno Demo","name":"Owner","email":"owner@example.com","password":"Password123!"}'
```

## 主要 API

- `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`, `GET /auth/me`
- `/customers`：`GET`, `POST`; `/customers/:id`：`GET`, `PUT`, `DELETE`
- `/projects`：`GET`, `POST`; `/projects/:id`：`GET`, `PUT`, `DELETE`
- `/projects/:id/drawing`：`GET`, `PUT`
- `/drawing-objects`：`POST`; `/drawing-objects/:id`：`PUT`, `DELETE`
- `/drawing-annotations`：`POST`; `/drawing-annotations/:id`：`PUT`, `DELETE`
- `/file-assets/:id/upload`：开发期本地上传; `/file-assets/:id/download`：开发期本地下载
- `/brands`, `/product-categories`, `/products`：列表、新增、编辑、删除
- `GET /products/recommendations`
- `POST /projects/:id/quotes/preview`, `POST /projects/:id/quotes`, `GET /quotes`, `GET /quotes/:id`, `POST /quotes/:id/confirm`
- `GET /contracts`, `POST /quotes/:id/contracts`, `GET /contracts/:id`, `POST /contracts/:id/pdf`

## iOS 运行

1. 在 Mac 上安装 Xcode 16 或更新版本。
2. 打开 `ios/Quoter.xcodeproj`。
3. 设置 `Quoter` target 的 Apple Team。
4. iPad 模拟器可使用 `ios/Quoter/Resources/Config/Debug.xcconfig` 默认 API：

```text
API_BASE_URL = http:/$()/127.0.0.1:8080/api/v1
```

真机 iPad 不能访问电脑自己的 `127.0.0.1`。请改成运行 Docker 后端电脑的局域网 IP，例如：

```text
API_BASE_URL = http:/$()/192.168.1.50:8080/api/v1
```

## 测试

Windows 当前环境可运行后端测试：

```powershell
$env:GOCACHE='D:\aaaaaaaaaaaaaReno mumu\iosapp\.gocache'
$env:GOPATH='D:\aaaaaaaaaaaaaReno mumu\iosapp\.gopath'
$env:GOMODCACHE='D:\aaaaaaaaaaaaaReno mumu\iosapp\.gopath\pkg\mod'
cd backend
go test ./...
```

iOS 原生编译需要在 Mac/Xcode 上验证；Windows 环境不能编译 iPadOS target。

## AWS 部署方向

生产版建议：

- API：ECS Fargate 或 EC2 + Docker。
- DB：Amazon RDS PostgreSQL，放 private subnet。
- 文件：Amazon S3 存储 drawing binary、preview image、quote PDF、contract PDF、产品图片、logo。
- 读取加速：CloudFront。
- Secrets：AWS Secrets Manager 保存 `DATABASE_URL`、`JWT_SECRET`、S3 bucket 配置。
- 日志：CloudWatch Logs。
- 网络：Application Load Balancer + HTTPS。

当前代码已保留 `file_assets.bucket/object_key` 与 upload-url 接口形状；切到 AWS 时，把开发期本地 upload handler 替换为 S3 pre-signed URL 签发即可。
