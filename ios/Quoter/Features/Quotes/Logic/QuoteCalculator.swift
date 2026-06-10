import Foundation

struct QuoteCalculator {
    func preview(
        objects: [DrawingObject],
        annotations: [DrawingAnnotation],
        products: [QuoteProduct],
        prices: [QuotePrice],
        taxRate: Decimal,
        date: Date = Date()
    ) -> QuotePreview {
        var items: [QuoteItemPreview] = []
        var warnings: [UnboundQuoteWarning] = []
        let productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })

        for object in objects where object.isQuoteEnabled {
            guard let productID = object.productID ?? object.serviceID else {
                warnings.append(UnboundQuoteWarning(
                    sourceObjectID: object.id,
                    sourceEstimateItemID: nil,
                    objectType: object.objectType,
                    message: AppLanguage.localizedFormat(
                        "Unbound product object: %@",
                        AppLanguage.localizedKnownSystemString(object.objectType)
                    )
                ))
                continue
            }
            guard let product = productsByID[productID],
                  let price = prices
                    .filter({ $0.productID == productID && $0.isEffective(on: date) })
                    .sorted(by: { $0.effectiveFrom > $1.effectiveFrom })
                    .first else {
                warnings.append(UnboundQuoteWarning(
                    sourceObjectID: object.id,
                    sourceEstimateItemID: nil,
                    objectType: object.objectType,
                    message: AppLanguage.localizedFormat(
                        "Missing active price for %@",
                        AppLanguage.localizedKnownSystemString(object.objectType)
                    )
                ))
                continue
            }

            let notes = annotations
                .filter { $0.linkedObjectID == object.id }
                .map(\.text)
                .joined(separator: "\n")
            let lineTotal = round(price.unitPrice * object.quantity - object.discountAmount + object.installationFee)

            items.append(QuoteItemPreview(
                productID: productID,
                sourceObjectID: object.id,
                sourceKind: "drawing_object",
                productNameSnapshot: product.name,
                skuSnapshot: product.sku,
                brandSnapshot: product.brand,
                categorySnapshot: product.category,
                unitSnapshot: product.unit,
                unitPriceSnapshot: price.unitPrice,
                quantity: object.quantity,
                discountAmount: object.discountAmount,
                installationFee: object.installationFee,
                lineTotal: lineTotal,
                notesSnapshot: [object.notes, notes].filter { !$0.isEmpty }.joined(separator: "\n"),
                isContractVisible: object.isContractVisible,
                pricingStatus: "priced"
            ))
        }

        let subtotal = round(items.map(\.lineTotal).reduce(0, +))
        let discountTotal = round(items.map(\.discountAmount).reduce(0, +))
        let taxTotal = round(subtotal * taxRate)
        let total = round(subtotal + taxTotal)

        return QuotePreview(
            items: items,
            warnings: warnings,
            subtotal: subtotal,
            discountTotal: discountTotal,
            taxTotal: taxTotal,
            total: total
        )
    }

    private func round(_ value: Decimal) -> Decimal {
        DecimalFormatter.roundedMoney(value)
    }
}
