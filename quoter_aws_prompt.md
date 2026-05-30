# Quoter iPad App 完整开发提示词（AWS 自建后端版）

你是一名资深 **iOS / SwiftUI / AWS / PostgreSQL / SaaS 产品工程师**。请帮我从零开始设计并实现一个 **iPad 原生 App**，用于卫浴、厨房、全屋装修销售人员在客户现场手绘平面草图、绑定产品、自动生成报价单，并最终生成合同 PDF。

项目名称暂定为：**Quoter**

请严格按照下面的产品需求、技术架构、开发步骤和验收标准执行。不要只写 demo，要尽量按照可维护、可扩展、可上线的真实商业 App 结构来实现。

---

## 一、产品目标

我要做一个 **iOS / iPadOS App**，主要运行在 iPad 上。

核心场景：

1. 销售、设计师、总承包商拿 iPad 到客户现场。
2. 登录自己的账号。
3. 创建客户资料。
4. 创建一个项目，例如“张先生主卫翻新”。
5. 进入项目后，左侧是项目导航和项目资料，中间是画布，右侧是产品和属性面板。
6. 用户可以用 Apple Pencil 或手指在画布上自由手画厕所、浴室、厨房、全屋平面草图。
7. 用户可以自由画墙体、门、窗、柜子、洗手台、镜子、马桶、浴缸、灶台等常见装修内容，并在图上写文字、尺寸、备注、箭头、圈注。
8. 用户也可以从右侧产品菜单添加结构化产品对象，例如：
   - 浴室柜
   - 浴缸
   - 马桶
   - 花洒
   - 镜柜
   - 龙头
   - 瓷砖
   - 橱柜
   - 台面
   - 电器
   - 拆除服务
   - 安装服务
   - 防水服务
   - 电工服务
   - 水工服务
   - 以及其它可以自定义的内容
9. 每个产品对象可以放在画布上，并绑定数据库里的具体产品或服务，也可以在报价阶段临时添加数据库中没有的新产品或自定义服务项。
10. 用户选中某个产品对象后，右侧属性面板显示：
    - 对象类型
    - 产品分类
    - 品牌
    - 系列
    - SKU
    - 尺寸
    - 颜色
    - 材质
    - 单位
    - 数量
    - 单价
    - 备注
    - 是否参与报价
    - 是否显示在合同中
11. 点击“生成报价”后，App 根据已绑定的产品对象和服务对象生成统一报价表。
12. 用户确认报价后，可以点击“生成合同”。
13. 合同可以生成 PDF。
14. PDF 可以：
    - 在 App 内预览
    - 导出
    - 通过 iOS 分享面板发送
    - 未来可支持后端邮件发送

这个 App 的重点不是 CAD 精准制图，而是：

> **iPad 手绘草图 + 结构化产品选型 + 快速报价 + 合同生成**

---

## 二、核心设计原则

非常重要：**不要把用户每一笔手绘线条直接作为报价依据。**

必须采用“双图层 + 标注层 + 结构化对象层”的设计。

### 1. 手绘草图层 Drawing Layer

- 使用 PencilKit。
- 保存用户自由手画内容。
- 用于视觉表达、客户沟通、现场标注。
- 可以写文字、画箭头、圈出区域、手写尺寸。
- 不直接参与报价计算。
- 不直接作为合同数据来源。
- 可以在 PDF 中作为项目草图附件导出。

### 2. 标注层 Annotation Layer

用于高效标注和辅助理解手绘图，但仍然不直接作为报价唯一依据。

标注类型包括：

- 尺寸标注，例如 60 inch vanity、8 ft wall、12 x 24 tile。
- 区域标注，例如 shower area、vanity wall、backsplash area。
- 箭头标注，例如 “replace existing toilet”。
- 文本标注，例如 “customer wants matte black finish”。
- 施工说明，例如 “demo existing tub”。
- 问题标注，例如 “check plumbing location”。

每个标注对象应该有：

- `id`
- `project_id`
- `drawing_id`
- `annotation_type`
- `text`
- `x`
- `y`
- `width`
- `height`
- `rotation`
- `linked_object_id`
- `linked_product_id`
- `linked_quote_item_id`
- `created_by`
- `created_at`
- `updated_at`

标注可以关联到某个产品对象，也可以只是普通备注。

### 3. 产品对象层 Product Object Layer

