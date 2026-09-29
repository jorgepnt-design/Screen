# Screen On

Eine kleine native iPhone-App: öffnen, **Bildschirm anlassen** drücken und die App im Vordergrund lassen. Erneutes Drücken stellt die normale automatische Bildschirmsperre wieder her.

## Funktionen

- SwiftUI mit großer Schaltfläche, grünem AKTIV-Status, Laufzeit (HH:MM:SS), Light/Dark Mode, SF Symbols und Haptik.
- Optionaler Abschalttimer: Unbegrenzt (Standard), 15/30 Minuten, 1/2/4 Stunden. Die Auswahl wird lokal gespeichert und gilt für die nächste Sitzung.
- ActivityKit / WidgetKit: kompakt Sonne + ON, erweitert Titel, Status und Laufzeit.
- Kein Konto, keine Werbung, keine Cloud, kein Netzwerkzugriff, keine Drittanbieter-Bibliotheken.
- VoiceOver-Beschriftungen, skalierbare Schrift, scrollbare Ansicht und Berücksichtigung von „Bewegung reduzieren“.

## Voraussetzungen und Öffnen

- Ein Mac mit der neuesten stabilen Xcode-Version und dem dazugehörigen iOS SDK; keine Beta nötig. SDKROOT ist `iphoneos`, daher nutzt das Projekt das installierte SDK, keine fest eingebundene alte SDK-Version.
- Deployment-Ziel: **iOS 17.0 oder neuer**, iPhone.
- Repository herunterladen oder klonen und **ScreenOn.xcodeproj** öffnen. Kein XcodeGen, CocoaPods oder Swift Package Setup nötig.
- Scheme **ScreenOn** auswählen. Das Widget-Extension-Target wird automatisch gebaut und eingebettet.

## Auf dem eigenen iPhone installieren

1. Xcode auf dem Mac öffnen und unter **Settings → Accounts** deinen Apple-Account hinzufügen.
2. iPhone mit dem Mac verbinden, entsperren und die Vertrauensabfrage bestätigen.
3. In Xcode das Projekt, dann Target **ScreenOn**, dann **Signing & Capabilities** öffnen. **Automatically manage signing** aktivieren und dein Team wählen.
4. Dasselbe Team für **ScreenOnActivity** wählen. Falls die Kennungen schon belegt sind, `com.jorgepinto.ScreenOn` durch eine eigene eindeutige Kennung ersetzen; die Extension muss deren Präfix verwenden, z. B. `de.deinname.ScreenOn.Activity`.
5. Das iPhone als Ausführungsziel auswählen. Falls verlangt, unter **Einstellungen → Datenschutz & Sicherheit → Entwicklermodus** aktivieren und neu starten.
6. In Xcode **Run (⌘R)** drücken. Falls iOS es verlangt, dem Entwicklerprofil unter **Allgemein → VPN und Geräteverwaltung** vertrauen.
7. App öffnen und einschalten. Für Live Activities gegebenenfalls die entsprechende Erlaubnis in den iPhone-Einstellungen für Screen On aktivieren.

Mit einem kostenlosen persönlichen Team sind Entwicklungsinstallationen zeitlich begrenzt und müssen gegebenenfalls erneut aus Xcode installiert werden. Eine App-Store-Veröffentlichung oder signierte IPA ist nicht Teil dieses Projekts.

## Dynamic Island und Sperrbildschirm

Auf unterstützten iPhones stellt iOS die Live Activity in der Dynamic Island dar. Lange drücken öffnet die erweiterte Darstellung. Auf anderen unterstützten iPhones verwendet iOS die Sperrbildschirm-Darstellung. Position, Sichtbarkeit und Priorität bestimmt iOS; andere Aktivitäten können die Anzeige verdrängen. Die App prüft die ActivityKit-Verfügbarkeit und bleibt bei deaktivierten Live Activities weiterhin nutzbar.

**Wichtige Konsequenz:** Screen On endet bereits beim Verlust des aktiven Vordergrunds, also auch beim Sperren, App-Wechsel oder manchen Systemunterbrechungen. Deshalb soll auf dem gesperrten Gerät keine fortlaufende aktive Screen-On-Sitzung erscheinen. Das Sperrbildschirm-Layout ist implementiert, die Sitzung wird beim Sperren aber beendet. Auch das Öffnen einer Systemoberfläche kann die Sitzung stoppen. Zum Fortsetzen in der App erneut einschalten.

## Technische iOS-Grenzen und Statuskorrektheit

Die App verhindert den automatischen Ruhezustand ausschließlich mit `UIApplication.shared.isIdleTimerDisabled = true`, solange sie diesen Zustand als aktive Vordergrund-App kontrollieren kann. Beim Ausschalten bzw. Verlassen setzt sie die Eigenschaft sofort auf `false`. Manuelles Sperren, Systementscheidungen oder das Ausschalten des Geräts werden nicht verhindert. Es gibt keine Audio-, Video- oder Hintergrund-Workarounds.

Beliebige eigene Symbole sind in der normalen iOS-Statusleiste nicht erlaubt. Der externe Status verwendet ausschließlich Apples Live Activity / Dynamic Island. Eine Live Activity hält weder die App am Leben noch den Bildschirm anderer Apps eingeschaltet.

