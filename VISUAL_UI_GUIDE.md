# Visual UI Guide: New Features

---

## Feature 1: Partial Usage Input

### Normal Benefit (No Usage)
```
┌─────────────────────────────────────────────┐
│ ○  Annual Hotel Credit                      │
│    American Express Platinum                │
│    $100 / year                              │
│    Get $100 credit for eligible charges...  │
│                                             │
│    + Add partial usage                      │
│                                             │
│    ↻ Resets May 17, 2027                   │
└─────────────────────────────────────────────┘
```

### With Partial Usage Entered
```
┌─────────────────────────────────────────────┐
│ ○  Annual Hotel Credit                      │
│    American Express Platinum                │
│    $100 / year                              │
│                                             │
│    ┌─────────────────────────────────────┐  │
│    │ 🔧 Used: $75/$100            [x]   │  │
│    └─────────────────────────────────────┘  │
│                                             │
│    + Add partial usage                      │
│                                             │
│    ↻ Resets May 17, 2027                   │
└─────────────────────────────────────────────┘
```

### Partial Usage Input Sheet
```
╔═════════════════════════════════════════════╗
║                                             ║
║            Record Usage                     ║
║                                             ║
║ ─────────────────────────────────────────   ║
║                                             ║
║ Partial Usage                               ║
║                                             ║
║ $ [250________] / $100                     ║
║                                             ║
║ Usage: 75%                                  ║
║ ℹ️  Partial usage recorded                  ║
║                                             ║
║ ─────────────────────────────────────────   ║
║                                             ║
║ Any amount of usage will prevent this       ║
║ benefit from being marked as missed.        ║
║                                             ║
║ [Cancel]                      [Save]        ║
║                                             ║
╚═════════════════════════════════════════════╝
```

### Percentage Scenarios
```
Scenario 1: Under-utilized
┌────────────────────────────────────────┐
│ Used: $25/$300                   [x]   │
│ (8% - barely used)                     │
└────────────────────────────────────────┘

Scenario 2: Partial use
┌────────────────────────────────────────┐
│ Used: $150/$200                  [x]   │
│ (75% - good usage)                     │
└────────────────────────────────────────┘

Scenario 3: Full utilization
┌────────────────────────────────────────┐
│ Used: $300/$300                  [x]   │
│ (100% - fully used)                    │
└────────────────────────────────────────┘
```

---

## Feature 2: Ignore/Exclude

### Swipe Right to Reveal
```
Normal State:
┌──────────────────────────────────────────┐
│ ○ Hertz Five Star Status                 │
│   American Express Gold                  │
│   Complimentary Hertz Five Star Status   │
│   ↻ Resets May 17, 2027                 │
└──────────────────────────────────────────┘

↓ (Swipe Right)

Swiped State:
                     ┌────────────────────┐
                     │ [bell.slash]       │
                     │ Ignore             │
                     └────────────────────┘
┌──────────────────────────────────────────┐
│ ○ Hertz Five Star Status                 │
│   American Express Gold                  │
│   Complimentary Hertz Five Star Status   │
│   ↻ Resets May 17, 2027                 │
└──────────────────────────────────────────┘
```

### After Ignoring
```
┌──────────────────────────────────────────┐
│ 🔒 Hertz Five Star Status (grayed out)   │
│    American Express Gold                 │
│    Complimentary Hertz Five Star Status  │
│    ↻ Resets May 17, 2027                 │
│                                          │
│ (Background slightly gray)               │
│ (Text at 60% opacity)                    │
│ (Checkbox disabled)                      │
└──────────────────────────────────────────┘
```

### Swipe to Restore
```
Ignored State (Swiped):
                     ┌────────────────────┐
                     │ [bell]             │
                     │ Tracked            │
                     └────────────────────┘
┌──────────────────────────────────────────┐
│ 🔒 Hertz Five Star Status (grayed)       │
│    American Express Gold                 │
│    Complimentary Hertz...                │
│    ↻ Resets May 17, 2027                 │
└──────────────────────────────────────────┘

↓ (Tap "Tracked")

Restored to Normal:
┌──────────────────────────────────────────┐
│ ○ Hertz Five Star Status                 │
│   American Express Gold                  │
│   Complimentary Hertz Five Star Status   │
│   ↻ Resets May 17, 2027                 │
└──────────────────────────────────────────┘
```

---

## Full Benefits Tab Example

### Mixed States
```
BENEFITS TAB - Annually Period
═════════════════════════════════════════

📅 Travel Category (4)
─────────────────────────────────────────

✓ Airline Fee Credit $200           (Completed)
  Delta Air Lines
  Statement credit for incidental fees

🔧 Hotel Credit $300 [x]            (Partial: $150)
  The Hotel Collection
  $150 used of available credit
  🌐 Used: $150/$300
  ┌─────────────────────────┐
  │ + Add partial usage     │
  └─────────────────────────┘

🔒 Global Entry Credit $120         (Ignored)
  Airport Lounge Access
  (grayed out - not tracked)

○ Car Rental Benefit                (Unused)
  Hertz Five Star Status

───────────────────────────────────────

🍽️  Dining Category (3)
─────────────────────────────────────────

✓ Dining Credit $100
  Restaurant Rebates
  (Completed)

🔧 Grubhub Credit $120 [x]
  DoorDash & Delivery
  🌐 Used: $45/$120
  ┌─────────────────────────┐
  │ + Add partial usage     │
  └─────────────────────────┘

○ Dunkin Credit $84
  Coffee & Donuts
  (Unused)

───────────────────────────────────────

💳 Shopping Category (2)
─────────────────────────────────────────

🔒 Saks Credit $50                  (Ignored)
  Department Store
  (grayed out - not tracked)

○ Walmart+ Credit $155
  Retail Membership
  (Unused)
```

