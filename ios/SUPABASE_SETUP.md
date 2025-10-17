# Supabase-Anbindung für Login & Registrierung

Diese Anleitung erklärt, wie du die iOS-App so konfigurierst, dass die Anmeldung und Registrierung direkt über deine Supabase-Instanz laufen.

## 1. Swift Package Abhängigkeit hinzufügen
1. Öffne das Xcode-Projekt `AITIExplorer.xcodeproj`.
2. Wähle im Menü **File > Add Packages...**.
3. Füge das Paket `https://github.com/supabase-community/supabase-swift` hinzu.
4. Wähle das Produkt **Supabase** und binde es in das App-Target ein.
5. Xcode lädt nun die Bibliothek und stellt den `SupabaseClient` bereit, den die App im Login verwendet.

## 2. Supabase-Projekt vorbereiten
1. Melde dich im [Supabase Dashboard](https://app.supabase.com/) an und öffne dein Projekt.
2. **Authentifizierung aktivieren**
   - Navigiere zu **Authentication > Providers** und stelle sicher, dass **Email** aktiviert ist.
   - Deaktiviere (falls nicht benötigt) andere Provider.
   - Unter **Authentication > Settings** kannst du optional die E-Mail-Bestätigung deaktivieren, wenn du eine sofortige Anmeldung ohne Bestätigungslink wünschst.
3. **Profile-Tabelle anlegen**
   - Öffne **Database > Table editor** und erstelle (oder prüfe) die Tabelle `profiles` entsprechend dem bereitgestellten Schema.
   - Führe die Trigger `profiles_set_timestamp` und `trg_profiles_name_immutable` aus dem Schema ebenfalls aus.
4. **Row Level Security aktivieren**
   - Aktiviere RLS für die Tabelle `profiles`.
   - Lege folgende Policies an, damit Nutzer nur ihre eigenen Profile sehen bzw. bearbeiten können:
     ```sql
     create policy "Users can read own profile" on profiles
     for select using (auth.uid() = id);

     create policy "Users can insert own profile" on profiles
     for insert with check (auth.uid() = id);

     create policy "Users can update own profile" on profiles
     for update using (auth.uid() = id);
     ```
5. **Optionale Seed-Daten**
   - Wenn du Testnutzer benötigst, erstelle sie über **Authentication > Users** oder über die App-Registrierung.

## 3. Konfigurationsdatei in Xcode hinterlegen
1. Kopiere die Datei `ios/AITIExplorer/Resources/SupabaseConfig.example.plist` und benenne die Kopie in `SupabaseConfig.plist` um.
2. Trage dort deine Projekt-URL (`https://<project>.supabase.co`) und den **anon**-Key aus **Project Settings > API** ein.
3. Ziehe `SupabaseConfig.plist` in Xcode in den Ordner *Resources* und aktiviere das App-Target im Dialog **Add to targets**.
4. Achte darauf, dass die Datei nicht in Versionskontrolle mit echten Schlüsseln eingecheckt wird.

## 4. App starten & testen
1. Baue die App mit `⌘R`.
2. Registriere einen neuen Account – der Nutzer wird in Supabase erstellt und der Eintrag in der Tabelle `profiles` angelegt.
3. Melde dich mit dem neuen Account an. Beim Login wird der Datensatz aus `profiles` geladen und als `UserProfile` in der App verwendet.
4. Profiländerungen in der App werden automatisch wieder in Supabase gespeichert.

## 5. Fehlerdiagnose
- Prüfe bei Login-Fehlern die Supabase-Logs unter **Authentication > Logs**.
- Vergewissere dich, dass `SupabaseConfig.plist` im App-Bundle enthalten ist (im Build-Log oder unter **Build Phases > Copy Bundle Resources**).
- Bei `403`-Antworten kontrolliere die RLS-Policies und, ob der Nutzer verifiziert ist (falls E-Mail-Bestätigung aktiv ist).

Nach Abschluss dieser Schritte kommuniziert die App vollständig mit Supabase für Authentifizierung und Profildaten.
