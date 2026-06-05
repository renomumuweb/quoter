# 产品、材料和报价 Template 使用说明

## 在哪里输入产品和材料

在 iOS App 里进入 `Products` 页面维护 catalog：

1. 点右上角 `Add`。
2. 先按需要创建 `New Category`，例如 Vanity、Tile、Flooring、Install Service。
3. 可选创建 `New Brand`。
4. 创建 `New Product`，填写：
   - `Category`：产品或服务所属分类。
   - `Brand`：品牌，没有品牌可以选 No Brand。
   - `Name`：产品名称。
   - `SKU`：唯一编码，后期用来识别同名不同材料/规格的产品。
   - `Unit`：each、sq ft、ln ft、job 等。
   - `Current Price`：当前单价，会自动带入 template item 的 Material Cost。
   - `Attributes > Material`：材料名称，例如 porcelain、quartz、painted plywood cabinet / ceramic top。
   - `Size`、`Color`、`Description`：有就补，后期搜索和识别会更准。

如果同一个产品有不同材料或规格，建议建成多个产品记录，并用不同 SKU 区分，例如：

- `TILE-1224-POR-WHT`：12 x 24 porcelain tile，Material = porcelain。
- `TILE-1224-CER-GRY`：12 x 24 ceramic tile，Material = ceramic。

## 在报价 Template 里面怎么用

进入某个 Project 后打开 `Estimate Template`：

1. 选择一个 renovation type，或从 saved template 创建。
2. 在某个 category 里点 `Add Item`。
3. 在编辑窗口顶部的 `Catalog Product` 下拉菜单选择产品。
4. 选择后系统会自动补齐：
   - item name
   - description
   - unit
   - material cost
   - product id
   - product name / SKU / brand / category / material / unit price 快照
5. 保存 template 时，后端会重新校验 `product_id` 必须属于当前公司 catalog，并刷新产品快照字段，避免 template 关联到错误产品。

你仍然可以保留手动 item：`Catalog Product` 选择 `Custom Item`，然后自己输入名称、单位和成本。

## 后端关联规则

Template 的 category 和 item 仍然存放在 `estimate_templates.categories` JSON 里。现在 item 可以带这些 catalog 关联字段：

- `product_id`
- `product_name_snapshot`
- `sku_snapshot`
- `brand_snapshot`
- `product_category_snapshot`
- `material_snapshot`
- `unit_price_snapshot`

保存或更新 template 时：

- 如果 item 没有 `product_id`，按普通手动 item 保存。
- 如果 item 有 `product_id`，后端会确认该产品属于当前公司，且未被删除。
- 后端会用 catalog 当前数据补齐产品名称、SKU、品牌、分类、材料、单位和价格快照。
- 如果 item 的名称、单位、描述或材料成本为空，会用产品数据自动补上。

## 后期补充产品的建议

以后慢慢补 catalog 时，优先保证这几个字段完整：

1. Category
2. Product Name
3. SKU
4. Material
5. Unit
6. Current Price

这样在 template 里用下拉菜单选择时，产品和材料会自然对应，报价 item 也能自动带出正确成本。