这是报价和合同生成的核心数据来源。

每个对象必须保存结构化字段：

- `object_type`
- `product_id`
- `service_id`
- `category_id`
- `x`
- `y`
- `width`
- `height`
- `rotation`
- `quantity`
- `unit`
- `discount_amount`
- `installation_fee`
- `notes`
- `is_quote_enabled`
- `is_contract_visible`

报价单只根据 Product Object Layer 和手动添加的 Quote Item 生成。

这样可以保证：

- 用户仍然可以自由手画。
- 报价逻辑稳定。
- 合同数据准确。
- 后期可以扩展自动识别、尺寸计算、库存、ERP、AI 识别等功能。
- 标注可以辅助销售人员解释报价和合同条款。

---

## 三、重要限制：不要使用第三方 BaaS 平台

**不要使用 Supabase、Firebase、Appwrite、Parse、PocketBase、Hasura Cloud、PlanetScale、Neon、Railway、Render 等第三方 BaaS 或托管后端平台。**

本项目后端必须基于 **AWS 直接部署自建服务和数据库**。

允许使用 AWS 官方服务，例如：

- Amazon EC2
- Amazon ECS / Fargate
- Amazon RDS for PostgreSQL
- Amazon S3
- Amazon CloudFront
- AWS Application Load Balancer
- AWS Secrets Manager
- AWS CloudWatch
- AWS IAM
- AWS VPC
- AWS WAF
- Amazon SES（未来用于邮件发送）
- AWS Backup

认证系统要求：

- 不使用 Supabase Auth。
- 不使用 Firebase Auth。
- 第一版优先实现自建邮箱密码登录。
- 密码必须使用安全哈希，例如 Argon2id 或 bcrypt。
- 后端签发 Access Token / Refresh Token。
- Access Token 使用 JWT。
- Refresh Token 需要可撤销、可轮换、可失效。
- iOS 端使用 Keychain 保存 token。
- 不要把数据库密码、JWT secret、AWS secret 写死在客户端。

---

## 四、推荐技术架构

### iPad App

- Swift
- SwiftUI
- PencilKit
- PDFKit
- UIKit bridging where needed
- SwiftData 或本地 Codable 文件缓存，用于本地草稿
- async/await
- MVVM 或 Clean Architecture 风格
- 支持 iPad 横屏优先
- 支持 Apple Pencil 和手指输入
- 支持离线草稿
- 支持网络恢复后同步

### 后端 API

可以选择以下任一后端技术，但需要保持结构清晰：

- Go + Gin / Fiber
- Node.js + NestJS
- Kotlin + Ktor
- Swift Vapor

推荐使用：

- **Go + Gin**
- PostgreSQL
- SQL migrations
- JWT auth
- REST API 第一版
- OpenAPI 文档
- Docker
- ECS/Fargate 或 EC2 部署

### 数据库

- Amazon RDS for PostgreSQL
- PostgreSQL migrations
- 所有业务表必须有 `company_id`
- 使用数据库事务保证报价和合同生成一致性
- 重要数据需要历史快照
- 第一版可以使用软删除或状态字段，不要硬删除核心业务数据

### 文件存储

- Amazon S3
- 存储内容：
  - PencilKit drawing binary 文件
  - drawing preview image
  - quote PDF
  - contract PDF
  - 产品图片
  - 公司 logo
- iOS 客户端不要直接持有 AWS Secret。
- 文件上传下载通过后端签发 pre-signed URL。
- S3 bucket 不能公开写入。
- CloudFront 可用于读取产品图片和 PDF 预览附件。

---

## 五、App 模块

请实现以下模块。

### 1. Auth 模块

- 登录
- 注册
- 退出登录
- 当前用户 session 管理
- Access Token 自动刷新
- Refresh Token 轮换
- 失败提示
- 加载状态
- Keychain 安全保存 token
- 不需要 OAuth

### 2. Customer 模块

客户列表、新建客户、编辑客户。

客户字段：

- `name`
- `phone`
- `email`
- `address`
- `notes`

### 3. Project 模块

项目列表、新建项目、编辑项目。

项目字段：

- `title`
- `customer_id`
- `room_type`
- `status`
- `created_at`
- `updated_at`

### 4. Drawing 模块

