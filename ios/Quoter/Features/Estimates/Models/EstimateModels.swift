import Foundation

enum RenovationType: String, CaseIterable, Codable, Identifiable {
    case kitchenRenovation = "kitchen_renovation"
    case bathroomRenovation = "bathroom_renovation"
    case fullHouseRenovation = "full_house_renovation"
    case condoRenovation = "condo_renovation"
    case basementRenovation = "basement_renovation"
    case bedroomRoomRenovation = "bedroom_room_renovation"
    case flooringProject = "flooring_project"
    case doorsWindows = "doors_windows"
    case customProject = "custom_project"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kitchenRenovation: return "Kitchen Renovation"
        case .bathroomRenovation: return "Bathroom Renovation"
        case .fullHouseRenovation: return "Full House Renovation"
        case .condoRenovation: return "Condo Renovation"
        case .basementRenovation: return "Basement Renovation"
        case .bedroomRoomRenovation: return "Bedroom / Room Renovation"
        case .flooringProject: return "Flooring Project"
        case .doorsWindows: return "Doors & Windows"
        case .customProject: return "Custom Project"
        }
    }

    var localizedTitle: String {
        AppLanguage.localizedString(title)
    }

    var shortTitle: String {
        switch self {
        case .kitchenRenovation: return "Kitchen"
        case .bathroomRenovation: return "Bathroom"
        case .fullHouseRenovation: return "Full House"
        case .condoRenovation: return "Condo"
        case .basementRenovation: return "Basement"
        case .bedroomRoomRenovation: return "Room"
        case .flooringProject: return "Flooring"
        case .doorsWindows: return "Doors & Windows"
        case .customProject: return "Custom"
        }
    }

    var localizedShortTitle: String {
        AppLanguage.localizedString(shortTitle)
    }

    var systemImage: String {
        switch self {
        case .kitchenRenovation: return "cooktop"
        case .bathroomRenovation: return "shower"
        case .fullHouseRenovation: return "house"
        case .condoRenovation: return "building.2"
        case .basementRenovation: return "stairs"
        case .bedroomRoomRenovation: return "bed.double"
        case .flooringProject: return "square.grid.3x3"
        case .doorsWindows: return "door.left.hand.open"
        case .customProject: return "slider.horizontal.3"
        }
    }

    var defaultCategoryNames: [String] {
        switch self {
        case .kitchenRenovation:
            return [
                "Demolition",
                "Framing / Structural",
                "Plumbing",
                "Electrical",
                "Cabinets",
                "Countertop",
                "Backsplash",
                "Flooring",
                "Drywall / Patching",
                "Painting",
                "Appliances",
                "Trim / Finish Carpentry",
                "Cleanup / Disposal",
                "Other Category"
            ]
        case .bathroomRenovation:
            return [
                "Demolition",
                "Plumbing",
                "Electrical",
                "Waterproofing",
                "Shower / Tub",
                "Tile Work",
                "Vanity / Fixtures",
                "Flooring",
                "Drywall / Ceiling",
                "Painting",
                "Accessories",
                "Cleanup / Disposal",
                "Other Category"
            ]
        case .fullHouseRenovation:
            return [
                "Site Protection",
                "Demolition",
                "Framing / Structural",
                "Drywall",
                "Flooring",
                "Painting",
                "Kitchen",
                "Bathrooms",
                "Electrical",
                "Plumbing",
                "HVAC",
                "Doors",
                "Windows",
                "Trim / Finish Carpentry",
                "Stairs",
                "Basement",
                "Cleanup / Disposal",
                "Project Management",
                "Other Category"
            ]
        case .condoRenovation:
            return [
                "Condo Management Requirements",
                "Elevator / Loading Booking",
                "Common Area Protection",
                "Demolition",
                "Kitchen",
                "Bathroom",
                "Flooring",
                "Painting",
                "Electrical",
                "Plumbing",
                "Doors / Trim",
                "Appliance Installation",
                "Cleanup / Disposal",
                "Other Category"
            ]
        case .basementRenovation:
            return [
                "Demolition",
                "Framing",
                "Insulation",
                "Electrical",
                "Plumbing",
                "HVAC",
                "Drywall",
                "Flooring",
                "Bathroom",
                "Laundry",
                "Painting",
                "Doors / Trim",
                "Ceiling",
                "Cleanup / Disposal",
                "Other Category"
            ]
        case .bedroomRoomRenovation:
            return [
                "Demolition",
                "Drywall Repair",
                "Flooring",
                "Painting",
                "Electrical",
                "Closet",
                "Doors",
                "Trim / Baseboard",
                "Window Trim",
                "Cleanup",
                "Other Category"
            ]
        case .flooringProject:
            return [
                "Existing Floor Removal",
                "Subfloor Preparation",
                "Floor Leveling",
                "New Flooring Material",
                "Flooring Installation",
                "Stairs",
                "Baseboard / Quarter Round",
                "Transitions",
                "Furniture Moving",
                "Cleanup / Disposal",
                "Other Category"
            ]
        case .doorsWindows:
            return [
                "Door Removal",
                "New Doors",
                "Door Hardware",
                "Door Installation",
                "Window Removal",
                "New Windows",
                "Window Installation",
                "Trim / Casing",
                "Caulking / Sealing",
                "Painting / Touch-up",
                "Cleanup / Disposal",
                "Other Category"
            ]
        case .customProject:
            return [
                "Demolition",
                "Preparation",
                "Materials",
                "Labor",
                "Subcontractor",
                "Finishing",
                "Cleanup / Disposal",
                "Other Category"
            ]
        }
    }
}

