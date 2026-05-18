# New Features: Partial Usage & Ignore Functionality

## Overview
Added two powerful tracking features to the Benefits Tab:

1. **Partial Usage Tracking** - Record how much of a credit you've used
2. **Ignore Feature** - Mark benefits to exclude from "missed" notifications

---

## Feature 1: Partial Usage Tracking

### How It Works
- Tap "Add partial usage" button on any dollar-amount benefit
- Enter the amount you've used (e.g., "$250" out of "$300" available)
- Any usage amount prevents the benefit from being counted as "missed"
- Usage percentage is displayed (e.g., "Usage: 83%")

### UI Elements
```
┌─────────────────────────────────────┐
│ Annual Hotel Credit                 │
│ $100 / year                         │
│ Blue credit card                    │
│ Get $100 credit for eligible...     │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ Used: $75/$100              [x] │ │ ← Displays current usage
│ └─────────────────────────────────┘ │
│                                     │
│ + Add partial usage                 │ ← Tap to modify
│                                     │
│ ↻ Resets May 17, 2027              │
└─────────────────────────────────────┘
```

### Usage Recording Sheet
When you tap "Add partial usage":
```
Record Usage
─────────────
$ [Input Field] / $300
Usage: 75%
ℹ️ Partial usage recorded

Any amount of usage will prevent this benefit 
from being marked as missed.

[Cancel] [Save]
```

### Examples
- **$100 credit available, used $50** → Records as "50% usage", not marked as missed ✅
- **$25/month benefit, used $5** → Records as "20% usage", not marked as missed ✅
- **$300 hotel credit, used full amount** → Records as "100% usage" ✅

---

## Feature 2: Ignore Functionality

### How It Works
- **Swipe right** on any benefit in the Benefits Tab
- Tap the **"Ignore"** button (bell with slash icon, orange color)
- Benefit becomes grayed out and read-only
- Checkbox is disabled
- Benefit is NOT counted in "missed" notifications

### UI Elements

#### Normal Benefit (Before Swipe)
```
[O] Hertz Five Star Status
    American Express Gold
    Complimentary Hertz...
    ↻ Resets May 17, 2027
```

#### Swiped State
```
    ┌──────────────────────────────┐
    │ [bell.slash]                 │
    │ Ignore                       │
    └──────────────────────────────┘
[O] Hertz Five Star Status (grayed out)
    ...
```

#### After Tapping "Ignore"
```
[🔒] Hertz Five Star Status (grayed out & locked)
     American Express Gold
     Complimentary Hertz...
     ↻ Resets May 17, 2027
```

When ignored, you can:
- **Swipe right again** and tap "Tracked" to restore tracking
- The benefit remains in your Benefits Tab
- It just won't count as "missed"

### Examples
- **Benefits you don't care about** → Ignore them so they don't skew your "missed" count
- **Benefits you've already gotten** → Mark as ignored, they won't be counted
- **Status perks** → Some users might not value them, can ignore

---

## Data Model Changes

### BenefitCompletion Model
Added two new fields:

```swift
var partialUsage: String = ""   // Amount used, e.g., "250"
var isIgnored: Bool = false      // Whether benefit is excluded from tracking
```

### New Computed Property
```swift
var hasAnyUsage: Bool {
    isCompleted || !partialUsage.trimmingCharacters(in: .whitespaces).isEmpty
}
```

This property returns `true` if:
- Checkbox is marked as completed, OR
- Any partial usage amount is entered

### Updated Reset Logic
```swift
func resetIfNeeded() {
    // Only counts as "missed" if:
    // - Not completed AND
    // - No partial usage AND
    // - Not ignored
    if !hasAnyUsage && !isIgnored {
        missedCount += 1
    }
}
```

---

## User Workflows

### Workflow 1: Tracking Partial Credit Usage
1. User receives benefit with $300 annual credit
2. Uses part of it ($250) during the period
3. Taps "Add partial usage"
4. Enters "250"
5. Sees: "Used: $250/$300 (83%)"
6. Benefit no longer counts as "missed"
7. When period resets, partial usage is cleared