Der Aktiv-Zustand wird **nicht** in UserDefaults gespeichert. Beim Start werden alte Live Activities beendet und die App startet mit AUS. UIKit-Lifecycle-Benachrichtigungen und SwiftUI-ScenePhase stoppen die Sitzung. Eine kurze offizielle Background-Task dient ausschließlich zum Abschließen des ActivityKit-Endaufrufs, nicht zum Offenhalten des Displays. Ein monotones Zeitlimit schützt den Abschalttimer vor Änderungen der Systemuhr.

**Keine falsche Garantie bei Abstürzen:** iOS garantiert keinen letzten Callback bei Prozessabbruch, Absturz oder erzwungenem Beenden. Eine sofortige atomare Synchronisierung zwischen App und Systemanzeige ist deshalb ohne Einschränkungen nicht möglich. Die Live Activity erhält alle 15 Sekunden eine neue Statusbestätigung und ein `staleDate` maximal 45 Sekunden in der Zukunft (höchstens bis zum Timer-Ende). Ohne Bestätigung zeigt das Widget nach Verarbeitung durch iOS „Status nicht bestätigt – App öffnen“ und kein ON. `staleDate` beendet eine Live Activity nicht selbst; Render-/Systemverzögerungen sind möglich, 45 Sekunden sind keine garantierte Obergrenze. Beim nächsten Start erfolgt zusätzlich die Bereinigung. Diese Einschränkung kann mit öffentlichen lokalen APIs nicht vollständig beseitigt werden.

Live Activities haben zudem eine von iOS begrenzte Lebensdauer (normalerweise bis zu acht Stunden). Unbegrenzt bezieht sich auf den Vordergrund-Idle-Timer, nicht auf eine unbegrenzt garantierte Dynamic-Island-Anzeige. Endet die Live Activity, zeigt die Haupt-App einen Hinweis und kann weiter aktiv bleiben.

## Struktur

- `ScreenOn/`: App, SwiftUI-Ansicht, MainActor-ViewModel und Lifecycle.
- `Shared/ScreenActivityAttributes.swift`: gemeinsames ActivityKit-Datenmodell, in beiden Targets eingebunden.
- `ScreenOnActivity/`: WidgetKit-Extension mit allen Dynamic-Island-Größen und Sperrbildschirmansicht.
- `ScreenOn/Assets.xcassets/AppIcon.appiconset/`: vorbereiteter Icon-Platzhalter. In Xcode ein opakes 1024×1024-PNG einsetzen, z. B. dunkler Hintergrund mit weißem Display-/Sonnensymbol. Ein fertiges Icon ist für eine spätere Veröffentlichung noch nötig.
- `.github/workflows/ios.yml`: Build beider Targets auf einem macOS-Runner mit dessen neuester installierter stabiler Xcode-Version. Die tatsächlich verwendete Version steht im Log; Runner können hinter Apples neuester Veröffentlichung liegen.

## Prüfen

Lokal auf einem Mac:

```sh
xcodebuild -project ScreenOn.xcodeproj -scheme ScreenOn \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

Die Erstellung erfolgte in einer Linux-Umgebung ohne Xcode/Apple SDK. Dort wurden Projektverweise, Property Lists und Swift-Code statisch geprüft; dies ersetzt keinen erfolgreichen Xcode-Build oder Gerätetest. Den tatsächlichen Build-Status unter GitHub **Actions → iOS Build** kontrollieren.

Geräte-Abnahme:

1. Auto-Sperre auf kurze Zeit stellen. Aktivieren und länger warten: Display bleibt an; deaktivieren: normale Sperre kehrt zurück.
2. Alle Timer-Auswahlen prüfen; eine laufende Sitzung behält ihr ursprüngliches Limit. Für eine kurze Entwicklungsprüfung temporär die Multiplikation mit 60 reduzieren und vor Auslieferung zurücksetzen.
3. Schnelles Ein-/Ausschalten: höchstens eine aktuelle Live Activity, keine wiederauferstandene alte Anzeige.
4. Home-Geste, Sperrtaste, Kontrollzentrum, Anruf/Systemunterbrechung: Sitzung endet, Rückkehr zeigt AUS.
5. App beenden/Prozess abbrechen: nach Ablauf der Gültigkeit kein bestätigtes ON; Neustart bereinigt alte Aktivitäten.
6. Live Activities verweigern bzw. manuell entfernen: Hauptfunktion bleibt nutzbar, verständlicher Hinweis.
7. Dynamic Island kompakt/minimal/erweitert, große Schrift, VoiceOver, Dark/Light Mode sowie Gerät ohne Dynamic Island prüfen.

## Apple-Dokumentation

- [isIdleTimerDisabled](https://developer.apple.com/documentation/uikit/uiapplication/isidletimerdisabled)
- [Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)
- [staleDate](https://developer.apple.com/documentation/activitykit/activitycontent/staledate)
- [isStale](https://developer.apple.com/documentation/widgetkit/activityviewcontext/isstale)