enum UnitType: String, CaseIterable, Codable, Identifiable {
    case each = "ea"
    case squareFoot = "sq ft"
    case linearFoot = "ln ft"
    case hour = "hr"
    case day = "day"
    case allowance = "allowance"
    case lot = "lot"

    var id: String { rawValue }
}

struct CostBreakdown: Codable, Hashable {
    var materialCost: Decimal
    var laborCost: Decimal
    var subcontractorCost: Decimal
    var otherCost: Decimal
    var markup: Decimal
    var tax: Decimal

    static let empty = CostBreakdown(
        materialCost: 0,
        laborCost: 0,
        subcontractorCost: 0,
        otherCost: 0,
        markup: 0,
        tax: 0
    )

    var baseCost: Decimal {
        materialCost + laborCost + subcontractorCost + otherCost
    }
}

struct EstimateItem: Codable, Identifiable, Hashable {
    var id: UUID
    var productID: UUID?
    var productNameSnapshot: String?
    var skuSnapshot: String?
    var brandSnapshot: String?
    var productCategorySnapshot: String?
    var materialSnapshot: String?
    var unitPriceSnapshot: Decimal?
    var itemName: String
    var categoryID: UUID
    var description: String
    var quantity: Decimal
    var unit: String
    var costs: CostBreakdown
    var notes: String
    var selected: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case productID = "productId"
        case productNameSnapshot
        case skuSnapshot
        case brandSnapshot
        case productCategorySnapshot
        case materialSnapshot
        case unitPriceSnapshot
        case itemName
        case categoryID = "categoryId"
        case description
        case quantity
        case unit
        case costs
        case notes
        case selected
    }

    init(
        id: UUID = UUID(),
        productID: UUID? = nil,
        productNameSnapshot: String? = nil,
        skuSnapshot: String? = nil,
        brandSnapshot: String? = nil,
        productCategorySnapshot: String? = nil,
        materialSnapshot: String? = nil,
        unitPriceSnapshot: Decimal? = nil,
        itemName: String = "",
        categoryID: UUID,
        description: String = "",
        quantity: Decimal = 1,
        unit: String = UnitType.each.rawValue,
        costs: CostBreakdown = .empty,
        notes: String = "",
        selected: Bool = true
    ) {
        self.id = id
        self.productID = productID
        self.productNameSnapshot = productNameSnapshot
        self.skuSnapshot = skuSnapshot
        self.brandSnapshot = brandSnapshot
        self.productCategorySnapshot = productCategorySnapshot
        self.materialSnapshot = materialSnapshot
        self.unitPriceSnapshot = unitPriceSnapshot
        self.itemName = itemName
        self.categoryID = categoryID
        self.description = description
        self.quantity = quantity
        self.unit = unit
        self.costs = costs
        self.notes = notes
        self.selected = selected
    }

    var subtotal: Decimal {
        guard selected else { return 0 }
        return DecimalFormatter.roundedMoney(quantity * costs.baseCost + costs.markup)
    }
}