- iPad 画布
- PencilKit 手绘
- 保存 PKDrawing 数据
- 加载历史 PKDrawing
- 生成预览图片
- 画布上显示产品对象
- 画布上显示标注对象
- 支持添加产品对象
- 支持选择产品对象
- 支持移动产品对象
- 支持删除产品对象
- 支持旋转产品对象
- 支持缩放产品对象
- 支持复制产品对象
- 支持网格背景
- 支持对象吸附到网格
- 支持撤销/重做的基础结构

### 5. Product Catalog 模块

- 品牌列表
- 产品分类
- 产品列表
- 根据分类、品牌、关键词筛选产品
- 支持服务类 item，例如安装费、拆除费、防水、电工、水工
- 产品字段：
  - `brand`
  - `category`
  - `name`
  - `sku`
  - `size`
  - `color`
  - `material`
  - `unit`
  - `description`
  - `image_url`
  - `active`

### 6. Product Object Inspector 模块

选中画布上的产品对象后，在右侧显示属性面板。

需要支持：

- 绑定产品
- 更换产品
- 修改数量
- 修改单位
- 修改尺寸
- 修改备注
- 修改折扣
- 修改安装费
- 设置是否参与报价
- 设置是否显示在合同
- 修改后实时更新报价预览
- 显示未绑定状态提醒

### 7. Annotation Inspector 模块

选中标注对象后，在右侧显示标注属性。

需要支持：

- 修改标注文本
- 修改标注类型
- 绑定到某个产品对象
- 绑定到某个 quote item
- 设置是否导出到 PDF
- 设置是否显示在合同附件草图中

### 8. Quote 模块

根据 drawing_objects 生成报价单。

报价单包含：

- `quote_number`
- `customer`
- `project`
- `quote_items`
- `subtotal`
- `discount_total`
- `tax`
- `total`

报价 item 必须保存价格快照，不要只保存 `product_id`。

必须保存：

- `product_name_snapshot`
- `sku_snapshot`
- `brand_snapshot`
- `category_snapshot`
- `unit_snapshot`
- `unit_price_snapshot`
- `quantity`
- `discount_amount`
- `installation_fee`
- `line_total`
- `source_object_id`
- `notes_snapshot`

### 9. Contract 模块

从已确认 quote 生成合同。

合同包含：

- 公司信息
- 客户信息
- 项目信息
- 报价明细
- 总金额
- 付款条款
- 施工/交付条款
- 免责声明
- 签名区域
- 日期
- 附件：现场草图和关键标注

需要生成 PDF，并支持：

- App 内预览
- 本地导出
- iOS Share Sheet 分享
- 后续通过后端邮件发送

### 10. Settings / Admin Stub 模块

- 当前用户资料
- 公司信息
- 税率设置
- 退出登录
- 预留产品管理入口
- 预留用户角色管理入口
- 预留报价模板管理入口
- 预留合同条款模板入口

---

## 六、画布交互与标注匹配要求

这是本项目非常重要的部分。请重点实现“画图交互高效、标注清晰、产品匹配准确、报价合同联动稳定”。

### 1. 画布总体交互

`DrawingWorkspaceView` 应该是 iPad 横屏优先布局。

左侧：

- 返回项目
- 客户/项目信息
- 保存按钮
- 图层开关
- 草图附件入口

中间：

- PencilKit 画布
- 产品对象 overlay
- 标注对象 overlay
- 可缩放/可平移
- 第一版可以先不做无限画布
- 背景可选网格
- 支持 Apple Pencil 优先输入
- 支持双指缩放/平移
- 支持对象拖拽时临时禁用 PencilKit 绘制，避免误画

右侧：

- 添加产品按钮
- 产品分类
- 产品搜索
- 常用产品快捷入口
- 产品对象属性面板
- 标注属性面板
- 报价预览小计
- 生成报价按钮

### 2. 高效添加对象

请实现以下方式，让销售现场操作足够快：

- 右侧产品分类点击后，直接进入产品列表。
- 常用对象提供快捷按钮，例如 Vanity、Toilet、Shower、Tub、Tile、Demo、Install。
- 支持拖拽产品到画布。
- 支持点击画布中心自动添加。
- 支持复制上一个产品对象。
- 支持最近使用产品列表。
- 支持常用服务包，例如 “Bathroom Basic Install Package”。

### 3. 对象选择与编辑

产品对象显示方式：

