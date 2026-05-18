# Visual Guide: Anniversary Date Feature

## The Problem

Most credit cards renew annual benefits on the card's opening anniversary date, NOT January 1st.

**Example Timeline:**
```
Card opened:           December 15, 2024
Annual benefits start:  December 15, 2024
First renewal:         December 15, 2025
Second renewal:        December 15, 2026
(Not January 1st!)
```

---

## UI Layout

### Annual Benefit Without Anniversary Set

```
┌─────────────────────────────────────┐
│ ○ Global Entry / TSA PreCheck       │
│   American Express Platinum         │
│   Up to $120 credit...              │
│                                     │
│ 📅 Set anniversary date             │ ← Purple button
│ (tap to add date)                   │
│                                     │
│ ↻ Resets January 1, 2027            │ ← Default Jan 1
└─────────────────────────────────────┘
```

### Annual Benefit With Anniversary Set

```
┌─────────────────────────────────────┐
│ ○ Global Entry / TSA PreCheck       │
│   American Express Platinum         │
│   Up to $120 credit...              │
│                                     │
│ ┌────────────────────────────────┐  │
│ │ 📅 Anniversary: May 15, 2024 [x]│  │ ← Shows anniversary
│ └────────────────────────────────┘  │
│                                     │
│ 📅 Edit anniversary date            │ ← Button to change
│                                     │
│ ↻ Resets May 15, 2027               │ ← Uses anniversary
└─────────────────────────────────────┘
```

### Non-Annual Benefits (No Anniversary Option)

```
┌─────────────────────────────────────┐
│ ○ Dining Credit $50                 │
│   American Express Gold             │
│   Semi-annually dining credit...    │
│                                     │
│ 🔧 Used: $25/$50              [x]   │ ← Only shows partial usage
│                                     │
│ ↻ Resets July 1, 2026               │ ← Based on period (not anniversary)
└─────────────────────────────────────┘
(No anniversary section - only for annual benefits)
```

---

## DatePicker Sheet UI

```
╔═══════════════════════════════════╗
║                                   ║
║  Annual Benefit Anniversary       ║
║                                   ║
║ ─────────────────────────────────  ║
║                                   ║
║ Set Anniversary Date              ║
║                                   ║
║ ┌─────────────────────────────┐   ║
║ │ 📅  May  |  15  |  2024  ▼  │   ║ ← DatePicker
║ └─────────────────────────────┘   ║
║                                   ║
║ ℹ️ Benefits renew on this          ║
║    date each year                 ║
║                                   ║
║ ─────────────────────────────────  ║
║                                   ║
║ Example                           ║
║                                   ║
║ If anniversary is Dec 15:         ║
║ • Current year: Dec 15            ║
║ • Next year: Dec 15               ║
║ • And so on...                    ║
║                                   ║
║ ─────────────────────────────────  ║
║                                   ║
║ [Cancel]              [Save]      ║
║                                   ║
╚═══════════════════════════════════╝
```

---

## User Flows

### Flow 1: Setting Anniversary for First Time

```
START: Annual benefit, no anniversary set

   User taps "Set anniversary date"
            ↓
   DatePicker sheet opens
   Shows current date (May 20, 2026)
            ↓
   User adjusts to: December 15, 2024
   (Card opening date)
            ↓
   User taps "Save"
            ↓
   System updates:
   • benefitStartDate = Dec 15, 2024
   • resetDate = Dec 15, 2026 (next anniversary)
            ↓
END: Anniversary badge shows, reset date updates
```

### Flow 2: Editing Existing Anniversary

```
START: Annual benefit with anniversary set

   Shows: "Anniversary: May 15, 2024"
   Reset: May 15, 2027
            ↓
   User taps "Edit anniversary date"
            ↓
   DatePicker opens, pre-populated with May 15
            ↓
   User changes to: March 1, 2024
            ↓
   User taps "Save"
            ↓
   System recalculates:
   • benefitStartDate = Mar 1, 2024
   • resetDate = Mar 1, 2027
            ↓
END: Anniversary and reset date both updated
```

### Flow 3: Clearing Anniversary

```
START: Annual benefit with anniversary

   Shows: "Anniversary: May 15, 2024"
            ↓
   User taps [x] button
            ↓
   benefitStartDate = nil
            ↓
   System defaults to Jan 1 reset
   • resetDate = January 1, 2027
            ↓
END: Anniversary removed, reverts to default
```

---

## Reset Date Calculations

### Example 1: Anniversary Not Yet Passed This Year

```
Today: May 20, 2026
Card opened: December 15, 2024
Period: Annually

Logic:
1. Check December 15, 2026 (this year)
2. Is Dec 15, 2026 > May 20, 2026? YES ✓
3. Next reset = December 15, 2026

Reset Badge: "Resets December 15, 2026"
Time until reset: ~7 months
```