struct EstimateCategory: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var items: [EstimateItem]
    var sortOrder: Int

    init(id: UUID = UUID(), name: String, items: [EstimateItem] = [], sortOrder: Int) {
        self.id = id
        self.name = name
        self.items = items
        self.sortOrder = sortOrder
    }

    var selectedTotal: Decimal {
        items.reduce(0) { $0 + $1.subtotal }
    }
}

struct EstimateTemplate: Codable, Identifiable, Hashable {
    var id: UUID
    var projectID: UUID?
    var name: String
    var renovationType: RenovationType
    var categories: [EstimateCategory]
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case projectID = "projectId"
        case name
        case renovationType
        case categories
        case createdAt
        case updatedAt
    }

    init(
        id: UUID = UUID(),
        projectID: UUID?,
        name: String,
        renovationType: RenovationType,
        categories: [EstimateCategory],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.projectID = projectID
        self.name = name
        self.renovationType = renovationType
        self.categories = categories
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static let taxRate: Decimal = 0.13

    var subtotal: Decimal {
        categories.reduce(0) { $0 + $1.selectedTotal }
    }

    var taxTotal: Decimal {
        DecimalFormatter.roundedMoney(subtotal * Self.taxRate)
    }

    var total: Decimal {
        subtotal + taxTotal
    }

    static func makeDefault(projectID: UUID?, type: RenovationType, name: String? = nil) -> EstimateTemplate {
        let categories = type.defaultCategoryNames.enumerated().map { index, categoryName in
            EstimateCategory(name: categoryName, sortOrder: index)
        }
        return EstimateTemplate(
            projectID: projectID,
            name: name ?? type.title,
            renovationType: type,
            categories: categories
        )
    }

    func reusableCopy(named templateName: String) -> EstimateTemplate {
        EstimateTemplate(
            id: UUID(),
            projectID: nil,
            name: templateName,
            renovationType: renovationType,
            categories: Self.freshCategories(from: categories),
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func projectCopy(projectID: UUID, named estimateName: String? = nil) -> EstimateTemplate {
        EstimateTemplate(
            id: UUID(),
            projectID: projectID,
            name: estimateName ?? name,
            renovationType: renovationType,
            categories: Self.freshCategories(from: categories),
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private static func freshCategories(from categories: [EstimateCategory]) -> [EstimateCategory] {
        categories.map { category in
            let categoryID = UUID()
            let items = category.items.map { item in
                EstimateItem(
                    id: UUID(),
                    productID: item.productID,
                    productNameSnapshot: item.productNameSnapshot,
                    skuSnapshot: item.skuSnapshot,
                    brandSnapshot: item.brandSnapshot,
                    productCategorySnapshot: item.productCategorySnapshot,
                    materialSnapshot: item.materialSnapshot,
                    unitPriceSnapshot: item.unitPriceSnapshot,
                    itemName: item.itemName,
                    categoryID: categoryID,
                    description: item.description,
                    quantity: item.quantity,
                    unit: item.unit,
                    costs: item.costs,
                    notes: item.notes,
                    selected: item.selected
                )
            }
            return EstimateCategory(
                id: categoryID,
                name: category.name,
                items: items,
                sortOrder: category.sortOrder
            )
        }
    }
}
