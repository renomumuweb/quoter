package catalog

import (
	"context"
	"math"
	"strings"

	"github.com/google/uuid"
)

type Repository interface {
	ListBrands(ctx context.Context, companyID uuid.UUID) ([]Brand, error)
	CreateBrand(ctx context.Context, companyID uuid.UUID, input BrandInput) (Brand, error)
	UpdateBrand(ctx context.Context, companyID uuid.UUID, id uuid.UUID, input BrandInput) (Brand, error)
	DeleteBrand(ctx context.Context, companyID uuid.UUID, id uuid.UUID) error

	ListCategories(ctx context.Context, companyID uuid.UUID) ([]Category, error)
	CreateCategory(ctx context.Context, companyID uuid.UUID, input CategoryInput) (Category, error)
	UpdateCategory(ctx context.Context, companyID uuid.UUID, id uuid.UUID, input CategoryInput) (Category, error)
	DeleteCategory(ctx context.Context, companyID uuid.UUID, id uuid.UUID) error

	ListProducts(ctx context.Context, companyID uuid.UUID, filter ProductFilter) ([]Product, error)
	GetProduct(ctx context.Context, companyID uuid.UUID, id uuid.UUID) (Product, error)
	CreateProduct(ctx context.Context, companyID uuid.UUID, input ProductInput) (Product, error)
	UpdateProduct(ctx context.Context, companyID uuid.UUID, id uuid.UUID, input ProductInput) (Product, error)
	DeleteProduct(ctx context.Context, companyID uuid.UUID, id uuid.UUID) error
}

type Service struct {
	repo Repository
}

func NewService(repo Repository) *Service {
	return &Service{repo: repo}
}

func (s *Service) ListBrands(ctx context.Context, companyID uuid.UUID) ([]Brand, error) {
	return s.repo.ListBrands(ctx, companyID)
}

func (s *Service) CreateBrand(ctx context.Context, companyID uuid.UUID, input BrandInput) (Brand, error) {
	normalized, err := normalizeBrandInput(input)
	if err != nil {
		return Brand{}, err
	}
	return s.repo.CreateBrand(ctx, companyID, normalized)
}

func (s *Service) UpdateBrand(ctx context.Context, companyID uuid.UUID, id uuid.UUID, input BrandInput) (Brand, error) {
	normalized, err := normalizeBrandInput(input)
	if err != nil {
		return Brand{}, err
	}
	return s.repo.UpdateBrand(ctx, companyID, id, normalized)
}

func (s *Service) DeleteBrand(ctx context.Context, companyID uuid.UUID, id uuid.UUID) error {
	return s.repo.DeleteBrand(ctx, companyID, id)
}

func (s *Service) ListCategories(ctx context.Context, companyID uuid.UUID) ([]Category, error) {
	return s.repo.ListCategories(ctx, companyID)
}

func (s *Service) CreateCategory(ctx context.Context, companyID uuid.UUID, input CategoryInput) (Category, error) {
	normalized, err := normalizeCategoryInput(input)
	if err != nil {
		return Category{}, err
	}
	return s.repo.CreateCategory(ctx, companyID, normalized)
}

func (s *Service) UpdateCategory(ctx context.Context, companyID uuid.UUID, id uuid.UUID, input CategoryInput) (Category, error) {
	normalized, err := normalizeCategoryInput(input)
	if err != nil {
		return Category{}, err
	}
	return s.repo.UpdateCategory(ctx, companyID, id, normalized)
}

func (s *Service) DeleteCategory(ctx context.Context, companyID uuid.UUID, id uuid.UUID) error {
	return s.repo.DeleteCategory(ctx, companyID, id)
}

func (s *Service) ListProducts(ctx context.Context, companyID uuid.UUID, filter ProductFilter) ([]Product, error) {
	filter.Query = strings.TrimSpace(filter.Query)
	return s.repo.ListProducts(ctx, companyID, filter)
}

func (s *Service) GetProduct(ctx context.Context, companyID uuid.UUID, id uuid.UUID) (Product, error) {
	return s.repo.GetProduct(ctx, companyID, id)
}

func (s *Service) CreateProduct(ctx context.Context, companyID uuid.UUID, input ProductInput) (Product, error) {
	normalized, err := normalizeProductInput(input)
	if err != nil {
		return Product{}, err
	}
	return s.repo.CreateProduct(ctx, companyID, normalized)
}

func (s *Service) UpdateProduct(ctx context.Context, companyID uuid.UUID, id uuid.UUID, input ProductInput) (Product, error) {
	normalized, err := normalizeProductInput(input)
	if err != nil {
		return Product{}, err
	}
	return s.repo.UpdateProduct(ctx, companyID, id, normalized)
}

func (s *Service) DeleteProduct(ctx context.Context, companyID uuid.UUID, id uuid.UUID) error {
	return s.repo.DeleteProduct(ctx, companyID, id)
}

func (s *Service) RecommendProducts(ctx context.Context, companyID uuid.UUID, input RecommendationInput) ([]ProductMatch, error) {
	products, err := s.repo.ListProducts(ctx, companyID, ProductFilter{ActiveOnly: true})
	if err != nil {
		return nil, err
	}

	objectType := strings.ToLower(strings.TrimSpace(input.ObjectType))
	annotation := strings.ToLower(strings.TrimSpace(input.Annotation))
	roomType := strings.ToLower(strings.TrimSpace(input.RoomType))
	if roomType == "" {
		roomType = "bathroom"
	}

	results := make([]ProductMatch, 0)
	for _, product := range products {
		score, reasons, keywords, size, color, category := scoreProductMatch(product, objectType, annotation, roomType)
		if score <= 0 {
			continue
		}
		results = append(results, ProductMatch{
			Product:         product,
			Score:           roundMoney(score),
			Reasons:         reasons,
			MatchedKeywords: keywords,
			MatchedSize:     size,
			MatchedColor:    color,
			MatchedCategory: category,
		})
	}
	sortProductMatches(results)
	if len(results) > 12 {
		results = results[:12]
	}
	return results, nil
}

func sortProductMatches(results []ProductMatch) {
	for i := 0; i < len(results); i++ {
		for j := i + 1; j < len(results); j++ {
			if results[j].Score > results[i].Score {
				results[i], results[j] = results[j], results[i]
			}
		}
	}
}

func roundMoney(value float64) float64 {
	return math.Round(value*100) / 100
}
