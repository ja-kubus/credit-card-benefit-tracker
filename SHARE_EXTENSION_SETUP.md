# Share Extension Setup Guide

Follow these steps in Xcode to wire up the ShareExtension target. Once done, statement PDFs/CSVs shared from Mail, Files, or a bank app appear under **Share → Benefit Tracker**, get stashed in the App Group container, and are offered for import the next time the main app opens.

---

## Step 1 — Add the Share Extension target

1. In Xcode, go to **File → New → Target**.
2. Select **Share Extension** under the iOS section and click **Next**.
3. Set the Product Name to **ShareExtension**.
4. Click **Finish**. When Xcode asks whether to activate the new scheme, click **Activate**.

---

## Step 2 — Replace the template files

Xcode generates a compose-style template we don't need.

1. Delete the generated `ShareViewController.swift` and `MainInterface.storyboard` from the new ShareExtension group (**Move to Trash**).
2. Add the provided `ShareExtension/ShareViewController.swift` to the project. In the **File Inspector**, confirm **Target Membership** shows only **ShareExtension** checked (not the main app).
3. Replace the generated `Info.plist` contents with the provided `ShareExtension/Info.plist`. Key differences:
   - **`NSExtensionMainStoryboard` is removed** — we use a programmatic UI instead.
   - `NSExtensionPrincipalClass` is set to `$(PRODUCT_MODULE_NAME).ShareViewController`.
   - The activation rule is the dictionary form with `NSExtensionActivationSupportsFileWithMaxCount = 10`, so the extension appears for shared files (PDF, CSV, etc.) up to 10 at a time.

> If Xcode's target settings reference the Info.plist by build setting (`INFOPLIST_FILE`), point it at `ShareExtension/Info.plist`.

---

## Step 3 — Add the App Group capability to both targets

The extension hands files to the main app through the App Group container. Both targets must share the same group.

### ShareExtension target

1. Select the **ShareExtension** target in the project navigator.
2. Open the **Signing & Capabilities** tab.
3. Click **+ Capability** and add **App Groups**.
4. Click the **+** inside the App Groups box and enter:
   ```
   group.benefittracker.shared
   ```
5. Make sure its checkbox is checked.

### Main app target

The main app should already have this group from the widget setup. If not, repeat the same steps on the **Credit Card Benefit Tracker** target with the same group ID.

Both targets must use the same Apple Developer Team so Xcode can provision the entitlements automatically.

---

## Step 4 — Add SharedInbox.swift to the main app target

The file `Credit Card Benefit Tracker/SharedInbox.swift` was created alongside this guide.

1. In Xcode, select `SharedInbox.swift` in the navigator.
2. In the **File Inspector**, confirm **Target Membership** shows only **Credit Card Benefit Tracker** checked — **not** ShareExtension. The extension writes files with plain FileManager calls and does not need this type.

---

## Step 5 — Build and test

1. Select the **Credit Card Benefit Tracker** scheme and run on a simulator (⌘R). This installs both the app and the extension.
2. Open the **Files** app on the simulator (drag a sample PDF or CSV onto the simulator window first to put one in Downloads).
3. Long-press the file → **Share** → **Benefit Tracker** (may be under "More" the first time).
4. You should see a checkmark with "Saved to Benefit Tracker"; the sheet auto-dismisses after ~1.2 s.
5. Open the main app — a sheet titled **Import Statements** lists the received files.

---

## How the main-app wiring works

This part is already implemented — no action needed, but here is the flow:

- **`ContentView.swift`** calls `SharedInbox.pendingFiles()` in `.onAppear` and in the `.onChange(of: scenePhase)` `.active` branch. If files are pending, it presents `SharedImportSheet`, which lists the file names under a "Statements received via Share" header with two actions:
  - **Discard** — calls `SharedInbox.clear()` and dismisses.
  - **Import** — stores the files in `SharedImportCoordinator.shared.filesToImport` and dismisses.
- **`SharedInbox.swift`** decodes the `UUID__originalName` filename prefix the extension uses to avoid collisions, exposing `InboxFile { url, originalName, data }`. `consume(_:)` deletes a single file after successful import; `clear()` empties the inbox.

### Upload sheet integration (follow-up)

The statement upload flow should read `SharedImportCoordinator.shared.filesToImport` when it appears and pre-fill itself. Each `SharedInbox.InboxFile` maps directly onto the existing `PickedFile` type (defined in `DocumentPickerView.swift`):

```swift
let picked = coordinator.filesToImport.map {
    PickedFile(fileName: $0.originalName, data: $0.data)
}
```

After a successful import, call `SharedInbox.consume(file)` for each imported file (or `SharedInbox.clear()`) and empty `filesToImport` so the prompt does not reappear.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Extension missing from the share sheet | Delete the app from the simulator, clean build folder (Shift+⌘K), and re-run. Check the activation rule dictionary is present in Info.plist. |
| Extension crashes on launch | Ensure `NSExtensionMainStoryboard` was removed and `NSExtensionPrincipalClass` is set — both keys present at once is invalid. |
| Files never show up in the app | Verify both targets list `group.benefittracker.shared` under App Groups with the same Team. |
| "Saved" shows but app finds nothing | The group ID string in `ShareViewController.swift` and `SharedInbox.swift` must match exactly (`group.benefittracker.shared`). |