- 初期可以用简单的矩形、圆角矩形、图标、文字标签表示。
- 对象上显示产品名、SKU 或对象类型。
- 未绑定产品的对象需要明显显示 “Unbound” 或 “未绑定产品”。
- 选中状态要有边框和控制点。
- 支持拖动改变位置。
- 支持缩放改变 width/height。
- 支持旋转。
- 支持删除。
- 支持复制。
- 支持绑定具体产品。
- 支持打开产品详情。
- 支持从对象直接跳到对应 quote item。

### 4. 标注对象

标注对象不是自由手绘，而是结构化 overlay。

支持：

- 文本标注
- 尺寸标注
- 箭头标注
- 区域框选
- 圆圈标注
- 编号标注，例如 A1、A2、B1
- 施工备注
- 客户偏好备注

每个标注都可以：

- 独立保存
- 绑定产品对象
- 绑定产品
- 绑定 quote item
- 导出到 PDF 草图附件
- 在合同中作为备注显示或隐藏

### 5. 产品匹配与数据库联动

当用户画完或添加对象后，需要便于匹配数据库内容。

请实现以下匹配方式：

#### 手动匹配

- 用户选中对象后，右侧点击“绑定产品”。
- 支持按分类、品牌、SKU、关键词搜索。
- 支持最近使用产品。
- 支持收藏产品。
- 支持只显示 active 产品。
- 支持只显示当前公司产品。
- 支持绑定服务类 item，例如安装、拆除、防水。

#### 半自动推荐

第一版不要求 AI 识别手绘，但需要预留推荐机制：

- 根据 `object_type` 推荐同类产品。
- 根据项目 `room_type` 推荐常用产品。
- 根据标注文本关键词推荐产品，例如标注里写了 “60 inch vanity”，则推荐 Vanity 分类里 size 接近 60 inch 的产品。
- 根据历史报价中常用搭配推荐产品。
- 根据对象尺寸推荐匹配产品。
- 根据 SKU 或品牌关键词快速定位产品。

请实现一个独立的 `ProductMatcher`，第一版使用规则匹配即可。

输入：

- drawing_object
- annotations
- product_catalog
- project_context
- recent_products

输出：

- recommended_products
- match_reason
- confidence_score

示例：

```text
object_type = vanity
annotation text = "60 inch white vanity"
推荐：
1. SKU VAN-60-WHITE-001
原因：分类匹配 vanity，尺寸匹配 60 inch，颜色匹配 white
confidence_score = 0.86
```

### 6. 标注和报价联动

需要支持从图到报价、从报价回到图。

- 点击画布对象，可以看到对应 quote item。
- 点击报价 item，可以高亮画布上的对象。
- 点击合同预览中的某个 item，未来可以定位到画布对象。
- 如果一个对象未绑定产品，报价预览必须显示“未绑定产品对象”，不能静默忽略。
- 如果标注绑定了对象，quote item 备注中可以自动带入该标注。
- 如果对象绑定了多个标注，报价 item 需要显示可展开的备注列表。

### 7. 坐标设计

所有 overlay 对象坐标必须使用相对坐标：

- `x`
- `y`
- `width`
- `height`

取值范围使用 `0.0` 到 `1.0`。

不要使用固定像素作为数据库坐标。

这样不同 iPad 屏幕尺寸、横竖屏、导出 PDF 时都能保持比例。

### 8. PencilKit 数据保存

- 使用 `PKDrawing.dataRepresentation()` 保存二进制文件。
- 上传到 S3。
- 本地可缓存。
- 同时生成 preview image 上传到 S3。
- 后端返回 S3 object key，不要让 iOS 客户端直接保存 AWS secret。
- iOS 端上传可以通过后端签发 pre-signed URL 完成。

---

## 七、数据库设计

请写出完整 PostgreSQL migration 文件，不要只写伪代码。

数据库使用：

- Amazon RDS for PostgreSQL
- PostgreSQL schema migrations
- 所有业务表必须有 `company_id`
- 自建 auth tables
- 自建 role / permission 结构
- 重要业务数据使用快照
- 核心删除优先用 `status` 或 `deleted_at`

必须包含以下表：

- `companies`
- `users`
- `user_sessions`
- `customers`
- `projects`
- `drawings`
- `drawing_objects`
- `drawing_annotations`
- `brands`
- `product_categories`
- `products`
- `product_prices`
- `quotes`
- `quote_items`
- `contracts`
- `contract_templates`
- `file_assets`
- `audit_logs`