### Example 2: Anniversary Already Passed This Year

```
Today: December 20, 2026
Card opened: December 15, 2024
Period: Annually

Logic:
1. Check December 15, 2026 (this year)
2. Is Dec 15, 2026 > Dec 20, 2026? NO ✗
3. Use next year: December 15, 2027

Reset Badge: "Resets December 15, 2027"
Time until reset: ~12 months
```

### Example 3: Anniversary is Today

```
Today: December 15, 2026
Card opened: December 15, 2024
Period: Annually

Logic:
1. Check December 15, 2026 (today)
2. Is Dec 15, 2026 > Dec 15, 2026? NO ✗
   (today is NOT > today)
3. Use next year: December 15, 2027

Reset Badge: "Resets December 15, 2027"
Note: Won't actually reset until tomorrow
```

### Example 4: No Anniversary Set (Default)

```
Today: May 20, 2026
Anniversary: nil (not set)
Period: Annually

Logic:
1. Check if anniversary exists? NO
2. Use default period logic (Jan 1)
3. Next reset = January 1, 2027

Reset Badge: "Resets January 1, 2027"
(Uses traditional calendar reset)
```

---

## Multiple Benefits Scenarios

### Scenario: Different Anniversary Dates

```
CARD: American Express Platinum (opened Jan 10, 2024)

Benefit 1: Global Entry Credit
  Anniversary: January 10, 2024
  Next reset: January 10, 2027

Benefit 2: Airline Fee Credit
  Anniversary: January 10, 2024
  Next reset: January 10, 2027

Benefit 3: Resy Dining Credit
  Anniversary: NOT SET (uses default)
  Next reset: January 1, 2027

─────────────────────────────

CARD: Chase Sapphire Reserve (opened Sep 15, 2024)

Benefit 1: Travel Credit
  Anniversary: September 15, 2024
  Next reset: September 15, 2026

Benefit 2: StubHub Credit
  Anniversary: September 15, 2024
  Next reset: September 15, 2026
```

---

## Benefits Tab Display

### Full Benefits Tab with Mixed States

```
BENEFITS TAB - Annually Period
═════════════════════════════════════

Travel Category (3)
─────────────────────────────────────

✓ Global Entry Credit $120
  American Express Platinum
  📅 Anniversary: December 15, 2024
  ✎ Edit anniversary date
  ↻ Resets December 15, 2026

○ Airline Fee Credit $200
  American Express Platinum
  📅 Anniversary: December 15, 2024
  ✎ Edit anniversary date
  ↻ Resets December 15, 2026

○ Travel Credit $300
  Chase Sapphire Reserve
  📅 Anniversary: September 15, 2024
  ✎ Edit anniversary date
  ↻ Resets September 15, 2026

Shopping Category (2)
─────────────────────────────────────

○ Saks Credit $50
  American Express Platinum
  📅 Set anniversary date
  ↻ Resets January 1, 2027
  (No anniversary set - uses default)

🔒 Walmart+ Credit $155 (Ignored)
```

---

## Color Scheme

- **Anniversary badge:** Purple color (unique identifier)
- **Icons:** 
  - 📅 (calendar) - Anniversary indicator
  - ✎ (pencil) - Edit action
  - [x] - Remove action
- **Button states:**
  - "Set anniversary date" (gray) - No anniversary
  - "Edit anniversary date" (purple) - Has anniversary

---

## Edge Cases Illustrated

### Edge Case 1: Leap Year Anniversary (Feb 29)

```
User selects: February 29, 2024 (leap year)

Leap year (2024): Works normally
  Anniversary: Feb 29, 2024
  Next reset: Feb 29, 2027? NO (2027 is not leap year)
  Result: March 1, 2027 (calendar adjusts automatically)

Non-leap year: Calendar handles gracefully
  Feb 29 doesn't exist → March 1 automatically
```

### Edge Case 2: Card Just Opened Today

```
User adds new card: TODAY (Dec 15, 2026)
Sets anniversary: December 15, 2026

Current: Dec 15, 2026 (today)
Check: Dec 15, 2026 > Dec 15, 2026? NO
Result: Next reset = December 15, 2027

First year gets full year to use benefit
(Won't reset until next anniversary)
```

### Edge Case 3: Wrong Year Selected by Mistake

```
User picks anniversary: December 15, 2025 (wrong year)

System behavior:
- Still works correctly
- Calculates next anniversary as Dec 15, 2026
- User can edit anytime to fix

Note: Specific year doesn't matter, only month/day
```

---

## Summary

✅ Shows anniversary date prominently (purple badge)  
✅ Easy to set, edit, or clear  
✅ Reset date auto-calculates  
✅ Works with multiple benefits  
✅ Handles edge cases gracefully  
✅ Fully optional (backward compatible)  

**User Experience:** Straightforward and intuitive ⭐⭐⭐⭐⭐
