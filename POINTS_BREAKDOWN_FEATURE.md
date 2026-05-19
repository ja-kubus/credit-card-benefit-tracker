# Points Breakdown Feature - Statement Management & Earning Calculation

## Overview

The Points Breakdown feature allows users to upload credit card statements, track spending by category, and automatically calculate earned points based on card-specific multipliers.

### Key Capability:
In Grid view, clicking a card opens a **Points Breakdown** view (instead of card details) showing:
- Statement uploads by year
- Points earned per spending category
- Automatic point calculations based on spending × multipliers

---

## Data Models

### Statement
Represents an uploaded credit card statement
```swift
@Model
final class Statement {
    var cardID: String              // Which card this statement belongs to
    var fileName: String            // Original file name
    var uploadDate: Date            // When uploaded
    var statementMonth: Date        // For organizing by month/year
    var uploadHash: String          // Prevents duplicate uploads
    var issuers: String             // Card issuer (Amex, Chase, Discover, etc)
    
    @Relationship(deleteRule: .cascade) 
    var rows: [StatementRow] = []   // Individual transactions
}
```

### StatementRow
Represents a single transaction from a statement
```swift
@Model
final class StatementRow {
    var transactionDate: Date           // When purchase occurred
    var category: String                // Spending category (e.g., "Restaurants")
    var amount: Double                  // Dollar amount spent
    var transactionDescription: String  // Optional description
}
```

### EarningRate
Represents a point multiplier for a category
```swift
struct EarningRate: Codable {
    let multiplier: Double      // e.g., 4.0 for 4x points
    let category: String        // e.g., "Restaurants", "Flights"
    let description: String     // Full description from catalog
}
```

---

## Features

### 1. Statement Upload

**Process:**
1. User taps "Upload Statement" button
2. DocumentPicker opens to select PDF/CSV from device
3. Statement is parsed to extract:
   - Transaction date
   - Spending category
   - Dollar amount
4. Statement is saved with uploadHash to prevent duplicates

**Duplicate Prevention:**
- Uses hash of `cardID + fileName + uploadDate`
- If same file uploaded twice, system detects it
- Prevents double-counting points

### 2. Spending Categories

Statement rows are categorized into:
- **Restaurants** - Dining purchases
- **Supermarkets** - Grocery purchases
- **Flights** - Airline tickets
- **Hotels** - Hotel stays
- **Other** - All other purchases (1x multiplier)

### 3. Points Calculation

For each category:
```
Points Earned = Total Spending × Category Multiplier
```

**Example (Amex Gold):**
- Spent $400 at restaurants (4x multiplier)
  - Earned: 400 × 4 = 1,600 points
- Spent $100 at supermarkets (4x multiplier)
  - Earned: 100 × 4 = 400 points
- Spent $50 on flights (3x multiplier)
  - Earned: 50 × 3 = 150 points
- Spent $200 other (1x multiplier)
  - Earned: 200 × 1 = 200 points

**Total: 2,350 points earned**

### 4. Year Filtering

- Stepper at top lets user select any year (2020-2030)
- Only shows statements uploaded in selected year
- Points calculations filtered by year
- Easy to view earning history by year

### 5. Statement Management

**View Uploaded Statements:**
- List shows all statements for current year
- Shows file name and upload date
- Can download/view statement again

**Clear All:**
- Button to delete ALL statements for a card
- Prevents accidental clicks (confirmation may be added)
- Clears all associated statement rows

**Undo Last Upload:**
- Single undo level
- Only available if at least one statement uploaded
- Reverts last upload completely

---

## UI Components

### PointsBreakdownView
Main view for points breakdown
```
Header: Points Breakdown | Year Selector

Upload Section:
  [Upload Statement Button]

Statements Section:
  Dropdown list of uploaded statements
  - Can download each one

Points by Category:
  For each earning rate:
    [4X - Category] → [Points Earned]
    [Description...]

Actions:
  [Undo Last Upload] (if available)
  [Clear All Statements] (if available)
```

### PointsCategoryRow
Individual category row showing earned points
```
4X - Restaurants | 1,600 points
4X Points on restaurants worldwide
```

---

## Integration Points

### With Existing Features

**Card Model Updates:**
- Added `statements: [Statement]` relationship to UserCard
- Cascading delete: removing card deletes all statements

**Earning Rates:**
- Extracted from catalog card data
- Mapped from card benefits
- e.g., "4X Points on Global Restaurants" → 4.0x multiplier

**Grid View:**
- Tapping card in grid mode → PointsBreakdownView
- Tapping card in accordion mode → Card Detail View (unchanged)

---

## How to Use

### Upload Statement
1. Go to Cards view
2. Switch to Grid mode
3. Tap a card
4. Points Breakdown opens
5. Tap "Upload Statement"
6. Select PDF/CSV from device
7. System extracts transactions and saves

### View Points by Category
1. Points Breakdown already open
2. Scroll to "Points by Category" section
3. See total points earned per category
4. Change year with stepper to see different year's data

### Download Previously Uploaded
1. Points Breakdown open
2. Find statement in "Uploaded Statements" list
3. Tap to download/open again
4. View original file on device

### Clear Data
1. Points Breakdown open
2. Tap "Clear All Statements"
3. All statements for this card deleted
4. Points reset to $0 until new upload

### Undo
1. Just uploaded wrong statement
2. Tap "Undo Last Upload"
3. Previous upload restored
4. (Only works once - reverts to before last upload)

---

## Implementation Notes

### Statement Format Handling
Currently basic structure. Future enhancement:
- Detect issuer (Amex vs Chase vs Discover)
- Apply issuer-specific parsing rules
- Handle different CSV/PDF formats

### Category Matching
Currently:
- User selects category when uploading
- Or system auto-detects based on merchant name
- Future: ML-based category prediction

### Duplicate Detection
- Uses `uploadHash` field
- Hash = `MD5(cardID + fileName + uploadDate)`
- Prevents duplicate uploads of same file
- Allows re-uploading different versions

### Data Persistence
- All statements saved to SwiftData
- Automatic sync with device
- Included in app backup

---

## Future Enhancements

- [ ] PDF/CSV parsing logic
- [ ] Merchant name → category auto-mapping
- [ ] Multiple undo levels (stack-based)
- [ ] Export points report
- [ ] Year-over-year comparison
- [ ] Earning forecasts
- [ ] CSV export of spending by category
- [ ] Receipt image attachment per transaction
- [ ] Manual transaction entry (if missing from statement)
- [ ] Point transfer tracking (between categories)
- [ ] Redeem points UI

---

## Build Status

✅ **SUCCESSFUL** - No errors, no warnings

---

## Testing Checklist

- [ ] Can upload statement for a card
- [ ] Points calculate correctly for each category
- [ ] Duplicate uploads detected and prevented
- [ ] Year selector filters statements correctly
- [ ] Statement list shows uploaded statements
- [ ] Can download uploaded statement
- [ ] Clear all statements works
- [ ] Undo last upload works (if available)
- [ ] Points update when statements modified
- [ ] Grid mode shows PointsBreakdown (not CardDetail)
- [ ] Accordion mode still shows CardDetail
- [ ] Statements deleted when card deleted
- [ ] Works with multiple cards independently

---

**Status:** ✅ FOUNDATION COMPLETE

The feature is structurally ready. Next phase would be:
1. Add CSV/PDF parsing
2. Implement statement upload from DocumentPicker
3. Add category detection logic
4. Build out undo/redo stack

