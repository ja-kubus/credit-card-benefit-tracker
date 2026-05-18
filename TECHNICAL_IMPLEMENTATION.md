# Technical Implementation Guide

## Feature: Partial Usage & Ignore Tracking

---

## Data Model Changes

### Before
```swift
@Model
final class BenefitCompletion {
    var cardID: String
    var benefitID: String
    var benefitName: String
    var benefitDescription: String
    var dollarAmount: Double
    var period: String
    var isCompleted: Bool
    var resetDate: Date
    var missedCount: Int = 0
    // ... init and methods
}
```

### After
```swift
@Model
final class BenefitCompletion {
    // ... existing fields ...
    var partialUsage: String = ""      // NEW: Amount used (e.g., "250")
    var isIgnored: Bool = false        // NEW: Exclude from missed tracking
    
    // NEW: Helper property
    var hasAnyUsage: Bool {
        isCompleted || !partialUsage.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // UPDATED: Reset logic
    func resetIfNeeded() {
        guard Date() >= resetDate else { return }
        // Only count as missed if NO usage AND NOT ignored
        if !hasAnyUsage && !isIgnored {
            missedCount += 1
        }
        isCompleted = false
        partialUsage = ""
        resetDate = benefitPeriod.nextResetDate(from: resetDate)
    }
}
```

### Key Changes
1. **partialUsage** - Stored as String for flexibility (allows "$250", "250.50", etc.)
2. **isIgnored** - Boolean flag for tracking exclusion
3. **hasAnyUsage** - Computed property that checks both completion and partial usage
4. **resetIfNeeded()** - Updated to consider ignore status and partial usage

---

## UI Implementation

### BenefitRow Component

#### Structure
```
┌─ ZStack (with swipe background)
│
├─ HStack (swipe actions - background)
│  └─ Orange "Ignore" button
│     Blue "Tracked" button (when ignored)
│
└─ HStack (main content - foreground)
   ├─ Checkbox / Lock Icon
   ├─ VStack (benefit details)
   │  ├─ Name + Dollar Amount
   │  ├─ Card Name
   │  ├─ Description
   │  ├─ Partial Usage UI
   │  │  ├─ "Used: $X/$Y" display
   │  │  └─ "Add partial usage" button
   │  └─ Reset Date
   └─ Background color (gray if ignored)
```

#### Key Code Points

**1. Checkbox/Lock Icon Logic**
```swift
if completion.isIgnored {
    Image(systemName: "lock.fill")
        .font(.title2)
        .foregroundStyle(.secondary)
} else {
    Button {
        completion.isCompleted.toggle()
        completion.partialUsage = ""  // Clear partial usage when toggling
    } label: {
        Image(systemName: completion.isCompleted ? "checkmark.circle.fill" : "circle")
            .font(.title2)
            .foregroundStyle(completion.isCompleted ? .green : .secondary)
    }
    .buttonStyle(.plain)
}
```

**2. Partial Usage Display**
```swift
if catalogBenefit.dollarAmount > 0 && !completion.isIgnored {
    VStack(alignment: .leading, spacing: 6) {
        if !completion.partialUsage.isEmpty {
            // Show current usage with clear button
            HStack(spacing: 4) {
                Image(systemName: "square.and.pencil")
                Text("Used: $\(completion.partialUsage)/$\(Int(catalogBenefit.dollarAmount))")
                Button { completion.partialUsage = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(6)
        }
        
        // Button to add/edit partial usage
        Button { showPartialUsageInput = true } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle")
                Text("Add partial usage")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
            .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $showPartialUsageInput) {
            PartialUsageInputView(
                completion: completion,
                maxAmount: Int(catalogBenefit.dollarAmount),
                isPresented: $showPartialUsageInput
            )
        }
    }
}
```

**3. Swipe Actions (Background)**
```swift
ZStack(alignment: .trailing) {
    // Background swipe actions
    HStack(spacing: 0) {
        Spacer()
        
        Button {
            withAnimation {
                completion.isIgnored.toggle()
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: completion.isIgnored ? "bell" : "bell.slash")
                Text(completion.isIgnored ? "Tracked" : "Ignore")
            }
            .frame(minWidth: 70)
            .frame(maxHeight: .infinity)
            .background(completion.isIgnored ? Color.blue : Color.orange)
            .foregroundStyle(.white)
        }
    }
    
    // Main content (foreground)
    HStack { ... }
        .padding(.trailing, 80)  // Make room for swipe actions
}
```

**4. Ignore State Styling**
```swift
.opacity(completion.isIgnored ? 0.6 : 1.0)
.background(completion.isIgnored ? Color.gray.opacity(0.1) : .clear)
```

---

### PartialUsageInputView Component

**Purpose:** Modal sheet for entering partial usage amount

**Key Features:**
- Number input with keyboard type `.decimalPad`
- Live percentage calculation
- Input validation (prevents 0 or empty)
- Save/Cancel buttons
- Usage hint text

