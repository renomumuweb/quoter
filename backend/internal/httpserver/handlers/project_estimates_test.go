package handlers

import (
	"encoding/json"
	"testing"

	"github.com/google/uuid"
)

func TestAppendProjectEstimateItemsToPreviewCreatesPendingScopeItems(t *testing.T) {
	categoryID := uuid.New()
	itemID := uuid.New()
	productID := uuid.New()
	categories := []estimateTemplateCategoryJSON{
		{
			ID:   categoryID,
			Name: "Kitchen",
			Items: []estimateTemplateItemJSON{
				{
					ID:                itemID,
					ProductID:         &productID,
					ItemName:          "Countertop",
					CategoryID:        categoryID,
					RoomName:          "Kitchen 1",
					ScopeCode:         "kitchen_countertop",
					MaterialChoice:    "Quartz",
					SuppliedBy:        "Company",
					RiskFlags:         []string{"Engineer review required."},
					Quantity:          42,
					Unit:              "sq ft",
					Notes:             "Waterfall edge to review",
					Selected:          true,
					PricingStatus:     "pending",
					UnitPriceSnapshot: floatPtr(999),
					Costs: estimateTemplateCostBreakdown{
						MaterialCost: 999,
						LaborCost:    999,
					},
				},
				{
					ID:         uuid.New(),
					ItemName:   "Unselected item",
					CategoryID: categoryID,
					Quantity:   1,
					Unit:       "ea",
					Selected:   false,
				},
			},
		},
	}
	raw, err := json.Marshal(categories)
	if err != nil {
		t.Fatal(err)
	}

	estimate := projectEstimatePayload{
		ID:         uuid.New(),
		ProjectID:  uuid.New(),
		Categories: raw,
	}
	preview := quotePreviewPayload{}

	if err := (BusinessHandler{}).appendProjectEstimateItemsToPreview(estimate, &preview); err != nil {
		t.Fatal(err)
	}
	if len(preview.Items) != 1 {
		t.Fatalf("expected 1 selected quote item, got %d", len(preview.Items))
	}

	item := preview.Items[0]
	if item.ProductID == nil || *item.ProductID != productID {
		t.Fatalf("expected product id snapshot to be preserved")
	}
	if item.SourceEstimateItemID == nil || *item.SourceEstimateItemID != itemID {
		t.Fatalf("expected source estimate item id")
	}
	if item.PricingStatus != "pending" {
		t.Fatalf("expected pending pricing status, got %q", item.PricingStatus)
	}
	if item.UnitPriceSnapshot != 0 || item.LineTotal != 0 {
		t.Fatalf("expected no field pricing, got unit=%v total=%v", item.UnitPriceSnapshot, item.LineTotal)
	}
	if item.RoomSnapshot != "Kitchen 1" || item.ScopeSnapshot != "Kitchen" || item.MaterialSnapshot != "Quartz" || item.SuppliedBySnapshot != "Company" {
		t.Fatalf("scope snapshots were not preserved: %#v", item)
	}
	if len(preview.Warnings) != 1 || preview.Warnings[0].Message != "Engineer review required." {
		t.Fatalf("expected risk warning, got %#v", preview.Warnings)
	}
}

func floatPtr(value float64) *float64 {
	return &value
}
