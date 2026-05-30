# Quoter

Quoter 是一个 iPad 优先的装修现场报价 App 骨架：销售人员在 iPad 上手绘草图，叠加结构化产品对象和标注，后续由这些结构化对象生成报价、合同和 PDF。当前仓库按需求先完成阶段 1-4：SwiftUI iPad App 骨架、Go/Gin 自建后端、PostgreSQL migrations、Docker 本地环境、自建邮箱密码注册/登录。

## 已完成

- `ios/Quoter.xcodeproj`：SwiftUI iPad App，包含 Auth、AppState、Router、APIClient、Keychain TokenStore、SessionManager。
- iOS 模块目录：Customers、Projects、Drawing、Products、Quotes、Contracts、Settings。
- Drawing 基础骨架：PencilKit wrapper、网格、产品对象 overlay、标注 overlay、相对坐标 mapper。
- Quote/PDF 基础骨架：`QuoteCalculator`、`ProductMatcher`、`PDFGenerator` 独立文件。
- `backend/`：Go + Gin API，PostgreSQL 连接、migration runner、JWT access token、可轮换 refresh token。
- 数据库：完整 `0001_init.sql`，包含 companies、users、sessions、customers、projects、drawings、drawing_objects、drawing_annotations、products、prices、quotes、contracts、files、audit_logs。
- Docker：`docker-compose.yml` 可启动 PostgreSQL 和 API。

## 未完成 / TODO 阶段 5-10

- 阶段 5：Customer / Project CRUD API 与 SwiftUI 页面接入。
- 阶段 6：真实保存/加载 PencilKit drawing，S3 pre-signed upload URL，拖拽/缩放/旋转对象。
- 阶段 7：Product Catalog API、产品选择器、绑定产品、规则推荐接口。
- 阶段 8：后端 quote preview/create/confirm，保存 quote_items 价格快照，补 Swift 单元测试。
- 阶段 9：合同 API、PDF 上传记录、合同 PDF 完整模板。
- 阶段 10：离线草稿同步、错误/空状态打磨、iPad 横屏体验优化、更多测试。

## 本地后端运行

在 Windows PowerShell 的仓库根目录运行：

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

后端环境变量参考：`backend/.env.example`。生产环境必须替换 `JWT_SECRET`、`DATABASE_URL`，不要把真实 AWS secret 写进仓库。

## 数据库 migration / seed

API 容器设置了 `RUN_MIGRATIONS=true`，启动时会自动执行 `backend/migrations/*.sql`。新公司通过注册创建时，会自动 seed 一份 demo catalog。

如需手动导入 `backend/seeds/001_demo_catalog.sql`，连接 PostgreSQL 后运行：

```powershell
docker compose exec -T postgres psql -U postgres -d quoter -f /path/in/container
```

更简单的方式是直接注册新账号，让 API 自动创建公司和 demo 产品目录。

## iOS 在 Mac / Xcode 运行

1. 把整个仓库同步到 Mac，推荐用 GitHub：
   ```bash
   git clone <your-repo-url>
   cd iosapp
   ```
2. 安装 Xcode 16 或更新版本。
3. 打开：
   ```bash
   open ios/Quoter.xcodeproj
   ```
4. 在 Xcode 里选择 `Quoter` target，设置你的 Apple Team。
5. 如果跑 iPad 模拟器，`ios/Quoter/Resources/Config/Debug.xcconfig` 默认可以用：
   ```text
   API_BASE_URL = http:/$()/127.0.0.1:8080/api/v1
   ```
6. 如果跑真机 iPad，不能用 `127.0.0.1`。把它改成 Mac 或 Windows 的局域网 IP，例如：
   ```text
   API_BASE_URL = http:/$()/192.168.1.50:8080/api/v1
   ```
7. 确保 iPad 和运行 Docker 后端的电脑在同一 Wi-Fi，Windows 防火墙允许 8080 入站。
8. 在 Xcode 选择你的 iPad，点击 Run。打开 App 后注册账号即可连自建后端。

## Windows 写代码，Mac 部署到 iPad

推荐流程：

1. Windows 上写 Go 后端、SQL、README，也可以编辑 Swift 文件。
2. 用 GitHub 同步代码，不建议手动复制单个文件，容易漏掉 `.xcodeproj` 和配置。
3. Mac 上 `git pull` 后打开 Xcode。
4. 后端可以继续跑在 Windows Docker，也可以在 Mac 上跑 `docker compose up --build`。
5. iPad 真机访问哪台电脑的后端，就把 `Debug.xcconfig` 的 `API_BASE_URL` 改成哪台电脑的局域网 IP。

如果临时不用 Git，也可以直接复制整个 `iosapp` 文件夹到 Mac，但不要只复制 `ios/`，因为 Docker、README、backend migrations 都在根目录。

## AWS 部署方向

第一版推荐：

- API：ECS Fargate 或 EC2 + Docker。
- DB：Amazon RDS PostgreSQL，放 private subnet。
- 文件：S3 存 PencilKit drawing、preview image、quote PDF、contract PDF、产品图片、logo。
- 读取加速：CloudFront。
- Secrets：AWS Secrets Manager 存 `DATABASE_URL`、`JWT_SECRET`、S3 bucket 配置。
- 日志：CloudWatch Logs。
- 网络：Application Load Balancer + HTTPS。

部署要点：

- RDS 开启自动备份。
- S3 bucket 禁止公开写入。
- S3 CORS 只允许需要的方法和域名。
- iOS 不保存 AWS secret，只请求后端签发 pre-signed URL。
- 后端所有查询必须从 JWT/session 解析 `company_id`，不能信任客户端传来的 `company_id`。

## 测试

后端单元测试：

```powershell
$env:GOCACHE='D:\aaaaaaaaaaaaaReno mumu\iosapp\.gocache'
$env:GOPATH='D:\aaaaaaaaaaaaaReno mumu\iosapp\.gopath'
$env:GOMODCACHE='D:\aaaaaaaaaaaaaReno mumu\iosapp\.gopath\pkg\mod'
cd backend
go test ./...
```

iOS 当前需要在 Mac 上用 Xcode 编译验证。Windows 不能编译 iOS 原生 App，这是 Apple 工具链限制。

## 项目结构

```text
backend/
  cmd/api
  internal/config
  internal/domain/auth
  internal/httpserver
  internal/platform
  migrations
  seeds
ios/
  Quoter.xcodeproj
  Quoter/
    App
    Core
    Features
    Resources
```
