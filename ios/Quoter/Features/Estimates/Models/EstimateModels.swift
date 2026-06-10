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
    case room = "room"
    case fixture = "fixture"
    case opening = "opening"
    case light = "light"
    case outlet = "outlet"
    case door = "door"
    case window = "window"
    case hour = "hr"
    case day = "day"
    case allowance = "allowance"
    case lot = "lot"

    var id: String { rawValue }

    var localizedTitle: String {
        AppLanguage.localizedKnownSystemString(rawValue)
    }
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
    var roomName: String
    var roomType: String
    var floorLevel: String
    var scopeCode: String
    var materialChoice: String
    var suppliedBy: String
    var riskFlags: [String]
    var pricingStatus: String
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
        case roomName
        case roomType
        case floorLevel
        case scopeCode
        case materialChoice
        case suppliedBy
        case riskFlags
        case pricingStatus
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
        roomName: String = "",
        roomType: String = "",
        floorLevel: String = "",
        scopeCode: String = "",
        materialChoice: String = "",
        suppliedBy: String = "TBD",
        riskFlags: [String] = [],
        pricingStatus: String = "pending",
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
        self.roomName = roomName
        self.roomType = roomType
        self.floorLevel = floorLevel
        self.scopeCode = scopeCode
        self.materialChoice = materialChoice
        self.suppliedBy = suppliedBy
        self.riskFlags = riskFlags
        self.pricingStatus = pricingStatus
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
        let categories = QuoteScopeCatalog.categories(for: type)
        return EstimateTemplate(
            projectID: projectID,
            name: name ?? type.localizedTitle,
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
                    roomName: item.roomName,
                    roomType: item.roomType,
                    floorLevel: item.floorLevel,
                    scopeCode: item.scopeCode,
                    materialChoice: item.materialChoice,
                    suppliedBy: item.suppliedBy,
                    riskFlags: item.riskFlags,
                    pricingStatus: item.pricingStatus,
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

struct QuoteScopeItemSeed: Hashable {
    let name: String
    let scopeCode: String
    let unit: String
    let materialChoice: String
    let suppliedBy: String
    let riskFlags: [String]
    let description: String

    init(
        _ name: String,
        scopeCode: String,
        unit: String = UnitType.each.rawValue,
        materialChoice: String = "",
        suppliedBy: String = "TBD",
        riskFlags: [String] = [],
        description: String = ""
    ) {
        self.name = name
        self.scopeCode = scopeCode
        self.unit = unit
        self.materialChoice = materialChoice
        self.suppliedBy = suppliedBy
        self.riskFlags = riskFlags
        self.description = description
    }
}

enum QuoteScopeCatalog {
    static let roomTypes = [
        "Kitchen", "Bathroom", "Powder Room", "Bedroom", "Living Room", "Family Room",
        "Dining Room", "Basement", "Laundry Room", "Hallway", "Staircase", "Garage",
        "Exterior", "Whole House", "Other"
    ]

    static let floorLevels = [
        "Basement", "Ground Floor", "2nd Floor", "3rd Floor", "Attic", "Exterior", "Other"
    ]

    static let suppliedByOptions = ["TBD", "Client", "Company"]

    static func categories(for type: RenovationType) -> [EstimateCategory] {
        let names: [String]
        switch type {
        case .kitchenRenovation:
            names = ["Demolition", "Kitchen", "Flooring", "Painting", "Ceiling", "Electrical", "Plumbing / HVAC", "Doors / Windows", "Cleanup / Disposal", "Other Category"]
        case .bathroomRenovation:
            names = ["Demolition", "Bathroom", "Flooring", "Painting", "Ceiling", "Electrical", "Plumbing / HVAC", "Doors / Windows", "Cleanup / Disposal", "Other Category"]
        case .fullHouseRenovation:
            names = ["Whole House", "Demolition", "Kitchen", "Bathroom", "Bedroom", "Flooring", "Painting", "Ceiling", "Doors / Windows", "Electrical", "Plumbing / HVAC", "Basement", "Exterior", "Cleanup / Disposal", "Other Category"]
        case .condoRenovation:
            names = ["Condo Management Requirements", "Kitchen", "Bathroom", "Flooring", "Painting", "Ceiling", "Doors / Windows", "Electrical", "Plumbing / HVAC", "Cleanup / Disposal", "Other Category"]
        case .basementRenovation:
            names = ["Basement", "Demolition", "Flooring", "Painting", "Ceiling", "Doors / Windows", "Electrical", "Plumbing / HVAC", "Cleanup / Disposal", "Other Category"]
        case .bedroomRoomRenovation:
            names = ["Bedroom", "Demolition", "Flooring", "Painting", "Ceiling", "Doors / Windows", "Electrical", "Cleanup / Disposal", "Other Category"]
        case .flooringProject:
            names = ["Flooring", "Demolition", "Doors / Windows", "Cleanup / Disposal", "Other Category"]
        case .doorsWindows:
            names = ["Doors / Windows", "Demolition", "Painting", "Cleanup / Disposal", "Other Category"]
        case .customProject:
            names = ["Demolition", "Flooring", "Painting", "Ceiling", "Doors / Windows", "Electrical", "Plumbing / HVAC", "Kitchen", "Bathroom", "Basement", "Exterior", "Other Category"]
        }

        return names.enumerated().map { index, name in
            let categoryID = UUID()
            let items = seeds(for: name).map { seed in
                EstimateItem(
                    itemName: seed.name,
                    categoryID: categoryID,
                    scopeCode: seed.scopeCode,
                    materialChoice: seed.materialChoice,
                    suppliedBy: seed.suppliedBy,
                    riskFlags: seed.riskFlags,
                    pricingStatus: "pending",
                    description: seed.description,
                    quantity: 1,
                    unit: seed.unit,
                    selected: false
                )
            }
            return EstimateCategory(id: categoryID, name: name, items: items, sortOrder: index)
        }
    }

    static func materialOptions(for scopeCode: String) -> [String] {
        materialOptionsByScope[scopeCode, default: []]
    }

    private static func seeds(for category: String) -> [QuoteScopeItemSeed] {
        switch category {
        case "Demolition":
            return [
                QuoteScopeItemSeed("Remove Existing Flooring", scopeCode: "demo_remove_flooring", unit: UnitType.squareFoot.rawValue),
                QuoteScopeItemSeed("Remove Baseboards", scopeCode: "demo_remove_baseboards", unit: UnitType.linearFoot.rawValue),
                QuoteScopeItemSeed("Remove Drywall", scopeCode: "demo_remove_drywall", unit: UnitType.squareFoot.rawValue),
                QuoteScopeItemSeed("Remove Ceiling", scopeCode: "demo_remove_ceiling", unit: UnitType.squareFoot.rawValue),
                QuoteScopeItemSeed("Remove Cabinets", scopeCode: "demo_remove_cabinets", unit: UnitType.linearFoot.rawValue),
                QuoteScopeItemSeed("Remove Vanity", scopeCode: "demo_remove_vanity", unit: UnitType.fixture.rawValue),
                QuoteScopeItemSeed("Remove Bathtub", scopeCode: "demo_remove_bathtub", unit: UnitType.fixture.rawValue),
                QuoteScopeItemSeed("Remove Shower", scopeCode: "demo_remove_shower", unit: UnitType.fixture.rawValue),
                QuoteScopeItemSeed("Remove Toilet", scopeCode: "demo_remove_toilet", unit: UnitType.fixture.rawValue),
                QuoteScopeItemSeed("Remove Tiles", scopeCode: "demo_remove_tiles", unit: UnitType.squareFoot.rawValue),
                QuoteScopeItemSeed("Remove Doors", scopeCode: "demo_remove_doors", unit: UnitType.door.rawValue),
                QuoteScopeItemSeed("Remove Windows", scopeCode: "demo_remove_windows", unit: UnitType.window.rawValue),
                QuoteScopeItemSeed("Remove Popcorn Ceiling", scopeCode: "demo_remove_popcorn_ceiling", unit: UnitType.squareFoot.rawValue),
                QuoteScopeItemSeed("Remove Closet", scopeCode: "demo_remove_closet", unit: UnitType.each.rawValue),
                QuoteScopeItemSeed("Remove Fixtures", scopeCode: "demo_remove_fixtures", unit: UnitType.fixture.rawValue),
                QuoteScopeItemSeed("Other Demolition", scopeCode: "demo_other", unit: UnitType.allowance.rawValue)
            ]
        case "Flooring":
            return [
                QuoteScopeItemSeed("Flooring Required", scopeCode: "flooring_required", unit: UnitType.squareFoot.rawValue),
                QuoteScopeItemSeed("Floor Leveling Required", scopeCode: "floor_leveling_required", unit: UnitType.squareFoot.rawValue),
                QuoteScopeItemSeed("Soundproofing Required", scopeCode: "floor_soundproofing_required", unit: UnitType.squareFoot.rawValue),
                QuoteScopeItemSeed("Underlayment Required", scopeCode: "floor_underlayment_required", unit: UnitType.squareFoot.rawValue),
                QuoteScopeItemSeed("Heated Floor Required", scopeCode: "floor_heated_required", unit: UnitType.squareFoot.rawValue, riskFlags: ["Licensed electrician review may be required."]),
                QuoteScopeItemSeed("Baseboard Required", scopeCode: "floor_baseboard_required", unit: UnitType.linearFoot.rawValue),
                QuoteScopeItemSeed("Quarter Round Required", scopeCode: "floor_quarter_round_required", unit: UnitType.linearFoot.rawValue),
                QuoteScopeItemSeed("Transition Strips Required", scopeCode: "floor_transition_required", unit: UnitType.each.rawValue)
            ]
        case "Painting":
            return [
                QuoteScopeItemSeed("Painting Required", scopeCode: "painting_required", unit: UnitType.squareFoot.rawValue),
                QuoteScopeItemSeed("Primer Required", scopeCode: "painting_primer_required", unit: UnitType.squareFoot.rawValue),
                QuoteScopeItemSeed("Patch / Repair Required", scopeCode: "painting_patch_required", unit: UnitType.allowance.rawValue),
                QuoteScopeItemSeed("Skim Coat Required", scopeCode: "painting_skim_coat_required", unit: UnitType.squareFoot.rawValue),
                QuoteScopeItemSeed("Accent Wall", scopeCode: "painting_accent_wall", unit: UnitType.squareFoot.rawValue),
                QuoteScopeItemSeed("Wallpaper / Paneling / Wainscoting", scopeCode: "wall_finish_feature", unit: UnitType.squareFoot.rawValue)
            ]
        case "Ceiling":
            return [
                QuoteScopeItemSeed("Ceiling Work Required", scopeCode: "ceiling_work_required", unit: UnitType.squareFoot.rawValue),
                QuoteScopeItemSeed("Popcorn Removal", scopeCode: "ceiling_popcorn_removal", unit: UnitType.squareFoot.rawValue),
                QuoteScopeItemSeed("New Drywall Ceiling", scopeCode: "ceiling_new_drywall", unit: UnitType.squareFoot.rawValue),
                QuoteScopeItemSeed("Drop Ceiling", scopeCode: "ceiling_drop_ceiling", unit: UnitType.squareFoot.rawValue),
                QuoteScopeItemSeed("Pot Lights Required", scopeCode: "ceiling_pot_lights", unit: UnitType.light.rawValue, riskFlags: ["ESA inspection may be required."]),
                QuoteScopeItemSeed("Ceiling Repair Required", scopeCode: "ceiling_repair_required", unit: UnitType.allowance.rawValue),
                QuoteScopeItemSeed("Ceiling Painting Required", scopeCode: "ceiling_painting_required", unit: UnitType.squareFoot.rawValue)
            ]
        case "Doors / Windows":
            return [
                QuoteScopeItemSeed("Interior Door Replacement", scopeCode: "doors_interior_replace", unit: UnitType.door.rawValue),
                QuoteScopeItemSeed("Exterior Door Replacement", scopeCode: "doors_exterior_replace", unit: UnitType.door.rawValue),
                QuoteScopeItemSeed("Patio / Sliding Door", scopeCode: "doors_patio_sliding", unit: UnitType.door.rawValue),
                QuoteScopeItemSeed("Closet Door Replacement", scopeCode: "doors_closet_replace", unit: UnitType.door.rawValue),
                QuoteScopeItemSeed("Door Hardware Required", scopeCode: "doors_hardware_required", unit: UnitType.each.rawValue),
                QuoteScopeItemSeed("Door Trim Required", scopeCode: "doors_trim_required", unit: UnitType.linearFoot.rawValue),
                QuoteScopeItemSeed("Window Replacement", scopeCode: "windows_replace", unit: UnitType.window.rawValue),
                QuoteScopeItemSeed("Egress Window", scopeCode: "windows_egress", unit: UnitType.window.rawValue, riskFlags: ["Permit review may be required."]),
                QuoteScopeItemSeed("Enlarge Window Opening", scopeCode: "windows_enlarge_opening", unit: UnitType.opening.rawValue, riskFlags: ["Structural review may be required."]),
                QuoteScopeItemSeed("New Window Opening", scopeCode: "windows_new_opening", unit: UnitType.opening.rawValue, riskFlags: ["Permit and structural review may be required."]),
                QuoteScopeItemSeed("Window Trim Required", scopeCode: "windows_trim_required", unit: UnitType.linearFoot.rawValue),
                QuoteScopeItemSeed("Window Covering Required", scopeCode: "windows_covering_required", unit: UnitType.window.rawValue)
            ]
        case "Electrical":
            return electricalSeeds
        case "Plumbing / HVAC":
            return plumbingHVACSeeds
        case "Kitchen":
            return kitchenSeeds
        case "Bathroom":
            return bathroomSeeds
        case "Bedroom":
            return [
                QuoteScopeItemSeed("Closet Work Required", scopeCode: "bedroom_closet_work", unit: UnitType.each.rawValue),
                QuoteScopeItemSeed("Closet Doors Replace", scopeCode: "bedroom_closet_doors", unit: UnitType.door.rawValue),
                QuoteScopeItemSeed("Closet Organizer Required", scopeCode: "bedroom_closet_organizer", unit: UnitType.each.rawValue),
                QuoteScopeItemSeed("Add Bedroom Lighting", scopeCode: "bedroom_lighting", unit: UnitType.light.rawValue),
                QuoteScopeItemSeed("Add Ceiling Fan", scopeCode: "bedroom_ceiling_fan", unit: UnitType.fixture.rawValue, riskFlags: ["Electrical review may be required."]),
                QuoteScopeItemSeed("Add Outlets", scopeCode: "bedroom_outlets", unit: UnitType.outlet.rawValue),
                QuoteScopeItemSeed("Flooring Replace", scopeCode: "bedroom_flooring", unit: UnitType.squareFoot.rawValue),
                QuoteScopeItemSeed("Painting Required", scopeCode: "bedroom_painting", unit: UnitType.squareFoot.rawValue),
                QuoteScopeItemSeed("Window Covering Required", scopeCode: "bedroom_window_covering", unit: UnitType.window.rawValue)
            ]
        case "Basement":
            return basementSeeds
        case "Whole House":
            return wholeHouseSeeds
        case "Exterior":
            return exteriorSeeds
        case "Condo Management Requirements":
            return [
                QuoteScopeItemSeed("Elevator Booking Required", scopeCode: "condo_elevator_booking", unit: UnitType.allowance.rawValue),
                QuoteScopeItemSeed("Parking / Loading Access", scopeCode: "condo_parking_loading", unit: UnitType.allowance.rawValue),
                QuoteScopeItemSeed("Building Management Approval", scopeCode: "condo_management_approval", unit: UnitType.allowance.rawValue),
                QuoteScopeItemSeed("Delivery Restriction Review", scopeCode: "condo_delivery_restriction", unit: UnitType.allowance.rawValue),
                QuoteScopeItemSeed("Common Area Protection", scopeCode: "condo_common_area_protection", unit: UnitType.allowance.rawValue)
            ]
        default:
            return [
                QuoteScopeItemSeed("Cleanup / Disposal", scopeCode: "cleanup_disposal", unit: UnitType.allowance.rawValue),
                QuoteScopeItemSeed("Other Scope Item", scopeCode: "other_scope_item", unit: UnitType.allowance.rawValue)
            ]
        }
    }

    private static let electricalSeeds = [
        QuoteScopeItemSeed("Electrical Work Required", scopeCode: "electrical_required", unit: UnitType.allowance.rawValue, riskFlags: ["Licensed electrician review may be required."]),
        QuoteScopeItemSeed("Add Outlet", scopeCode: "electrical_add_outlet", unit: UnitType.outlet.rawValue),
        QuoteScopeItemSeed("Add Switch", scopeCode: "electrical_add_switch", unit: UnitType.each.rawValue),
        QuoteScopeItemSeed("Add Pot Lights", scopeCode: "electrical_add_pot_lights", unit: UnitType.light.rawValue),
        QuoteScopeItemSeed("Add Ceiling Light", scopeCode: "electrical_add_ceiling_light", unit: UnitType.light.rawValue),
        QuoteScopeItemSeed("Add Wall Sconce", scopeCode: "electrical_add_sconce", unit: UnitType.light.rawValue),
        QuoteScopeItemSeed("Under Cabinet Lighting", scopeCode: "electrical_under_cabinet_lighting", unit: UnitType.linearFoot.rawValue),
        QuoteScopeItemSeed("Dedicated Circuit Required", scopeCode: "electrical_dedicated_circuit", unit: UnitType.each.rawValue, riskFlags: ["Licensed electrician review may be required."]),
        QuoteScopeItemSeed("Panel Upgrade May Be Required", scopeCode: "electrical_panel_upgrade", unit: UnitType.allowance.rawValue, riskFlags: ["Electrical panel review required."]),
        QuoteScopeItemSeed("Smart Switch / Dimmer Required", scopeCode: "electrical_smart_dimmer", unit: UnitType.each.rawValue),
        QuoteScopeItemSeed("Existing Wiring Concern", scopeCode: "electrical_wiring_concern", unit: UnitType.allowance.rawValue, riskFlags: ["Existing wiring concern needs professional review."]),
        QuoteScopeItemSeed("ESA Inspection May Be Required", scopeCode: "electrical_esa_inspection", unit: UnitType.allowance.rawValue, riskFlags: ["ESA inspection may be required."])
    ]

    private static let plumbingHVACSeeds = [
        QuoteScopeItemSeed("Plumbing Work Required", scopeCode: "plumbing_required", unit: UnitType.allowance.rawValue, riskFlags: ["Licensed plumber review may be required."]),
        QuoteScopeItemSeed("Sink Relocation", scopeCode: "plumbing_sink_relocation", unit: UnitType.fixture.rawValue),
        QuoteScopeItemSeed("Toilet Relocation", scopeCode: "plumbing_toilet_relocation", unit: UnitType.fixture.rawValue),
        QuoteScopeItemSeed("Shower Relocation", scopeCode: "plumbing_shower_relocation", unit: UnitType.fixture.rawValue),
        QuoteScopeItemSeed("Bathtub Relocation", scopeCode: "plumbing_bathtub_relocation", unit: UnitType.fixture.rawValue),
        QuoteScopeItemSeed("Laundry Relocation", scopeCode: "plumbing_laundry_relocation", unit: UnitType.fixture.rawValue),
        QuoteScopeItemSeed("New Drain Required", scopeCode: "plumbing_new_drain", unit: UnitType.each.rawValue),
        QuoteScopeItemSeed("New Water Line Required", scopeCode: "plumbing_new_water_line", unit: UnitType.each.rawValue),
        QuoteScopeItemSeed("Rough-In Required", scopeCode: "plumbing_rough_in", unit: UnitType.allowance.rawValue),
        QuoteScopeItemSeed("Shutoff Valve Required", scopeCode: "plumbing_shutoff_valve", unit: UnitType.fixture.rawValue),
        QuoteScopeItemSeed("Vent Relocation", scopeCode: "hvac_vent_relocation", unit: UnitType.each.rawValue),
        QuoteScopeItemSeed("Add Vent", scopeCode: "hvac_add_vent", unit: UnitType.each.rawValue),
        QuoteScopeItemSeed("Exhaust Fan Required", scopeCode: "hvac_exhaust_fan", unit: UnitType.fixture.rawValue),
        QuoteScopeItemSeed("Range Hood Vent Required", scopeCode: "hvac_range_hood_vent", unit: UnitType.fixture.rawValue),
        QuoteScopeItemSeed("Dryer Vent Required", scopeCode: "hvac_dryer_vent", unit: UnitType.fixture.rawValue),
        QuoteScopeItemSeed("Cold Air Return Required", scopeCode: "hvac_cold_air_return", unit: UnitType.each.rawValue)
    ]

    private static let kitchenSeeds = [
        QuoteScopeItemSeed("Kitchen Layout Change", scopeCode: "kitchen_layout_change", unit: UnitType.allowance.rawValue),
        QuoteScopeItemSeed("Wall Removal", scopeCode: "kitchen_wall_removal", unit: UnitType.allowance.rawValue, riskFlags: ["Structural wall concern needs review."]),
        QuoteScopeItemSeed("Engineer Review", scopeCode: "kitchen_engineer_review", unit: UnitType.allowance.rawValue, riskFlags: ["Engineer review required."]),
        QuoteScopeItemSeed("Kitchen Island", scopeCode: "kitchen_island", unit: UnitType.each.rawValue),
        QuoteScopeItemSeed("Peninsula", scopeCode: "kitchen_peninsula", unit: UnitType.each.rawValue),
        QuoteScopeItemSeed("Pantry", scopeCode: "kitchen_pantry", unit: UnitType.each.rawValue),
        QuoteScopeItemSeed("Upper Cabinets", scopeCode: "kitchen_upper_cabinets", unit: UnitType.linearFoot.rawValue),
        QuoteScopeItemSeed("Lower Cabinets", scopeCode: "kitchen_lower_cabinets", unit: UnitType.linearFoot.rawValue),
        QuoteScopeItemSeed("Tall Pantry Cabinet", scopeCode: "kitchen_tall_pantry", unit: UnitType.each.rawValue),
        QuoteScopeItemSeed("Cabinet Hardware", scopeCode: "kitchen_cabinet_hardware", unit: UnitType.each.rawValue),
        QuoteScopeItemSeed("Crown Molding", scopeCode: "kitchen_crown_molding", unit: UnitType.linearFoot.rawValue),
        QuoteScopeItemSeed("Light Valance", scopeCode: "kitchen_light_valance", unit: UnitType.linearFoot.rawValue),
        QuoteScopeItemSeed("Countertop", scopeCode: "kitchen_countertop", unit: UnitType.squareFoot.rawValue),
        QuoteScopeItemSeed("Waterfall Island", scopeCode: "kitchen_waterfall_island", unit: UnitType.each.rawValue),
        QuoteScopeItemSeed("Sink Cutout", scopeCode: "kitchen_sink_cutout", unit: UnitType.each.rawValue),
        QuoteScopeItemSeed("Cooktop Cutout", scopeCode: "kitchen_cooktop_cutout", unit: UnitType.each.rawValue),
        QuoteScopeItemSeed("Backsplash", scopeCode: "kitchen_backsplash", unit: UnitType.squareFoot.rawValue),
        QuoteScopeItemSeed("Appliance Relocation", scopeCode: "kitchen_appliance_relocation", unit: UnitType.allowance.rawValue),
        QuoteScopeItemSeed("Gas Line Required", scopeCode: "kitchen_gas_line", unit: UnitType.allowance.rawValue, riskFlags: ["Licensed gas fitter review may be required."]),
        QuoteScopeItemSeed("Water Line for Fridge", scopeCode: "kitchen_fridge_water_line", unit: UnitType.each.rawValue)
    ]

    private static let bathroomSeeds = [
        QuoteScopeItemSeed("Full Gut Required", scopeCode: "bathroom_full_gut", unit: UnitType.room.rawValue),
        QuoteScopeItemSeed("Bathroom Layout Change", scopeCode: "bathroom_layout_change", unit: UnitType.allowance.rawValue),
        QuoteScopeItemSeed("Waterproofing Required", scopeCode: "bathroom_waterproofing", unit: UnitType.squareFoot.rawValue),
        QuoteScopeItemSeed("Heated Floor Required", scopeCode: "bathroom_heated_floor", unit: UnitType.squareFoot.rawValue, riskFlags: ["Licensed electrician review may be required."]),
        QuoteScopeItemSeed("Toilet Replace", scopeCode: "bathroom_toilet_replace", unit: UnitType.fixture.rawValue),
        QuoteScopeItemSeed("Vanity Replace", scopeCode: "bathroom_vanity_replace", unit: UnitType.fixture.rawValue),
        QuoteScopeItemSeed("Sink / Faucet Replace", scopeCode: "bathroom_sink_faucet_replace", unit: UnitType.fixture.rawValue),
        QuoteScopeItemSeed("Mirror / Medicine Cabinet", scopeCode: "bathroom_mirror_medicine", unit: UnitType.fixture.rawValue),
        QuoteScopeItemSeed("Bathtub Replace", scopeCode: "bathroom_bathtub_replace", unit: UnitType.fixture.rawValue),
        QuoteScopeItemSeed("Shower Replace", scopeCode: "bathroom_shower_replace", unit: UnitType.fixture.rawValue),
        QuoteScopeItemSeed("Tub to Shower Conversion", scopeCode: "bathroom_tub_to_shower", unit: UnitType.fixture.rawValue),
        QuoteScopeItemSeed("Glass Shower Door", scopeCode: "bathroom_glass_shower_door", unit: UnitType.fixture.rawValue),
        QuoteScopeItemSeed("Shower Niche", scopeCode: "bathroom_shower_niche", unit: UnitType.each.rawValue),
        QuoteScopeItemSeed("Shower Bench", scopeCode: "bathroom_shower_bench", unit: UnitType.each.rawValue),
        QuoteScopeItemSeed("Floor Tile", scopeCode: "bathroom_floor_tile", unit: UnitType.squareFoot.rawValue),
        QuoteScopeItemSeed("Wall Tile", scopeCode: "bathroom_wall_tile", unit: UnitType.squareFoot.rawValue),
        QuoteScopeItemSeed("Shower Wall Tile", scopeCode: "bathroom_shower_wall_tile", unit: UnitType.squareFoot.rawValue),
        QuoteScopeItemSeed("Bathroom Fan", scopeCode: "bathroom_fan", unit: UnitType.fixture.rawValue),
        QuoteScopeItemSeed("Plumbing Rough-In", scopeCode: "bathroom_plumbing_rough_in", unit: UnitType.allowance.rawValue, riskFlags: ["Licensed plumber review may be required."])
    ]

    private static let basementSeeds = [
        QuoteScopeItemSeed("Basement Moisture / Mold Review", scopeCode: "basement_moisture_mold_review", unit: UnitType.allowance.rawValue, riskFlags: ["Moisture or mold concern needs review."]),
        QuoteScopeItemSeed("Framing Required", scopeCode: "basement_framing", unit: UnitType.linearFoot.rawValue),
        QuoteScopeItemSeed("Insulation Required", scopeCode: "basement_insulation", unit: UnitType.squareFoot.rawValue),
        QuoteScopeItemSeed("Drywall Required", scopeCode: "basement_drywall", unit: UnitType.squareFoot.rawValue),
        QuoteScopeItemSeed("Flooring Required", scopeCode: "basement_flooring", unit: UnitType.squareFoot.rawValue),
        QuoteScopeItemSeed("Bathroom Rough-In", scopeCode: "basement_bathroom_rough_in", unit: UnitType.allowance.rawValue),
        QuoteScopeItemSeed("Kitchen / Bar Rough-In", scopeCode: "basement_kitchen_bar_rough_in", unit: UnitType.allowance.rawValue),
        QuoteScopeItemSeed("Add Bedroom", scopeCode: "basement_add_bedroom", unit: UnitType.room.rawValue),
        QuoteScopeItemSeed("Add Egress Window", scopeCode: "basement_egress_window", unit: UnitType.window.rawValue, riskFlags: ["Permit review may be required."]),
        QuoteScopeItemSeed("Electrical Upgrade", scopeCode: "basement_electrical_upgrade", unit: UnitType.allowance.rawValue, riskFlags: ["Licensed electrician review may be required."]),
        QuoteScopeItemSeed("Laundry Work", scopeCode: "basement_laundry_work", unit: UnitType.allowance.rawValue),
        QuoteScopeItemSeed("Staircase Work", scopeCode: "basement_staircase_work", unit: UnitType.allowance.rawValue),
        QuoteScopeItemSeed("Legal Basement Review", scopeCode: "basement_legal_review", unit: UnitType.allowance.rawValue, riskFlags: ["Legal basement / secondary suite review required."]),
        QuoteScopeItemSeed("Permit Required", scopeCode: "basement_permit_required", unit: UnitType.allowance.rawValue, riskFlags: ["Permit may be required."]),
        QuoteScopeItemSeed("Fire Separation Required", scopeCode: "basement_fire_separation", unit: UnitType.squareFoot.rawValue, riskFlags: ["Fire separation review required."]),
        QuoteScopeItemSeed("Soundproofing Required", scopeCode: "basement_soundproofing", unit: UnitType.squareFoot.rawValue)
    ]

    private static let wholeHouseSeeds = [
        QuoteScopeItemSeed("Full Flooring Replacement", scopeCode: "whole_house_flooring", unit: UnitType.squareFoot.rawValue),
        QuoteScopeItemSeed("Full Painting", scopeCode: "whole_house_painting", unit: UnitType.squareFoot.rawValue),
        QuoteScopeItemSeed("Trim / Baseboard Replacement", scopeCode: "whole_house_trim_baseboard", unit: UnitType.linearFoot.rawValue),
        QuoteScopeItemSeed("Interior Doors Replacement", scopeCode: "whole_house_interior_doors", unit: UnitType.door.rawValue),
        QuoteScopeItemSeed("Kitchen Renovation", scopeCode: "whole_house_kitchen", unit: UnitType.room.rawValue),
        QuoteScopeItemSeed("Bathrooms Renovation", scopeCode: "whole_house_bathrooms", unit: UnitType.room.rawValue),
        QuoteScopeItemSeed("Staircase Renovation", scopeCode: "whole_house_staircase", unit: UnitType.allowance.rawValue),
        QuoteScopeItemSeed("Electrical Upgrade", scopeCode: "whole_house_electrical", unit: UnitType.allowance.rawValue, riskFlags: ["Licensed electrician review may be required."]),
        QuoteScopeItemSeed("Plumbing Upgrade", scopeCode: "whole_house_plumbing", unit: UnitType.allowance.rawValue, riskFlags: ["Licensed plumber review may be required."]),
        QuoteScopeItemSeed("HVAC Review", scopeCode: "whole_house_hvac", unit: UnitType.allowance.rawValue),
        QuoteScopeItemSeed("Structural Changes", scopeCode: "whole_house_structural", unit: UnitType.allowance.rawValue, riskFlags: ["Structural review required."]),
        QuoteScopeItemSeed("Permit Review Required", scopeCode: "whole_house_permit", unit: UnitType.allowance.rawValue, riskFlags: ["Permit review required."])
    ]

    private static let exteriorSeeds = [
        QuoteScopeItemSeed("Exterior Painting", scopeCode: "exterior_painting", unit: UnitType.squareFoot.rawValue),
        QuoteScopeItemSeed("Deck Repair / Build", scopeCode: "exterior_deck", unit: UnitType.allowance.rawValue),
        QuoteScopeItemSeed("Fence Repair / Build", scopeCode: "exterior_fence", unit: UnitType.linearFoot.rawValue),
        QuoteScopeItemSeed("Exterior Door Replace", scopeCode: "exterior_door_replace", unit: UnitType.door.rawValue),
        QuoteScopeItemSeed("Exterior Lighting", scopeCode: "exterior_lighting", unit: UnitType.light.rawValue, riskFlags: ["Licensed electrician review may be required."]),
        QuoteScopeItemSeed("Porch / Exterior Stairs", scopeCode: "exterior_porch_stairs", unit: UnitType.allowance.rawValue),
        QuoteScopeItemSeed("Driveway", scopeCode: "exterior_driveway", unit: UnitType.allowance.rawValue),
        QuoteScopeItemSeed("Siding", scopeCode: "exterior_siding", unit: UnitType.squareFoot.rawValue),
        QuoteScopeItemSeed("Roof Related", scopeCode: "exterior_roof_related", unit: UnitType.allowance.rawValue)
    ]

    private static let materialOptionsByScope: [String: [String]] = [
        "flooring_required": ["Vinyl Plank", "Laminate", "Engineered Hardwood", "Hardwood", "Porcelain Tile", "Ceramic Tile", "Carpet", "Epoxy", "Concrete Finish", "Other"],
        "basement_flooring": ["Vinyl Plank", "Laminate", "Carpet", "Tile", "Epoxy", "Concrete Finish", "Other"],
        "bedroom_flooring": ["Vinyl Plank", "Laminate", "Engineered Hardwood", "Hardwood", "Carpet", "Other"],
        "whole_house_flooring": ["Vinyl Plank", "Laminate", "Engineered Hardwood", "Hardwood", "Porcelain Tile", "Ceramic Tile", "Carpet", "Other"],
        "kitchen_countertop": ["Quartz", "Granite", "Marble", "Laminate", "Butcher Block", "Porcelain Slab", "Other"],
        "kitchen_backsplash": ["Ceramic Tile", "Porcelain Tile", "Subway Tile", "Mosaic", "Stone", "Quartz Slab", "Other"],
        "bathroom_floor_tile": ["Ceramic", "Porcelain", "Marble", "Mosaic", "Other"],
        "bathroom_wall_tile": ["Ceramic", "Porcelain", "Marble", "Mosaic", "Other"],
        "bathroom_shower_wall_tile": ["Ceramic", "Porcelain", "Marble", "Mosaic", "Other"],
        "painting_required": ["Paint", "Primer + Paint", "Wallpaper", "Paneling", "Wainscoting", "Other"],
        "ceiling_work_required": ["Drywall Ceiling", "Drop Ceiling", "Smooth Ceiling", "Popcorn Removal", "Ceiling Tile", "Other"],
        "doors_interior_replace": ["Slab Door", "Prehung Door", "French Door", "Pocket Door", "Barn Door", "Closet Door", "Other"],
        "doors_exterior_replace": ["Exterior Front Door", "Patio Door", "Garage Door", "Other"],
        "windows_replace": ["Fixed", "Casement", "Sliding", "Awning", "Bay Window", "Basement Window", "Other"],
        "windows_egress": ["Egress Window", "Basement Window", "Other"],
        "kitchen_upper_cabinets": ["Stock", "Semi-Custom", "Custom", "IKEA", "Client Supplied", "Refacing Only", "Other"],
        "kitchen_lower_cabinets": ["Stock", "Semi-Custom", "Custom", "IKEA", "Client Supplied", "Refacing Only", "Other"],
        "bathroom_vanity_replace": ["Client Supplied", "Company Supplied", "TBD"],
        "bathroom_shower_replace": ["Acrylic", "Tile Shower", "Prefab", "Custom", "Other"]
    ]
}
