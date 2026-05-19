# Visual Guide: Points Breakdown UI

## Grid Mode → Points Breakdown

### Before (Tapping Card in Grid)
```
Cards Tab - Grid View
┌─────────────────────────────────┐
│ ┌─────────────────────────────┐ │
│ │  American Express Platinum  │ │
│ │  (Card Image)               │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │  Chase Sapphire Reserve     │ │ ← Tap card here
│ │  (Card Image)               │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

### After (Opens PointsBreakdownView)
```
Points Breakdown

← Points Breakdown    2026 ⬅️ ⬅️

┌─────────────────────────────────┐
│ Upload Statement      [Upload]   │ ← Upload button
└─────────────────────────────────┘

Uploaded Statements
  📄 Chase_Statement_Apr2026.pdf
     Uploaded: May 15, 2026
  📄 Chase_Statement_Mar2026.pdf
     Uploaded: April 20, 2026

Points by Category

  4X - Restaurants           1,600 pts
  4X Points on restaurants worldwide

  1X - Supermarkets            400 pts
  1X Points on supermarkets

  3X - Flights                 150 pts
  3X Points on flights booked...

  1X - Other                   200 pts
  1X Point on all other...

Action Buttons:
  [Undo Last Upload]
  [Clear All Statements]

              [Done]
```

---

## Statement Upload Flow

### Step 1: Tap Upload Button
```
Points Breakdown
  [Upload Statement]  ← User taps here
       ↓
   DocumentPicker opens
```

### Step 2: Select File
```
📱 Files App
├─ iCloud Drive/
├─ On My iPhone/
│  ├─ Documents/
│  │  └─ Chase_Statement.pdf  ← Select this
│  ├─ Downloads/
│  └─ ...
└─ ...

User selects file from device
```

### Step 3: Parse & Save
```
System:
1. Extracts transactions from PDF/CSV
2. Creates StatementRow for each transaction
   - Date: May 5, 2026
   - Category: Restaurants
   - Amount: $75.00
3. Groups by category
4. Saves to database
5. Calculates upload hash (prevents duplicates)
```

### Step 4: Display Results
```
Points Breakdown updated:

Uploaded Statements
  📄 Chase_Statement.pdf
     Uploaded: Today 2:30 PM

Points by Category
  4X - Restaurants           $75 → 300 pts
  (New calculation includes uploaded statement)
```

---

## Points Calculation Example

### Example Card: Amex Gold
Multipliers:
- 4X Restaurants
- 4X Supermarkets
- 3X Flights
- 5X Hotels
- 1X Other

### Example Statement
```
May 2026 Transactions:
  5/1  Whole Foods          $50    → Supermarket
  5/5  Le Bernardin        $120    → Restaurant
  5/8  United Airlines     $450    → Flight
  5/15 Four Seasons       $200    → Hotel
  5/20 Amazon             $30     → Other
```

### Points Calculation
```
Restaurants:
  $120 × 4X = 480 points

Supermarkets:
  $50 × 4X = 200 points

Flights:
  $450 × 3X = 1,350 points

Hotels:
  $200 × 5X = 1,000 points

Other:
  $30 × 1X = 30 points

─────────────────────
TOTAL: 3,060 points
```

### Display in Points Breakdown
```
Points by Category

  4X - Restaurants               480 pts
  4X Points on restaurants worldwide

  4X - Supermarkets              200 pts
  4X Points at U.S. supermarkets

  3X - Flights                 1,350 pts
  3X Points on flights booked...

  5X - Hotels                  1,000 pts
  5X Points on prepaid hotels...

  1X - Other                      30 pts
  1X Point on all other...

TOTAL POINTS THIS YEAR: 3,060
```

---

## Year Selection

### Year Stepper
```
Points Breakdown

← Points Breakdown    2026 ⬅️ ⬅️  

Select Year: 2020 ← 2026 → 2030
             ⬅️        ➡️
