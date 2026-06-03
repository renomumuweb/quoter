package catalog

import "strings"

func scoreProductMatch(product Product, objectType string, annotation string, roomType string) (float64, []string, []string, *string, *string, *string) {
	score := 0.0
	reasons := make([]string, 0)
	keywords := make([]string, 0)
	categoryLower := strings.ToLower(product.Category)
	if objectType != "" && (strings.Contains(categoryLower, objectType) || strings.Contains(objectType, categoryLower)) {
		score += 0.35
		reasons = append(reasons, "object_type matches product category")
		category := product.Category
		returnedKeywords := keywordMatches(product, annotation)
		keywords = append(keywords, returnedKeywords...)
		return scoreProductDetails(product, annotation, roomType, score, reasons, keywords, nil, nil, &category)
	}
	return scoreProductDetails(product, annotation, roomType, score, reasons, keywords, nil, nil, nil)
}

func scoreProductDetails(product Product, annotation string, roomType string, score float64, reasons []string, keywords []string, matchedSize *string, matchedColor *string, matchedCategory *string) (float64, []string, []string, *string, *string, *string) {
	matches := keywordMatches(product, annotation)
	if len(matches) > 0 {
		score += float64(len(matches)) * 0.04
		if score > 0.2 {
			score = 0.2 + (score - 0.2)
		}
		reasons = append(reasons, "annotation keywords match product fields")
		keywords = append(keywords, matches...)
	}
	for _, size := range []string{"60 inch", "60\"", "5 ft", "12 x 24", "24 x 48"} {
		if strings.Contains(annotation, size) && product.Size != nil && strings.Contains(strings.ToLower(*product.Size), strings.ReplaceAll(size, "\"", " inch")) {
			score += 0.2
			matchedSize = &size
			reasons = append(reasons, "annotation size matches product size")
			break
		}
	}
	for _, color := range []string{"matte black", "brushed nickel", "white", "black", "chrome"} {
		if strings.Contains(annotation, color) && product.Color != nil && strings.Contains(strings.ToLower(*product.Color), color) {
			score += 0.15
			matchedColor = &color
			reasons = append(reasons, "annotation color matches product color")
			break
		}
	}
	if strings.Contains(roomType, "bath") && containsAny(strings.ToLower(product.Category), []string{"vanity", "toilet", "shower", "tile", "install"}) {
		score += 0.08
		reasons = append(reasons, "bathroom project boosts common bath category")
	}
	if product.CurrentPrice != nil {
		score += 0.08
		reasons = append(reasons, "product has an active price")
	}
	if !product.Active {
		score -= 0.2
	}
	if score > 1 {
		score = 1
	}
	return score, reasons, uniqueStrings(keywords), matchedSize, matchedColor, matchedCategory
}

func keywordMatches(product Product, annotation string) []string {
	if annotation == "" {
		return nil
	}
	haystack := strings.ToLower(strings.Join([]string{
		product.Name, product.SKU, product.Brand, product.Category, optionalValue(product.Size), optionalValue(product.Color),
	}, " "))
	matches := make([]string, 0)
	for _, token := range strings.Fields(annotation) {
		token = strings.Trim(token, ",.;:()[]")
		if len(token) >= 3 && strings.Contains(haystack, token) {
			matches = append(matches, token)
		}
	}
	return uniqueStrings(matches)
}

func optionalValue(value *string) string {
	if value == nil {
		return ""
	}
	return *value
}

func containsAny(value string, needles []string) bool {
	for _, needle := range needles {
		if strings.Contains(value, needle) {
			return true
		}
	}
	return false
}
