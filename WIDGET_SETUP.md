# Home Screen Widget Setup Guide

Follow these steps in Xcode to wire up the BenefitWidget extension.

---

## Step 1 — Add the Widget Extension target

1. In Xcode, go to **File → New → Target**.
2. Select **Widget Extension** under the iOS section and click **Next**.
3. Set the Product Name to **BenefitWidget**.
4. **Uncheck** "Include Configuration App Intent" (the widget is static).
5. Click **Finish**. When Xcode asks whether to activate the new scheme, click **Activate**.

---

## Step 2 — Add the App Group capability to both targets

The widget and the main app communicate through a shared `UserDefaults` suite backed by an App Group. You must add the same group to both targets.

### Main app target

1. Select the **Credit Card Benefit Tracker** target in the project navigator.
2. Open the **Signing & Capabilities** tab.
3. Click **+ Capability** and add **App Groups**.
4. Click the **+** button inside the App Groups box and enter:
   ```
   group.benefittracker.shared
   ```
5. Make sure the checkbox next to `group.benefittracker.shared` is checked.

### Widget target

1. Select the **BenefitWidget** target.
2. Repeat the same steps: **Signing & Capabilities → + Capability → App Groups**.
3. Enter the same group ID: `group.benefittracker.shared` and check it.

Both targets must use the same Apple Developer Team so Xcode can provision the entitlement automatically.

---

## Step 3 — Add BenefitWidget.swift to the widget target

The file `BenefitWidget/BenefitWidget.swift` was created alongside this guide.

1. In Xcode's project navigator, locate `BenefitWidget/BenefitWidget.swift`.
2. Select the file, open the **File Inspector** (right panel), and confirm that under **Target Membership** only **BenefitWidget** is checked (not the main app).
3. Delete the placeholder `BenefitWidget.swift` that Xcode generated when it created the target (it will be replaced by the one provided).

> If Xcode already generated a `BenefitWidget.swift` inside a folder called `BenefitWidget`, replace its contents with the provided file.

---

## Step 4 — Add WidgetDataWriter.swift to the main app target

The file `Credit Card Benefit Tracker/WidgetDataWriter.swift` was created alongside this guide.

1. In Xcode, select `WidgetDataWriter.swift` in the navigator.
2. In the **File Inspector**, confirm **Target Membership** shows only **Credit Card Benefit Tracker** checked.

---

## Step 5 — Call WidgetDataWriter.sync from the App entry point

Open `Credit Card Benefit Tracker/Credit_Card_Benefit_TrackerApp.swift` and update it to sync data whenever the app becomes active. The recommended approach uses `@Environment(\.scenePhase)` and a SwiftData query:

```swift
import SwiftUI
import SwiftData

@main
struct Credit_Card_Benefit_TrackerApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @Query private var userCards: [UserCard]

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserCard.self,
            BenefitCompletion.self,
            NotificationSettings.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                WidgetDataWriter.sync(userCards: userCards)
            }
        }
    }
}
```

**Why `.active`?** The widget reads from UserDefaults; writing on every foreground transition keeps the widget data current without requiring background fetch permissions.

> Note: `@Query` inside the `App` struct requires the `.modelContainer` modifier to already be applied in the scene, which it is. The query is re-evaluated automatically by SwiftData whenever the store changes.

---

## Step 6 — Build and run; add the widget to the simulator home screen

1. Select the **Credit Card Benefit Tracker** scheme (not the BenefitWidget scheme) and build for a simulator (**Product → Build**, or ⌘B).
2. Run the app on the simulator (**⌘R**). This installs both the main app and the widget extension.
3. On the simulator, press the **Home button** (or Shift+⌘H) to go to the home screen.
4. Long-press an empty area of the home screen until the icons jiggle.
5. Tap the **+** button in the top-left corner.
6. Search for **Benefit Tracker** in the widget gallery.
7. Select the small widget and tap **Add Widget**.
8. Press the Home button again to exit jiggle mode.

The widget will display the unclaimed count and remaining value from the last time the main app was foregrounded. Re-open the main app to trigger a fresh sync if the numbers look stale.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Widget shows 0 / $0 always | Check that both targets have the same App Group ID and the same Team in Signing settings. |
| Build error: `WidgetCenter` not found | Confirm `WidgetDataWriter.swift` has `import WidgetKit` and is a member of the main app target only. |
| Widget not appearing in gallery | Clean build folder (Shift+⌘K), delete the app from the simulator, and re-run. |
| `@Query` compile error in App struct | Make sure the `WindowGroup` `.modelContainer(sharedModelContainer)` modifier appears before `.onChange`. |