```

### What Changes
```
2024:
  Statements: 15
  Total Points: 18,500

2025:
  Statements: 8
  Total Points: 12,300

2026:
  Statements: 3
  Total Points: 3,060

User can view each year independently
```

---

## Statement Management

### Uploaded Statements List
```
Uploaded Statements (Year 2026)

📄 Chase_Statement_Apr2026.pdf
   Uploaded: April 20, 2026
   Transactions: 23
   Total Spent: $2,400

📄 Chase_Statement_Mar2026.pdf
   Uploaded: March 18, 2026
   Transactions: 19
   Total Spent: $1,800

[Tap to download/view original file]
```

### Actions

#### Undo Last Upload
```
Before:
  Uploaded Statements: 3
  Points: 3,060

User taps: [Undo Last Upload]

After:
  Uploaded Statements: 2
  Points: 2,400  (latest statement removed)
  
Undo restored to previous state
(Only 1 level - subsequent uploads overwrite undo)
```

#### Clear All Statements
```
Before:
  Statements: 3
  Points: 3,060

User taps: [Clear All Statements]

[Alert: "Remove all statements for this card?"]
[Cancel] [Clear]

After (if confirmed):
  Statements: 0
  Points: 0
  (All data deleted for this card)
```

---

## Multiple Cards

### Cards with Different Multipliers
```
CARD 1: Amex Gold
Restaurants:    4X
Supermarkets:   4X
Flights:        3X
Hotels:         5X
Other:          1X

Points Breakdown:
  Restaurant:   $200 × 4X = 800
  Supermarket:  $100 × 4X = 400
  Flights:      $400 × 3X = 1,200
  Hotels:       $150 × 5X = 750
  Other:        $50 × 1X = 50
  TOTAL: 3,200 points

─────────────────────────────────

CARD 2: Chase Sapphire Reserve
Restaurants:    3X
Supermarkets:   1X
Flights:        5X
Hotels:         5X
Other:          1X

Points Breakdown:
  Restaurant:   $200 × 3X = 600
  Supermarket:  $100 × 1X = 100
  Flights:      $400 × 5X = 2,000
  Hotels:       $150 × 5X = 750
  Other:        $50 × 1X = 50
  TOTAL: 3,500 points

Each card tracks independently
```

---

## Edge Cases

### Duplicate Statement Upload
```
User selects: Chase_Statement_May2026.pdf
System calculates hash:
  MD5("chase_xyz" + "Chase_Statement_May2026.pdf" + "2026-05-15")

Check database for same hash...
FOUND! Statement already exists.

Result: Upload rejected
Message: "This statement has already been uploaded"
No duplicate points added
```

### Year with No Statements
```
User selects: 2020
Year 2020 has 0 statements

Display:
Points by Category

  4X - Restaurants               0 pts
  4X Points on restaurants worldwide

  4X - Supermarkets              0 pts
  4X Points at U.S. supermarkets

  ...all categories show 0...

Total Points: 0
Message: "Upload statements to see points"
```

### Statement with Mixed Categories
```
Uploaded: May 2026 statement

Transactions detected:
✓ Restaurant         $120
✓ Supermarket        $50
✓ Pharmacy           $30  ← Non-categorized
✓ Flight             $450
✓ Hotel              $200
? Unknown            $100  ← Needs categorization

System prompts:
"Please categorize 2 transactions"

User selects:
  Pharmacy → Restaurant (healthcare spending)
  Unknown → Other

Statement saves with all categories assigned
```

---

## Summary

✅ **Intuitive Flow:** Upload → Auto-calculate → View breakdown  
✅ **Year-based:** Easy to see earning by year  
✅ **Category Breakdown:** See which categories earn most  
✅ **Duplicate Prevention:** Smart hash-based detection  
✅ **Data Management:** Undo & clear options  
✅ **Visual Feedback:** Clear point display per category  

**UX Rating:** ⭐⭐⭐⭐⭐ (Clean, intuitive, efficient)
