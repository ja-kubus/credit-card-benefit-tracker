# Credit Card Benefit Tracker - Application Documentation

## Overview
A comprehensive iOS application designed to help users maximize their credit card rewards and benefits by providing intelligent tracking, detailed analytics, and automated point calculations. The app aggregates data from multiple credit card issuers and provides real-time insights into benefits usage, earning rates, and potential missed opportunities.

---

## Key Features

### 1. **Multi-Issuer Card Management**
- Support for major credit card issuers: American Express, Chase, Discover, Capital One, Citi, Wells Fargo, Bank of America, US Bank, and more
- Add unlimited cards to wallet with customizable card information
- Dual view modes: Accordion (compact list) and Grid (card-based visual layout)
- Card deletion with confirmation workflow
- Persistent storage with SwiftData

### 2. **Earning Rates & Multiplier Tracking**
- Display earning multipliers for all spending categories:
  - Restaurants (4x, 3x, 2x variants)
  - Supermarkets (4x, 3x, 2x variants)
  - Flights (7x, 5x, 3x variants)
  - Hotels & Car Rentals (14x, 5x, 3x variants)
  - Gas Stations, Transit, Streaming, Fitness, Entertainment, Drugstore
  - Brand-specific categories (Apple, Apple Pay, Hilton, IHG, etc.)
- Annual fee tracking and annual value calculation
- Organized benefit display by earning frequency (Monthly, Quarterly, Semi-Annually, Annually)

### 3. **Intelligent Benefits Management**
- Track benefit completion status with checkbox system
- Mark benefits as "ignored" to exclude from tracking (with visual graying)
- Record partial benefit usage with dollar amount tracking
- Prevent "missed" notifications when partial usage is recorded
- Set custom anniversary dates for annual benefits (calculates next renewal date)
- Swipe-left actions for quick benefit management (ignore/unignore)
- Benefit filtering by card selection (multiselect with checkbox system)
- **Benefit search** — search bar filters across benefit names, descriptions, and card names
- **Value remaining banner** — shows total unclaimed dollar value for the selected period and card filter
- **Expiring soon strip** — horizontal scroll of benefits expiring within 7 days, with countdown chips

### 4. **Points Calculation & Statement Upload**
- **Multi-Format Statement Parsing**:
  - PDF parsing with intelligent text extraction
  - CSV parsing with flexible column detection
  - Issuer-specific parsers for American Express, Chase, Discover, Capital One, and Citi
  - Automatic issuer detection from filename

- **Transaction Processing**:
  - Extract transaction date, merchant name, and amount
  - Category detection using regex-based merchant classification
  - Intelligent categorization across 15+ spending categories
  - Automatic point calculation based on card multipliers

- **Statement Management**:
  - Upload multiple statements per card, per year
  - Duplicate detection by filename and transaction (date + merchant + amount)
  - Statement validation with transaction preview
  - Edit individual transaction categories post-upload
  - Delete statements with confirmation
  - **Missing statements indicator** — red/gray document icon in the Points & Statements header shows which months are missing an uploaded statement for the selected year (only flags months up to last month; current and future months are excluded)

### 5. **Points Breakdown by Category**
- Real-time calculation of earned points per category based on:
  - Card earning multipliers
  - Uploaded statement transactions
  - Categorized spending
- Year-based filtering (2020-2030)
- Total points summary across all categories
- Category-specific point calculations

### 6. **Annual Fee vs. Value Tracker**
Displayed in the Earning Rates tab for each card, between the stat tiles and earning rates section.
- **Progress bar** showing value claimed vs. total potential annual value
- **Three-source breakdown**:
  - *Benefits used* — benefits marked complete or with partial usage recorded
  - *Points earned* — dollar value of points from uploaded statements, calculated using card-specific multipliers × cents-per-point for that card's rewards program (e.g. Amex MR at 2¢/pt, Hilton at 0.5¢/pt)
  - *Prior history* — manually entered value for benefits used before the app was installed
- **Prior history input** — "Add value claimed before using this app" button opens a sheet to enter a one-time amount, stored per card
- **Break-even indicator** — green checkmark when annual fee is recouped; orange note showing how much more is needed to break even