### 权限要求

后端 API 必须强制校验：

- 用户只能访问自己 `company_id` 下的数据。
- 管理员可以管理本公司产品、价格、用户。
- sales / designer 可以创建客户、项目、报价、合同。
- 所有业务表必须有 `company_id`。
- 每个 API 查询都必须带 company scope。
- 不要依赖客户端传来的 company_id 作为最终可信来源。
- company_id 必须从 JWT/session 中解析出来。
- 重要写操作记录 audit log。

如果使用 PostgreSQL Row Level Security，也需要同时在 API 层做权限校验。不要只依赖前端隐藏按钮。

---

## 八、后端 API 要求

请实现 REST API 第一版。

### Auth API

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `GET /api/v1/auth/me`

### Customer API

- `GET /api/v1/customers`
- `POST /api/v1/customers`
- `GET /api/v1/customers/:id`
- `PUT /api/v1/customers/:id`
- `DELETE /api/v1/customers/:id`

### Project API

- `GET /api/v1/projects`
- `POST /api/v1/projects`
- `GET /api/v1/projects/:id`
- `PUT /api/v1/projects/:id`
- `DELETE /api/v1/projects/:id`

### Drawing API

- `GET /api/v1/projects/:projectId/drawing`
- `PUT /api/v1/projects/:projectId/drawing`
- `POST /api/v1/projects/:projectId/drawing/upload-url`
- `POST /api/v1/drawing-objects`
- `PUT /api/v1/drawing-objects/:id`
- `DELETE /api/v1/drawing-objects/:id`
- `POST /api/v1/drawing-annotations`
- `PUT /api/v1/drawing-annotations/:id`
- `DELETE /api/v1/drawing-annotations/:id`

### Product API

- `GET /api/v1/products`
- `GET /api/v1/products/:id`
- `GET /api/v1/product-categories`
- `GET /api/v1/brands`
- `GET /api/v1/products/recommendations`

### Quote API

- `POST /api/v1/projects/:projectId/quotes/preview`
- `POST /api/v1/projects/:projectId/quotes`
- `GET /api/v1/quotes/:id`
- `POST /api/v1/quotes/:id/confirm`

### Contract API

- `POST /api/v1/quotes/:quoteId/contracts`
- `GET /api/v1/contracts/:id`
- `POST /api/v1/contracts/:id/pdf`
- `GET /api/v1/contracts/:id/download-url`

---

## 九、iOS 项目结构要求

请使用清晰的模块化目录结构，例如：

```text
Quoter/
  App/
    QuoterApp.swift
    AppState.swift
    AppRouter.swift

  Core/
    API/
      APIClient.swift
      APIError.swift
      AuthInterceptor.swift
    Auth/
      TokenStore.swift
      SessionManager.swift
    Storage/
      LocalDraftStore.swift
      KeychainStore.swift
    Models/
      Money.swift
      PaginatedResponse.swift
    Utils/
      DecimalFormatter.swift
      DateFormatterProvider.swift

  Features/
    Auth/
      Views/
      ViewModels/
      Services/
      Models/

    Customers/
      Views/
      ViewModels/
      Services/
      Models/

    Projects/
      Views/
      ViewModels/
      Services/
      Models/

    Drawing/
      Views/
      ViewModels/
      Services/
      Models/
      Components/
        PencilCanvasView.swift
        ProductObjectOverlayView.swift
        AnnotationOverlayView.swift
        CanvasGridView.swift
        ObjectControlHandlesView.swift
      Logic/
        CanvasCoordinateMapper.swift
        ProductMatcher.swift

    Products/
      Views/
      ViewModels/
      Services/
      Models/

    Quotes/
      Views/
      ViewModels/
      Services/
      Models/
      Logic/
        QuoteCalculator.swift

    Contracts/
      Views/
      ViewModels/
      Services/
      Models/
      PDF/
        PDFGenerator.swift
        PDFPreviewView.swift
        ShareSheet.swift

    Settings/
      Views/
      ViewModels/

  Resources/
    Assets.xcassets
    Config/
      Debug.xcconfig
      Release.xcconfig

  Tests/
    QuoteCalculatorTests.swift
    ProductMatcherTests.swift
    CoordinateMapperTests.swift
```