**Code Structure:**
```swift
struct PartialUsageInputView: View {
    @Bindable var completion: BenefitCompletion
    let maxAmount: Int
    @Binding var isPresented: Bool
    @State private var inputValue: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Partial Usage") {
                    HStack {
                        Text("$")
                        TextField("Amount used", text: $inputValue)
                            .keyboardType(.decimalPad)
                            .focused($isInputFocused)
                        Text("/ $\(maxAmount)")
                    }
                    
                    // Live percentage calculation
                    if !inputValue.isEmpty, let amount = Double(inputValue), amount > 0 {
                        HStack {
                            Text("Usage: \(Int(amount * 100.0 / Double(maxAmount)))%")
                            Spacer()
                            if amount >= Double(maxAmount) {
                                Label("Full credit available!", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Label("Partial usage recorded", systemImage: "info.circle")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Record Usage")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if !inputValue.isEmpty {
                            completion.partialUsage = inputValue
                        }
                        isPresented = false
                    }
                    .disabled(inputValue.isEmpty || (Double(inputValue) ?? 0) <= 0)
                }
            }
            .onAppear {
                inputValue = completion.partialUsage
                isInputFocused = true
            }
        }
        .presentationDetents([.medium])
    }
}
```

---

## State Management

### State Variables in BenefitRow
```swift
@State private var showPartialUsageInput = false
```

### Observable Changes
- **completion.isCompleted** - Toggled by checkbox
- **completion.partialUsage** - Modified by input sheet
- **completion.isIgnored** - Toggled by swipe button

All changes are automatically persisted through SwiftData's @Bindable.

---

## Logic Flow

### Partial Usage Entry Flow
```
User taps "Add partial usage"
    ↓
Sheet appears with input
    ↓
User enters amount (e.g., "250")
    ↓
Percentage shows live (e.g., "83%")
    ↓
User taps "Save"
    ↓
completion.partialUsage = "250"
    ↓
SwiftData auto-saves
    ↓
BenefitRow refreshes
    ↓
Shows "Used: $250/$300"
```

### Ignore Toggle Flow
```
User swipes right on benefit
    ↓
"Ignore" button appears (orange)
    ↓
User taps "Ignore"
    ↓
completion.isIgnored = true
    ↓
SwiftData auto-saves
    ↓
BenefitRow updates:
  - Checkbox → Lock icon
  - Text → Grayed out
  - Background → Light gray
    ↓
Swipe right again
    ↓
"Tracked" button appears (blue)
    ↓
User taps "Tracked"
    ↓
completion.isIgnored = false
    ↓
Benefit returns to normal
```

### Reset Logic Flow
```
On reset date passage:
    ↓
For each benefit:
    ↓
if !hasAnyUsage && !isIgnored {
    missedCount += 1
}
    ↓
isCompleted = false
partialUsage = ""
resetDate = nextResetDate
    ↓
(isIgnored status PRESERVED)
```

---

## Data Persistence

### SwiftData Integration
- All changes automatically saved via @Bindable
- No additional save calls needed
- Changes sync immediately to database

### Field Values After Reset
| Field | Before Reset | After Reset | Notes |
|-------|--------------|-------------|-------|
| isCompleted | Any | false | Cleared |
| partialUsage | Any | "" | Cleared |
| isIgnored | true/false | Same | PRESERVED |
| resetDate | Any | Next date | Updated |
| missedCount | X | X or X+1 | Incremented if missed |

---

## Edge Cases Handled

### 1. Toggling Completed Clears Partial Usage
```swift
completion.isCompleted.toggle()
completion.partialUsage = ""  // Clear partial when marking complete
```
Rationale: If fully completed, no need for partial usage tracking

### 2. Ignored Benefits Disable Checkbox
```swift
if completion.isIgnored {
    // Show lock icon instead of checkbox
} else {
    // Show clickable checkbox
}
```

### 3. Invalid Input Prevented
```swift
.disabled(inputValue.isEmpty || (Double(inputValue) ?? 0) <= 0)
```
Only allows positive numbers, prevents empty submissions

### 4. Usage Display Only for Dollar Benefits
```swift
if catalogBenefit.dollarAmount > 0 && !completion.isIgnored {
    // Show usage input UI
}
```
Status perks don't show usage input (no dollar amount)

### 5. Percentage Calculation
```swift
Int(amount * 100.0 / Double(maxAmount))
```
Converts amount to percentage of total credit

---

## Performance Considerations

### Rendering
- Swipe actions only rendered in ZStack (efficient)
- Conditional rendering for ignored state
- Sheet presentation for input (doesn't block list)

### Data
- All queries use SwiftData @Query
- Changes auto-persist (no manual save overhead)
- No redundant calculations

### Memory
- String storage for partialUsage (minimal overhead)
- Boolean for isIgnored (negligible)
- Total per-benefit impact: ~20 bytes

---

## Build Status
✅ **SUCCESSFUL** - No errors, no warnings

---

## Testing Notes

### Unit Test Considerations
- `hasAnyUsage` should return true for both completed and partial usage
- `resetIfNeeded()` should only increment missedCount if !hasAnyUsage && !isIgnored
- Partial usage should clear on completion toggle
- Ignored status should persist through resets

### Integration Testing
- SwiftData persistence across app launches
- UI state consistency between list and detail views
- Swipe gesture recognition
- Keyboard handling in input sheet