---

## User Journey Maps

### Journey 1: Tracking Partial Credit Usage

```
User receives Annual Hotel Credit ($100)
         ↓
   Uses $75 in hotel stays
         ↓
Opens Benefits Tab
         ↓
Sees "Hotel Credit" benefit
         ↓
Taps "Add partial usage"
         ↓
Input sheet appears
         ↓
Enters "75"
         ↓
Sees "Usage: 75%"
         ↓
Taps "Save"
         ↓
Returns to Benefits Tab
         ↓
Sees "Used: $75/$100" badge
         ↓
✅ Benefit NOT counted as "missed"
```

### Journey 2: Ignoring Unwanted Benefits

```
User has Hertz status benefit
(doesn't use it, doesn't care)
         ↓
Opens Benefits Tab
         ↓
Sees "Hertz Five Star Status"
         ↓
Swipes RIGHT on benefit
         ↓
Orange "Ignore" button appears
         ↓
Taps "Ignore"
         ↓
Benefit turns gray with lock icon
         ↓
✅ Benefit NOT counted as "missed"
         ↓
(Later if needed)
Swipes RIGHT again
         ↓
Blue "Tracked" button appears
         ↓
Taps "Tracked" to restore
         ↓
Benefit returns to normal
```

### Journey 3: Mixed Tracking

```
User has 5 benefits in same period:
  1. Hotel Credit ($100)
  2. Dining Credit ($50)
  3. Status Perk (Free upgrade)
  4. Car Rental (Hertz status)
  5. Airline Fee Credit ($200)
         ↓
User's actions:
  1. ✓ Hotel - Uses $75 → partial usage
  2. ✓ Dining - Marked complete
  3. ○ Status - Ignored (not relevant)
  4. ○ Car - Left as-is (might use)
  5. ✓ Airline - Marked complete
         ↓
At period reset:
  Benefits with usage: 1, 2, 5 → NOT missed ✅
  Ignored benefit: 3 → NOT missed ✅
  Unused benefit: 4 → MISSED ❌
  
Result: Only 1 benefit counted as missed
```

---

## Interaction States

### Button States

**Checkbox State Machine**
```
Normal Benefit:
  [○] → tap → [✓] (checked)
  [✓] → tap → [○] (unchecked)

Ignored Benefit:
  [🔒] (locked, not clickable)
```

**Ignore Button Colors**
```
Active (ignore):      Orange (#FF9500)
Inactive (tracked):   Blue (#007AFF)
Background:          Light gray (when ignored)
```

**Partial Usage Button**
```
Inactive:  Gray + plus icon
Active:    Blue when usage exists
Clear:     [x] button visible when text entered
```

---

## Accessibility

### Icons Used
- **Checkbox:** ○ circle, ✓ checkmark
- **Lock:** 🔒 lock.fill (for ignored benefits)
- **Edit:** 🔧 square.and.pencil (for usage amount)
- **Bell:** 🔔 bell / 🔕 bell.slash (for ignore toggle)
- **Refresh:** ↻ arrow.clockwise (for reset date)

### Color Coding
```
Green  → Completed, full usage
Blue   → Active, interactive
Orange → Ignore action
Gray   → Disabled, ignored
Red    → Not used (in future: missed warning)
```

### Text Contrast
- Normal text: 100% opacity
- Secondary text: 75% opacity
- Ignored text: 60% opacity
- Disabled text: 50% opacity

---

## Animations

### Transitions
- **Swipe:** Smooth slide of background button
- **Ignore toggle:** Quick opacity change + background color shift
- **Input sheet:** Slide up from bottom
- **Clear button:** Fade out when usage cleared

### Timing
- Swipe actions: Instant (no delay)
- Sheet presentation: 0.3s
- State changes: 0.2s

---

## Edge Cases Illustrated

### Edge Case 1: Very Small Amount
```
┌────────────────────────────────┐
│ Used: $5/$300              [x] │
│ (Just 1% - minimal usage)      │
└────────────────────────────────┘
```

### Edge Case 2: Over Full Amount
```
Input Sheet:
$ [350________] / $100

Usage: 350%
✅ Full credit available!
   (Can over-enter, system allows)
```

### Edge Case 3: Decimal Amounts
```
┌────────────────────────────────┐
│ Used: $45.50/$150          [x] │
│ (30% - precise tracking)       │
└────────────────────────────────┘
```

### Edge Case 4: Ignored + Previously Used
```
Next period:
┌────────────────────────────────┐
│ 🔒 Benefit Name (grayed)       │
│ (Ignored status preserved)     │
│ (Previous usage cleared)       │
│ (Still not counted as missed)  │
└────────────────────────────────┘
```

---

## Summary

These visual guides show:
✅ How partial usage appears  
✅ How to swipe and ignore benefits  
✅ What happens in each state  
✅ User workflows  
✅ Edge cases  
✅ Accessibility & color coding  
✅ Animation expectations