### Workflow 2: Ignoring Unwanted Benefits
1. User has a benefit they don't value (e.g., lounge access)
2. Swipes right on the benefit
3. Taps "Ignore" button
4. Benefit appears grayed out with lock icon
5. Checkbox is disabled
6. Benefit is excluded from "missed" notifications
7. Later, can swipe and tap "Tracked" to re-enable tracking

### Workflow 3: Mixed Tracking
1. User has multiple benefits in same period
2. Some are completed (checkbox)
3. Some have partial usage recorded
4. Some are ignored
5. Only truly missed benefits (no usage + not ignored) count toward "missed"

---

## Visual Indicators

### States of a Benefit

#### 1. Normal (Not Used)
```
[○] Benefit Name
    Uncompleted, no usage entered
    Checkbox is interactive
```

#### 2. Completed
```
[✓] Benefit Name (strikethrough)
    Checkbox is checked ✅
    Marked as completed
```

#### 3. Partial Usage
```
[○] Benefit Name
    🔧 Used: $250/$300
    Partial usage tracked
```

#### 4. Ignored
```
[🔒] Benefit Name (grayed out)
     Locked, not tracked
     Checkbox disabled
     Color: 60% opacity
```

#### 5. Ignored + Has Usage
```
[🔒] Benefit Name (grayed out)
     Locked from tracking
     (previous usage preserved)
```

---

## Important Notes

### When Resetting Period
- ✅ Partial usage amount is **cleared**
- ✅ Checkbox is **reset to unchecked**
- ✅ Ignore status is **preserved** (stays ignored)
- ✅ If benefit was unused & not ignored → **missedCount incremented**

### Interaction Rules
- **Ignored benefits:** Checkbox is disabled (shows lock icon)
- **Non-ignored benefits:** Checkbox toggles normally
- **Partial usage field:** Only appears for dollar-amount benefits
- **Swipe actions:** Only available on Benefits Tab (not Card Detail)

### Data Persistence
- All changes auto-save immediately
- Partial usage amount is stored as string
- Ignore status is boolean flag
- Both persist across app launches

---

## Implementation Details

### Modified Files
1. **Models.swift**
   - Added `partialUsage` and `isIgnored` fields to `BenefitCompletion`
   - Added `hasAnyUsage` computed property
   - Updated `resetIfNeeded()` logic

2. **BenefitsView.swift**
   - Redesigned `BenefitRow` with swipe functionality
   - Added `PartialUsageInputView` sheet for input
   - Updated checkbox behavior for ignored benefits
   - Added visual indicators for different states

### UI/UX Features
- ✅ Swipe-to-reveal actions (standard iOS pattern)
- ✅ Modal sheet for partial usage input
- ✅ Visual state indicators (lock icon, opacity, strikethrough)
- ✅ Keyboard handling for number input
- ✅ Input validation (prevents 0 or empty values)
- ✅ Percentage calculation display
- ✅ Clear/remove button for partial usage

---

## Build Status
✅ **Successful** - No errors, no warnings

---

## Testing Checklist

- [ ] Add a benefit with dollar amount
- [ ] Tap "Add partial usage"
- [ ] Enter an amount less than total
- [ ] Verify usage percentage calculates correctly
- [ ] Clear the partial usage with [x] button
- [ ] Try entering partial usage >= total amount
- [ ] Swipe right on a benefit
- [ ] Tap "Ignore" button
- [ ] Verify benefit turns grayed out with lock icon
- [ ] Try tapping checkbox on ignored benefit (should not work)
- [ ] Swipe right on ignored benefit
- [ ] Tap "Tracked" to restore
- [ ] Verify benefit returns to normal state
- [ ] Close app and reopen
- [ ] Verify all partial usage and ignore states persist

---

## Future Enhancement Ideas
- [ ] Add usage notes/memo for each benefit
- [ ] Category-wide ignore option
- [ ] "Quick complete" button (tap to mark 100% of amount)
- [ ] Usage history tracking
- [ ] Budget view showing % of benefits utilized
- [ ] Alerts for unused benefits approaching reset date