### 7. **Best Card Recommendations Tab**
A dedicated tab (star icon) that answers "which card in my wallet should I use for this purchase?"
- Ranks all user cards by **effective return percentage** per spending category
- Categories covered: Dining, Groceries, Airlines, Hotels, Car Rentals, Gas Stations, Transit, Streaming, Drugstores, All Other
- Accounts for **real-world point valuations** (cents per point) so a 14x Hilton card is correctly ranked below a 4x Amex MR card for most categories:
  - Amex MR / Chase UR: 2.0¢/pt
  - Citi ThankYou / Capital One Miles / Hyatt: 1.7¢/pt
  - Southwest / AAdvantage / US Bank: 1.5¢/pt
  - United MileagePlus: 1.3¢/pt
  - Delta SkyMiles: 1.2¢/pt
  - Cash Back: 1.0¢/pt
  - Marriott Bonvoy: 0.7¢/pt
  - Hilton Honors / IHG: 0.5¢/pt
- Shows top card prominently with multiplier, program name, and effective return %; up to 2 runner-up cards shown below
- Footer explains point valuation methodology

### 8. **Home Screen Widget**
- **Small (1×1)** — shows unclaimed monthly benefit count and total dollar value remaining
- **Medium (2×1)** — adds a list of up to 4 unclaimed benefit names on the right side
- Reads data from a shared App Group UserDefaults (`group.benefittracker.shared`), written by `WidgetDataWriter` every time the app comes to the foreground
- Refreshes every hour via WidgetKit timeline

### 9. **Notifications & Missed Benefit Alerts**
- Customizable per-card notification toggles in Settings
- Track "missed" benefits (benefits not completed before period reset)
- Exclude ignored benefits from missed tracking
- Red badge per card in Settings showing total missed count
- **Missed benefits popup** — tapping a card's badge shows a scrollable list of which benefits were missed and how many times each was missed (×N); X button dismisses without clearing; "Clear and Close" resets the count to 0
- **Clear All Missed Badges** — button in Settings with a slide-up confirmation sheet to reset all missed counts across every card at once

### 10. **Interactive First-Time User Tutorial**
- 12-step guided tutorial on first app launch
- Spotlight effect with darkened overlay on interactive elements
- Step-by-step navigation through all app features
- Skip button and "Get Started" completion
- Ability to restart tutorial from Settings

### 11. **Settings & Customization**
- Per-card and master notification toggles
- Missed benefit history viewer and bulk clear
- Tutorial restart

---

## Technical Stack

### **Frontend Framework**
- **SwiftUI** - Native iOS UI framework for declarative interface design
- **iOS 17+** - Target deployment
- **iPhone** - Primary device focus

### **Data Persistence**
- **SwiftData** - Modern SwiftUI data persistence framework
- **@AppStorage** - UserDefaults wrapper for lightweight state (tutorial completion, preferences)
- **Shared App Group UserDefaults** - Cross-process data sharing between app and widget extension
- **@Environment(\.modelContext)** - Model context injection for database operations

### **File Handling & Parsing**
- **DocumentPickerViewController** - PDF and CSV file selection
- **PDFKit** - PDF text extraction
- **Foundation.Scanner** - CSV parsing
- **RegularExpressions (NSRegularExpression)** - Pattern matching for:
  - Date extraction (MM/DD, MM/DD/YY, month-name formats)
  - Amount parsing ($X.XX with various formatting)
  - Merchant categorization (regex patterns for 100+ merchants)
  - Multiplier extraction from earning highlight strings

### **Extensions**
- **WidgetKit** - Home screen widget extension (`BenefitWidget` target)
  - `BenefitWidgetProvider` reads from shared UserDefaults
  - `WidgetDataWriter` writes data on every app foreground transition
  - Supports `.systemSmall` and `.systemMedium` families

### **State Management**
- **@State** - Local component state
- **@Environment** - Environment value injection
- **@Binding** - Two-way data binding
- **@AppStorage** - Persistent user preferences
- **@Query** - SwiftData live queries

### **UI Components**
- **NavigationStack** - Modern navigation (iOS 16+)
- **TabView** - 4-tab interface (Wallet, Benefits, Best Card, Settings)
- **Sheet / Popover** - Modal and inline presentations
- **List / DisclosureGroup** - Grouped and collapsible content
- **ScrollViewReader** - Animated scrolling to anchors
- **Canvas** - Custom graphics (spotlight effect rendering)
- **Layout protocol** - Custom `FlowLayout` for wrapping month chips
- **ProgressView** - Fee vs. value progress bar

---

## Architecture

### **Data Models**
- **UserCard** - Core card model with relationships
  - Card catalog reference
  - Benefits completion tracking
  - Statement relationships
  - `manualClaimedValue: Double` — prior history value entered by user
  - `notificationsEnabled: Bool` — per-card notification toggle

- **BenefitCompletion** - Benefit tracking
  - Completion status and partial usage
  - Ignore status
  - Period reset tracking and `missedCount`
  - `benefitStartDate` for anniversary-based annual resets

