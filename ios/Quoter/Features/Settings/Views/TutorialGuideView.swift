import SwiftUI

struct TutorialGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: AppLocalization
    @State private var page = 0

    private var steps: [TutorialStep] {
        TutorialStep.steps(for: localization.language)
    }

    var body: some View {
        VStack(spacing: 18) {
            ProgressView(value: Double(page + 1), total: Double(max(steps.count, 1)))
                .animation(.easeInOut(duration: 0.2), value: page)

            TabView(selection: $page) {
                ForEach(steps.indices, id: \.self) { index in
                    TutorialStepCard(step: steps[index])
                        .tag(index)
                        .padding(.horizontal, 8)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack {
                Button(copy.back) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        page = max(0, page - 1)
                    }
                }
                .disabled(page == 0)

                Spacer()

                Text("\(page + 1)/\(steps.count)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)

                Spacer()

                Button(page == steps.count - 1 ? copy.done : copy.next) {
                    if page == steps.count - 1 {
                        dismiss()
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            page = min(steps.count - 1, page + 1)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .navigationTitle(copy.title)
        .onChange(of: localization.language) { _, _ in
            page = 0
        }
    }

    private var copy: TutorialCopy {
        TutorialCopy(language: localization.language)
    }
}

private struct TutorialStepCard: View {
    let step: TutorialStep

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: step.systemImage)
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 8) {
                Text(step.title)
                    .font(.title2.weight(.semibold))
                Text(step.summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(step.bullets, id: \.self) { bullet in
                    Label {
                        Text(bullet)
                    } icon: {
                        Image(systemName: "checkmark.circle")
                    }
                    .font(.callout)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct TutorialCopy {
    let title: String
    let back: String
    let next: String
    let done: String

    init(language: AppLanguage) {
        switch language {
        case .simplifiedChinese:
            title = "新手指引"
            back = "上一步"
            next = "下一步"
            done = "完成"
        case .english, .french, .italian:
            title = "Getting Started"
            back = "Back"
            next = "Next"
            done = "Done"
        }
    }
}

private struct TutorialStep: Identifiable {
    let id: String
    let systemImage: String
    let title: String
    let summary: String
    let bullets: [String]

    static func steps(for language: AppLanguage) -> [TutorialStep] {
        switch language {
        case .simplifiedChinese:
            return chineseSteps
        case .english, .french, .italian:
            return englishSteps
        }
    }

    private static let englishSteps: [TutorialStep] = [
        TutorialStep(
            id: "customer",
            systemImage: "person.crop.rectangle.stack",
            title: "1. Create the customer",
            summary: "Start with the person or company you are quoting for.",
            bullets: [
                "Add name, phone, email, address, and notes.",
                "This makes the later project, quote, contract, and email flow unambiguous."
            ]
        ),
        TutorialStep(
            id: "project",
            systemImage: "folder.badge.plus",
            title: "2. Confirm project basics",
            summary: "Every project should have a customer, title, service area, and status before drawing.",
            bullets: [
                "Use service areas such as kitchen, bathroom, flooring, or whole home.",
                "Keep the project title specific enough to recognize on quotes and contracts."
            ]
        ),
        TutorialStep(
            id: "drawing",
            systemImage: "pencil.and.outline",
            title: "3. Draw and place objects",
            summary: "Use the canvas for the field sketch, then add structured objects on top.",
            bullets: [
                "Drawing strokes explain the layout.",
                "Objects are what become quote lines, so keep them positioned near the matching sketch item."
            ]
        ),
        TutorialStep(
            id: "binding",
            systemImage: "shippingbox.and.arrow.backward",
            title: "4. Bind each object to a product",
            summary: "Select an object, open the Inspector, choose category, brand, product, quantity, and install fee.",
            bullets: [
                "Quote Readiness shows how many quote-enabled objects are still unbound.",
                "Resolve unbound objects before creating a quote."
            ]
        ),
        TutorialStep(
            id: "quote",
            systemImage: "list.bullet.rectangle.portrait",
            title: "5. Preview and create the quote",
            summary: "The quote preview calculates items from the drawing objects and shows warnings.",
            bullets: [
                "Review subtotal, discount, tax, and total.",
                "Create and confirm the quote once the warnings are acceptable."
            ]
        ),
        TutorialStep(
            id: "contract",
            systemImage: "doc.richtext",
            title: "6. Export and email",
            summary: "Create a contract from a confirmed quote, generate the PDF, then share or email it.",
            bullets: [
                "PDFs use system fonts that support English and Chinese text.",
                "Enter the recipient once and use Email PDF to open a ready-to-send message."
            ]
        )
    ]

    private static let chineseSteps: [TutorialStep] = [
        TutorialStep(
            id: "customer",
            systemImage: "person.crop.rectangle.stack",
            title: "1. 创建客户",
            summary: "先确定这份报价是给谁的，避免后面的项目、合同和邮件混在一起。",
            bullets: [
                "填写姓名、电话、邮箱、地址和备注。",
                "客户信息会贯穿项目、报价、合同和 PDF 发送流程。"
            ]
        ),
        TutorialStep(
            id: "project",
            systemImage: "folder.badge.plus",
            title: "2. 确认项目基本信息",
            summary: "进入画图前，每个项目都应该有客户、标题、服务区域和状态。",
            bullets: [
                "服务区域可以选择厨房、浴室、地板、整屋等。",
                "项目标题要具体，方便在报价和合同里识别。"
            ]
        ),
        TutorialStep(
            id: "drawing",
            systemImage: "pencil.and.outline",
            title: "3. 画草图并放置对象",
            summary: "画笔负责解释现场布局，结构化对象负责生成报价明细。",
            bullets: [
                "草图用来表达位置和施工关系。",
                "对象要放在对应的草图项目旁边，后续产品绑定才不容易出错。"
            ]
        ),
        TutorialStep(
            id: "binding",
            systemImage: "shippingbox.and.arrow.backward",
            title: "4. 把对象绑定到产品",
            summary: "选择对象，在右侧检查器里设置分类、品牌、产品、数量和安装费。",
            bullets: [
                "报价准备度会显示还有多少可报价对象没有绑定产品。",
                "创建报价前，先处理所有未绑定对象。"
            ]
        ),
        TutorialStep(
            id: "quote",
            systemImage: "list.bullet.rectangle.portrait",
            title: "5. 预览并创建报价",
            summary: "报价预览会从画图对象计算明细，并显示需要处理的警告。",
            bullets: [
                "检查小计、折扣、税费和总价。",
                "确认警告可接受后，再创建并确认报价。"
            ]
        ),
        TutorialStep(
            id: "contract",
            systemImage: "doc.richtext",
            title: "6. 导出并发送",
            summary: "从已确认报价创建合同，生成 PDF，然后分享或发送邮件。",
            bullets: [
                "PDF 使用支持中英文的系统字体。",
                "输入收件人后，用“邮件发送 PDF”打开可直接发送的邮件。"
            ]
        )
    ]
}
