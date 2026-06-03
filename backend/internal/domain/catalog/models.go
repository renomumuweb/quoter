package catalog

import (
	"errors"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"
)

var ErrValidation = errors.New("catalog validation failed")

type ValidationError struct {
	Message string
}

func (e ValidationError) Error() string {
	return e.Message
}

func (e ValidationError) Unwrap() error {
	return ErrValidation
}

type Brand struct {
	ID        uuid.UUID
	Name      string
	Status    string
	CreatedAt time.Time
	UpdatedAt time.Time
}

type Category struct {
	ID        uuid.UUID
	ParentID  *uuid.UUID
	Name      string
	Kind      string
	Status    string
	CreatedAt time.Time
	UpdatedAt time.Time
}

type Product struct {
	ID             uuid.UUID
	BrandID        *uuid.UUID
	Brand          string
	CategoryID     uuid.UUID
	Category       string
	CategoryKind   string
	Name           string
	SKU            string
	Size           *string
	Color          *string
	Material       *string
	Unit           string
	Description    *string
	ImageURL       *string
	Active         bool
	IsService      bool
	Status         string
	CurrentPriceID *uuid.UUID
	Currency       string
	CurrentPrice   *float64
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

type BrandInput struct {
	Name string
}

type CategoryInput struct {
	ParentID *uuid.UUID
	Name     string
	Kind     string
}

type ProductInput struct {
	BrandID      *uuid.UUID
	CategoryID   uuid.UUID
	Name         string
	SKU          string
	Size         *string
	Color        *string
	Material     *string
	Unit         string
	Description  *string
	ImageURL     *string
	Active       *bool
	IsService    *bool
	CurrentPrice *float64
	Currency     string
}

type ProductFilter struct {
	Query      string
	CategoryID *uuid.UUID
	BrandID    *uuid.UUID
	ActiveOnly bool
}

func (input ProductInput) ActiveValue() bool {
	return activeValue(input.Active)
}

func (input ProductInput) IsServiceValue() bool {
	return isServiceValue(input.IsService)
}

type RecommendationInput struct {
	ObjectType string
	Annotation string
	RoomType   string
}

type ProductMatch struct {
	Product         Product
	Score           float64
	Reasons         []string
	MatchedKeywords []string
	MatchedSize     *string
	MatchedColor    *string
	MatchedCategory *string
}

func normalizeBrandInput(input BrandInput) (BrandInput, error) {
	input.Name = strings.TrimSpace(input.Name)
	if input.Name == "" {
		return input, ValidationError{Message: "brand name is required"}
	}
	return input, nil
}

func normalizeCategoryInput(input CategoryInput) (CategoryInput, error) {
	input.Name = strings.TrimSpace(input.Name)
	input.Kind = strings.ToLower(strings.TrimSpace(input.Kind))
	if input.Name == "" {
		return input, ValidationError{Message: "category name is required"}
	}
	if input.Kind == "" {
		input.Kind = "product"
	}
	if input.Kind != "product" && input.Kind != "service" {
		return input, ValidationError{Message: "category kind must be product or service"}
	}
	return input, nil
}

func normalizeProductInput(input ProductInput) (ProductInput, error) {
	input.Name = strings.TrimSpace(input.Name)
	input.SKU = strings.TrimSpace(input.SKU)
	input.Unit = strings.TrimSpace(input.Unit)
	input.Currency = strings.TrimSpace(input.Currency)
	if input.Name == "" || input.SKU == "" || input.CategoryID == uuid.Nil {
		return input, ValidationError{Message: "category_id, name, and sku are required"}
	}
	if input.Unit == "" {
		input.Unit = "each"
	}
	if input.Currency == "" {
		input.Currency = "USD"
	}
	trimStringPtr(&input.Size)
	trimStringPtr(&input.Color)
	trimStringPtr(&input.Material)
	trimStringPtr(&input.Description)
	trimStringPtr(&input.ImageURL)
	if input.CurrentPrice != nil && *input.CurrentPrice < 0 {
		return input, ValidationError{Message: "current_price must be zero or greater"}
	}
	return input, nil
}

func activeValue(value *bool) bool {
	if value == nil {
		return true
	}
	return *value
}

func isServiceValue(value *bool) bool {
	if value == nil {
		return false
	}
	return *value
}

func trimStringPtr(value **string) {
	if value == nil || *value == nil {
		return
	}
	trimmed := strings.TrimSpace(**value)
	if trimmed == "" {
		*value = nil
		return
	}
	*value = &trimmed
}

func uniqueStrings(values []string) []string {
	seen := map[string]struct{}{}
	out := make([]string, 0, len(values))
	for _, value := range values {
		if _, ok := seen[value]; ok {
			continue
		}
		seen[value] = struct{}{}
		out = append(out, value)
	}
	sort.Strings(out)
	return out
}