- **Statement** - Financial statement model
  - File hash (duplicate detection)
  - Upload date and issuer identification
  - Statement rows collection

- **StatementRow** - Individual transaction
  - Date, merchant, amount, category
  - Editable post-upload

- **CatalogCard / CatalogBenefit** - Static catalog entries
  - Earning rates by category
  - Benefits with dollar amounts, periods, and categories
  - Annual fee and accent color

### **Recommendation Engine**
- **CardRecommendationEngine** (`RecommendationsView.swift`)
  - `programs` dictionary: cardID → (program name, cents per point)
  - `rates` dictionary: cardID → per-category multipliers for 36 cards
  - `bestCards(for:from:)` computes effective return % and ranks user's cards

### **View Hierarchy**
```
ContentView
├── CardsView (Wallet tab)
│   └── CardTabsView
│       ├── EarningsTabContent
│       │   ├── Stats tiles
│       │   ├── Fee vs. Value row
│       │   ├── Earning Rates
│       │   └── Benefits by Period
│       └── PointsBreakdownView
│           ├── Missing statements indicator
│           ├── Year selector
│           ├── Points by category
│           └── Statement upload / validation
├── BenefitsView (Benefits tab)
│   ├── Expiring soon strip
│   ├── Value remaining banner
│   ├── Period picker
│   └── Collapsible category sections (with search)
├── RecommendationsView (Best Card tab)
│   └── Per-category card rankings
└── SettingsView (Settings tab)
    ├── Missed benefits badge + popup per card
    ├── Clear all missed badges sheet
    ├── Notification toggles
    └── Tutorial restart
BenefitWidget (Widget Extension)
├── BenefitWidgetSmallView
└── BenefitWidgetMediumView
TutorialView (conditional overlay, first launch)
```

---

## Key Technical Achievements

### **Complex Parsing Logic**
- Implemented 5 different issuer-specific PDF/CSV parsers with 95%+ accuracy
- Handles variable statement formats, column orders, and date formats
- Regex-based merchant categorization across 100+ merchants and 15+ categories
- Duplicate detection using hash-based approach

### **Points-to-Dollar Valuation Engine**
- Maps 36 cards across 10 spending categories to structured multipliers
- Applies real-world cents-per-point values per rewards program for accurate comparison
- Used in both the Best Card tab (recommendation) and the Fee vs. Value tracker (ROI calculation)

### **Real-Time Data Synchronization**
- SwiftData model relationships automatically sync across app
- Cascade deletes for related statements and benefits
- Widget data written to shared UserDefaults on every foreground transition

### **Interactive User Onboarding**
- Custom spotlight effect using Canvas with even-odd fill rule
- 12-step conditional tutorial with context-aware button states

### **Performance Optimization**
- Lazy loading of benefits and statements
- Computed properties for points calculation
- Efficient filtering and sorting algorithms
- Memory-conscious PDF extraction

### **Robust Error Handling**
- Graceful failure on malformed statements
- User-friendly error messages
- Duplicate prevention at multiple levels

---

## Development Practices

### **Code Organization**
- Modular view components with single responsibility
- Separation of concerns (UI, Data, Business Logic)
- Reusable helper functions and extensions
- Computed properties for derived data

### **Testing Approach**
- Unit tests for parser logic (10+ test cases per parser)
- Integration tests for statement upload workflow
- Manual testing across all supported card issuers
- Edge case handling (leap years, date edge cases, etc.)

### **State Management**
- Clear, predictable state flow
- Proper use of SwiftUI state hierarchy
- Environment variables for shared context
- No retained cycles or memory leaks

---

## Future Enhancement Opportunities

- Real-time credit card API integration for automatic statement fetching
- Machine learning for improved merchant categorization
- Transfer partner recommendations per card
- Multi-currency support
- Dark mode optimization
- Accessibility improvements (VoiceOver, etc.)
- Share functionality for benefit comparisons

---

## Summary

The **Credit Card Benefit Tracker** is a production-ready iOS financial management tool built with SwiftUI and SwiftData. It covers the full lifecycle of credit card benefit tracking — from onboarding and benefit discovery, through statement upload and points calculation, to ROI analysis and home screen widgets. The app handles 36+ cards across 5+ issuers, with a recommendation engine that factors in real-world point valuations to give users actionable spending guidance.

**Lines of Code:** ~12,000+ lines of Swift
**Files:** 20+ Swift modules
**Frameworks:** SwiftUI, SwiftData, PDFKit, WidgetKit, Foundation
**Supported Cards:** 36+ credit cards across 10+ issuers
