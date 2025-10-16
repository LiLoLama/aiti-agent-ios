# AITI Explorer iOS – Setup-Anleitung

Diese Anleitung beschreibt, wie du das neue SwiftUI-Projekt in Xcode anlegst, die bereitgestellten Dateien einbindest und die App anschließend auf einem Simulator oder Gerät testest.

## 1. Neues Xcode-Projekt erstellen
1. Öffne **Xcode 15** (oder neuer) und wähle im Startdialog **Create a new Xcode project**.
2. Wähle unter *iOS* die Vorlage **App** aus und klicke auf **Next**.
3. Vergib einen Produktnamen, z. B. `AITIExplorer`.
4. Stelle folgende Optionen ein:
   - **Team**: (dein Apple-Entwicklerteam oder „None“ für den Simulator)
   - **Organization Identifier**: z. B. `ai.aiti`
   - **Interface**: `SwiftUI`
   - **Language**: `Swift`
   - **Use Core Data**: deaktiviert
   - **Include Tests**: optional
5. Wähle einen Speicherort und bestätige mit **Create**.

## 2. Projektstruktur anlegen
1. Erstelle in Xcode in der Projekt-Navigator-Leiste die folgenden Gruppen (Ordner):
   - `Models`
   - `ViewModels`
   - `Views`
   - `Resources`
2. Ziehe die Dateien aus diesem Repository (`ios/AITIExplorer/...`) per Drag & Drop in die entsprechenden Gruppen:
   - `AITIExplorerApp.swift` und `Views/RootView.swift` in die Hauptebene deines Projekts.
   - Dateien in `Models`, `ViewModels`, `Views` und `Resources` jeweils in die gleichnamigen Gruppen.
3. Achte darauf, dass **Copy items if needed** aktiviert ist und die Ziel-Targets deiner App ausgewählt sind.

## 3. Assets & App Icon
- Die aktuelle Implementierung nutzt ausschließlich SF Symbols und systemeigene Farben. Du kannst deshalb zunächst auf eigene Assets verzichten.
- Optional kannst du in der *Assets*-Sektion von Xcode ein App-Icon hinzufügen.

## 4. App starten
1. Wähle im Scheme-Menü den gewünschten Simulator (z. B. *iPhone 15 Pro*).
2. Baue und starte die App mit `⌘R`.
3. Melde dich mit dem Demo-Zugang an:
   - **E-Mail:** `demo@aiti.ai`
   - **Passwort:** `SwiftRocks!`
4. Navigiere über die Tab-Leiste zwischen **Chat**, **Einstellungen** und **Profil**.

## 5. Eigene Erweiterungen
- Passe Daten im `SampleData.swift` an, um weitere Agents oder Nachrichten hinzuzufügen.
- Über die `Profile`-Ansicht kannst du neue Agents direkt in der App anlegen.
- Der Einstellungen-Tab speichert gewählte Optionen via `UserDefaults` (`SampleData.saveSettings`).

## 6. Optional: Testen auf einem Gerät
1. Verbinde dein iPhone via USB oder WLAN mit dem Mac.
2. Wähle das Gerät als Run Destination aus.
3. Signiere das Projekt mit deinem Entwicklerprofil (unter **Signing & Capabilities**).
4. Starte die App mit `⌘R`.

Viel Erfolg beim Testen der nativen iOS-Version des AITI Explorer Agents!