---

## 十、报价计算规则

报价计算请实现为独立 `QuoteCalculator`。

输入：

- drawing_objects
- annotations
- products
- product_prices
- tax_rate

规则：

1. 每个 drawing_object 如果绑定了 product_id 或 service_id，并且 `is_quote_enabled = true`，则生成一条 quote_item。
2. 使用当前有效价格：
   - `effective_from <= today`
   - `effective_to is null` 或 `effective_to >= today`
3. `line_total = unit_price * quantity - discount_amount + installation_fee`
4. `subtotal = 所有 line_total 之和`
5. `discount_total = 所有 discount_amount 之和`
6. `tax_total = subtotal * tax_rate`
7. `total = subtotal + tax_total`
8. 所有金额保留 2 位小数。
9. 金额使用 Decimal，不要用 Double 做最终金额计算。
10. `quote_items` 必须保存产品快照，不允许只依赖 product_id。
11. 如果某个对象没有绑定产品，报价预览中要提示“未绑定产品”，但不能静默忽略。
12. 如果标注绑定了对象，标注内容可以进入 quote item 备注快照。
13. 如果对象设置 `is_contract_visible = false`，报价仍可显示，但合同生成时可以隐藏或作为内部备注处理。

请写单元测试覆盖：

- 单个产品报价
- 多个产品报价
- 折扣
- 安装费
- 税率
- 未绑定产品对象
- 历史价格快照
- 标注备注进入 quote item
- 不参与报价对象不生成 quote item
- Decimal 精度

---

## 十一、ProductMatcher 要求

请实现独立 `ProductMatcher`，用于产品推荐和对象匹配。

### 输入

- `DrawingObject`
- `[DrawingAnnotation]`
- `[Product]`
- `[ProductPrice]`
- `ProjectContext`
- `[RecentProduct]`

### 输出

- `[ProductMatchResult]`

字段：

- `product`
- `score`
- `reasons`
- `matched_keywords`
- `matched_size`
- `matched_color`
- `matched_category`

### 匹配规则

第一版使用规则匹配，不需要 AI。

需要支持：

1. object_type 与 product category 匹配。
2. annotation text 中的关键词匹配产品 name、sku、brand、category。
3. annotation text 中的尺寸解析，例如：
   - `60 inch`
   - `60"`
   - `5 ft`
   - `12 x 24`
4. annotation text 中的颜色解析，例如：
   - white
   - black
   - matte black
   - chrome
   - brushed nickel
5. room_type 推荐常用分类。
6. recent_products 加权。
7. active 产品优先。
8. 有有效价格的产品优先。

### 示例输出

```text
推荐产品：VAN-60-WHITE-001
score: 0.86
原因：
- object_type vanity 匹配产品分类 Vanity
- 标注文字包含 60 inch
- 产品尺寸匹配 60 inch
- 标注文字包含 white
- 产品颜色匹配 white
```

---

## 十二、PDF 合同生成要求

第一版可以在 iPad 本地生成 PDF，也可以预留后端生成 PDF 的接口。

请实现 `PDFGenerator`，能够生成：

1. 报价 PDF
2. 合同 PDF

### 报价 PDF 内容

- 公司名称
- 公司 logo
- 客户信息
- 项目信息
- 报价编号
- 日期
- 产品明细表
- 小计
- 折扣
- 税
- 总计
- 备注
- 现场草图预览图，可选

### 合同 PDF 内容

- 合同编号
- 公司信息
- 客户信息
- 项目信息
- 产品/服务明细
- 总金额
- 付款条款
- 施工/交付条款
- 免责声明
- 客户签名区域
- 公司签名区域
- 日期
- 附件：现场草图 + 关键标注

PDF 生成后：

- 保存本地临时文件。
- 可以用 PDFKit 预览。
- 可以通过 ShareLink 或 UIActivityViewController 分享。
- 合同 PDF 文件信息需要保存到后端 `file_assets` 和 `contracts` 表中。
- PDF 需要保留报价快照，不能因为之后产品价格变化导致旧合同内容变化。

---

## 十三、UI / UX 风格

请使用 SwiftUI 现代 iPad 风格。

设计要求：

