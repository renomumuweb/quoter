import Foundation

struct ProductMatchResult: Identifiable, Hashable {
    var id: UUID { product.id }
    let product: Product
    let score: Decimal
    let reasons: [String]
    let matchedKeywords: [String]
    let matchedSize: String?
    let matchedColor: String?
    let matchedCategory: String?
}

struct ProductMatcher {
    func match(
        object: DrawingObject,
        annotations: [DrawingAnnotation],
        products: [Product],
        prices: [ProductPrice],
        projectContext: ProjectContext,
        recentProducts: [RecentProduct],
        date: Date = Date()
    ) -> [ProductMatchResult] {
        let annotationText = annotations
            .filter { $0.linkedObjectID == nil || $0.linkedObjectID == object.id }
            .map(\.text)
            .joined(separator: " ")
            .lowercased()
        let objectType = object.objectType.lowercased()
        let sizes = parseSizes(from: annotationText)
        let colors = parseColors(from: annotationText)
        let recentIDs = Set(recentProducts.map(\.productID))
        let pricedIDs = Set(prices.filter { $0.isEffective(on: date) }.map(\.productID))

        return products.compactMap { product in
            guard product.active else { return nil }

            var score = Decimal(0)
            var reasons: [String] = []
            var keywords: [String] = []
            var matchedSize: String?
            var matchedColor: String?
            var matchedCategory: String?

            let category = product.category.lowercased()
            if category.contains(objectType) || objectType.contains(category) {
                score += weight("0.35")
                matchedCategory = product.category
                reasons.append("Object type \(object.objectType) matches category \(product.category).")
            }

            let haystack = [product.name, product.sku, product.brand, product.category, product.size, product.color]
                .compactMap { $0?.lowercased() }
                .joined(separator: " ")

            for token in annotationText.split(separator: " ").map(String.init) where token.count >= 3 {
                if haystack.contains(token) {
                    score += weight("0.04")
                    keywords.append(token)
                }
            }
            if !keywords.isEmpty {
                reasons.append("Annotation keywords match product fields.")
            }

            if let productSize = product.size?.lowercased(),
               let size = sizes.first(where: { productSize.contains($0) }) {
                score += weight("0.20")
                matchedSize = size
                reasons.append("Size \(size) matches.")
            }

            if let productColor = product.color?.lowercased(),
               let color = colors.first(where: { productColor.contains($0) || $0.contains(productColor) }) {
                score += weight("0.15")
                matchedColor = color
                reasons.append("Color \(color) matches.")
            }

            if projectContext.roomType.lowercased().contains("bath"),
               ["vanity", "toilet", "shower", "tile"].contains(category) {
                score += weight("0.08")
                reasons.append("Bathroom room type boosts common bath category.")
            }

            if recentIDs.contains(product.id) {
                score += weight("0.08")
                reasons.append("Product was used recently.")
            }
            if pricedIDs.contains(product.id) {
                score += weight("0.08")
                reasons.append("Product has an effective price.")
            }

            guard score > 0 else { return nil }
            return ProductMatchResult(
                product: product,
                score: min(score, weight("1")),
                reasons: reasons,
                matchedKeywords: Array(Set(keywords)).sorted(),
                matchedSize: matchedSize,
                matchedColor: matchedColor,
                matchedCategory: matchedCategory
            )
        }
        .sorted { $0.score > $1.score }
    }

    private func parseSizes(from text: String) -> [String] {
        let patterns = [
            #"\d+\s?inch"#,
            #"\d+\s?""#,
            #"\d+\s?ft"#,
            #"\d+\s?x\s?\d+"#
        ]
        return patterns.flatMap { pattern in
            (try? NSRegularExpression(pattern: pattern))?.matches(
                in: text,
                range: NSRange(text.startIndex..., in: text)
            ).compactMap { match in
                Range(match.range, in: text).map { String(text[$0]).replacingOccurrences(of: "\"", with: " inch") }
            } ?? []
        }
    }

    private func parseColors(from text: String) -> [String] {
        ["matte black", "brushed nickel", "white", "black", "chrome"].filter { text.contains($0) }
    }

    private func weight(_ value: String) -> Decimal {
        Decimal(string: value) ?? 0
    }
}