- 简洁专业
- 类似销售工具 / 设计工具
- iPad 横屏体验优先
- 右侧 Inspector 风格
- 左侧项目导航稳定
- 中间画布尽量大
- 按钮清晰
- 金额显示醒目
- 危险操作需要确认，例如删除项目、删除对象
- 表单要有校验
- 加载状态不能空白
- 网络错误要显示用户可理解的错误信息
- 离线状态要显示清楚
- 保存状态要显示，例如 Saving、Saved、Failed

主要页面流程：

未登录：

- `LoginView`
- `RegisterView`

登录后：

- `ProjectListView`
- `CustomerListView`
- `ProjectDetailView`
- `DrawingWorkspaceView`
- `QuotePreviewView`
- `ContractPreviewView`
- `SettingsView`

---

## 十四、权限与安全

请遵守：

1. 不要在客户端硬编码数据库密码、JWT secret、AWS secret。
2. iOS 客户端只能访问后端 API。
3. iOS 客户端上传文件必须使用后端签发的 pre-signed URL。
4. 所有敏感权限由后端 API 控制。
5. 用户只能访问自己 `company_id` 的数据。
6. 报价和合同要保存历史快照。
7. 删除数据优先软删除或状态取消，第一版可以先用 status 控制。
8. 不要在日志里输出密码、token、密钥。
9. 配置使用 `.xcconfig` 或环境配置文件。
10. README 中说明如何配置 API Base URL。
11. 后端配置使用环境变量或 AWS Secrets Manager。
12. 密码使用 Argon2id 或 bcrypt。
13. Refresh Token 需要存储 hash，不要明文保存。
14. 重要业务操作写入 audit log。
15. API 需要做输入校验和错误处理。

---

## 十五、AWS 部署要求

请提供 AWS 部署方案和相关配置说明。

### 推荐部署方式

第一版可以使用：

- Backend API：ECS Fargate 或 EC2 + Docker
- Database：RDS PostgreSQL
- File Storage：S3
- CDN：CloudFront
- Load Balancer：Application Load Balancer
- Secrets：AWS Secrets Manager
- Logs：CloudWatch Logs
- Metrics：CloudWatch
- Network：VPC + private subnet for RDS
- Backup：RDS automated backups + S3 versioning

### README 必须说明

- 如何创建 RDS PostgreSQL
- 如何配置数据库连接字符串
- 如何运行 migrations
- 如何创建 S3 bucket
- 如何配置 S3 CORS
- 如何配置后端环境变量
- 如何本地运行后端
- 如何用 Docker 构建后端
- 如何部署到 ECS/Fargate 或 EC2
- 如何配置 iOS 的 API Base URL
- 如何查看 CloudWatch 日志

---

## 十六、开发步骤

请按照以下顺序实现，不要一上来就写所有复杂功能。

### 阶段 1：项目骨架

- 创建 SwiftUI iPad App
- 建立目录结构
- 添加 APIClient
- 添加基础 AppState / Router
- 添加 Keychain TokenStore
- 添加 README

### 阶段 2：后端骨架

- 创建后端项目
- 创建 Dockerfile
- 创建环境配置
- 创建 health check API
- 创建数据库连接
- 创建 migration runner
- 写 README

### 阶段 3：数据库

- 写 PostgreSQL migrations
- 写 seed demo data
- 写 companies / users / customers / projects 基础表
- 写权限相关字段
- 提供运行说明

### 阶段 4：Auth

- 注册
- 登录
- 登出
- session restore
- token refresh
- Keychain 保存
- 错误处理

### 阶段 5：客户和项目

- CRUD customers
- CRUD projects
- 项目详情页

### 阶段 6：画布

- PencilKit 画布
- 保存/加载 PKDrawing
- 生成 preview image
- S3 pre-signed URL 上传
- 产品对象 overlay
- 标注对象 overlay
- 添加/选择/移动/删除对象

### 阶段 7：产品目录

- 产品列表
- 产品选择器
- 绑定产品到 drawing object
- 属性面板
- ProductMatcher 第一版规则匹配

### 阶段 8：报价

- QuoteCalculator
- QuotePreviewView
- 生成 quote 和 quote_items
- 保存价格快照
- 标注备注进入 quote item
- 单元测试

### 阶段 9：合同和 PDF

- PDFGenerator
- ContractPreviewView
- PDFPreviewView
- Share Sheet
- 合同 PDF 保存记录

### 阶段 10：打磨

- 错误处理
- 空状态
- 加载状态
- iPad 横屏布局优化
- 离线草稿
- 测试
- README 完善

---

## 十七、代码质量要求

请遵守：

- Swift 代码要可编译。
- 后端代码要可运行。
- 不要写大量无法运行的伪代码。
- ViewModel 使用 `@MainActor`。
- 网络请求使用 async/await。
- Model 遵守 Codable、Identifiable。
- 金额使用 Decimal，不要用 Double 做最终金额计算。
- View 文件不要过大，复杂 UI 拆成子 View。
- 业务计算逻辑不要放在 View 里。
- QuoteCalculator 必须可单元测试。
- ProductMatcher 必须可单元测试。
- PDFGenerator 必须独立。
- API 查询封装在 Service 层。
- 后端数据库操作必须使用 repository/service 分层。
- 后端每个 API 必须做 company scope 校验。
- 每完成一个阶段，请运行测试或说明无法运行的原因。
- 如果环境缺少依赖，请明确指出并提供安装步骤。
- 不要静默吞掉错误。
- 不要把 AWS secret、JWT secret、数据库密码写入仓库。

---

## 十八、需要生成的交付物

请输出并实现：

1. SwiftUI iPad App 源码
2. 自建后端 API 源码
3. PostgreSQL SQL migrations
4. Demo seed data
5. Dockerfile / docker-compose for local development
6. QuoteCalculator
7. ProductMatcher
8. PDFGenerator
9. PencilKit Canvas wrapper
10. Product Object overlay system
11. Annotation overlay system
12. Auth / Customer / Project / Product / Quote / Contract 基础页面
13. 单元测试
14. README
15. AWS 部署说明

README 必须包含：

- 项目介绍
- 功能列表
- 技术栈
- 数据库 migration 运行方式
- 后端本地运行方式
- AWS 部署方式
- S3 配置方式
- iOS 配置方式
- 如何配置环境变量
- 如何运行 App
- 如何在 Windows 上写代码，然后把项目放到 Mac / Xcode 上运行到 iPad
- 是否直接复制文件、用 GitHub 同步、还是用 Git clone
- 如何运行测试
- 已完成内容
- 未完成/后续计划

---

## 十九、验收标准

最终项目至少要满足：

1. 可以注册/登录。
2. 登录后可以创建客户。
3. 可以创建项目。
4. 可以进入项目画布。
5. 可以用 PencilKit 手绘。
6. 可以保存并重新打开画布。
7. 可以添加产品对象到画布。
8. 可以添加结构化标注到画布。
9. 可以给产品对象绑定数据库产品。
10. 可以根据对象类型和标注文本推荐产品。
11. 可以修改数量、折扣、安装费。
12. 可以生成报价预览。
13. 报价金额计算正确。
14. quote_items 保存价格快照。
15. 未绑定产品对象会在报价预览中明确提示。
16. 可以从报价 item 高亮对应画布对象。
17. 可以确认报价。
18. 可以生成合同 PDF。
19. 合同 PDF 可以包含草图附件和关键标注。
20. 可以预览 PDF。
21. 可以通过 iOS 分享面板分享 PDF。
22. 后端强制 company_id 权限隔离。
23. 用户只能看到自己 company_id 的数据。
24. 关键计算有单元测试。
25. ProductMatcher 有单元测试。
26. README 清楚说明如何本地运行和部署到 AWS。

---

## 二十、当前任务

请先检查当前仓库。

如果当前仓库是空的：

- 请创建完整项目骨架。
- 先完成阶段 1、阶段 2、阶段 3、阶段 4 的可运行版本。
- 然后列出接下来阶段 5-10 的 TODO。

如果当前仓库已经有代码：

- 请先阅读项目结构。
- 不要破坏现有代码。
- 按现有风格集成。
- 优先补齐缺失模块。
- 给出清晰的变更摘要。

请优先保证：

1. iPad App 项目结构清晰。
2. 自建 AWS 后端方向正确，不要引入 Supabase/Firebase 这种第三方 BaaS。
3. 画布对象、标注对象、产品数据库、报价 item、合同 PDF 之间的数据链路清楚。
4. 画图交互要高效，不能让销售现场操作很慢。
5. 报价和合同必须基于结构化对象和价格快照，而不是直接基于随手画的线条。
