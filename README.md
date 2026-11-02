# Shopping List App

Eine Einkaufslisten-App mit Flutter und Dart und lokaler Datenspeicherung in SQLite.

Die App hilft dabei, Einkäufe zu organisieren. In späteren Entwicklungsphasen soll sie Supermarktpreise vergleichen und dabei helfen, die Gesamtkosten des Einkaufs zu senken.

## Aktuelle Funktionen

### Produkte verwalten

- Produkte mit Namen und einer positiven, ganzzahligen Menge hinzufügen.
- Eingaben vor dem Hinzufügen auf Gültigkeit prüfen.
- Produkte als gekauft markieren und die Markierung wieder entfernen.
- Produkte nach Bestätigung löschen.
- Namen und Menge durch Antippen eines Produkts bearbeiten.
- Den Kaufstatus beim Bearbeiten beibehalten.
- Die Bearbeitung ohne Änderungen abbrechen.
- Beim Hinzufügen und Bearbeiten eine Kategorie auswählen.
- Die Kategorie neben der Menge anzeigen.
- Daten lokal über SQLite speichern und laden.
- Ladezustände und Fehlermeldungen anzeigen sowie fehlgeschlagene Vorgänge erneut versuchen.
- Eingaben nach einem fehlgeschlagenen Speichervorgang beibehalten.
- Wiederholte Aktionen für dasselbe Produkt während des Speicherns sperren und mehrfaches Speichern verhindern.

Die Menge bezeichnet eine ganzzahlige Anzahl von Stück oder Packungen. Dezimalmengen und Einheiten wie kg oder L werden derzeit nicht unterstützt.

Die Standardkategorie ist `other` (Sonstiges). Die Auswahl wird in SQLite gespeichert und bleibt nach einem Neustart erhalten.

### Mehrere Einkaufslisten

- Startseite mit den gespeicherten Listen.
- Neue Listen anlegen und leere Namen zurückweisen.
- Das Anlegen abbrechen oder nach einem Speicherfehler erneut versuchen.
- Doppelte Einträge durch wiederholtes Absenden beim Anlegen verhindern.
- Jede Liste mit ihrem Namen als Seitentitel öffnen.
- Produkte getrennt nach Liste laden und hinzufügen.
- Listen und Produkte nach einem Neustart beibehalten.

Bei der Migration bestehender Daten werden vorhandene Produkte der ursprünglichen Liste `Einkaufsliste` zugeordnet.

Listen lassen sich über die Schaltfläche mit dem Stiftsymbol umbenennen:

- Den bestehenden Namen im Dialog anzeigen.
- Leere Namen zurückweisen und Leerzeichen am Anfang und Ende entfernen.
- Ohne Namensänderung abbrechen.
- Eingaben nach einem Fehler beibehalten und einen erneuten Versuch ermöglichen.
- Mehrfaches Speichern durch wiederholtes Antippen verhindern.
- Die ID der Liste und ihre Produkte beibehalten.

Jede Liste, auch die ursprüngliche, kann nach Bestätigung gelöscht werden. Dabei werden alle zugehörigen Produkte innerhalb derselben Transaktion gelöscht. Bei einem Fehler bleiben die Daten erhalten und der Vorgang kann erneut versucht werden. Während des Löschvorgangs sind die Aktionen der betroffenen Liste gesperrt.

Auch alle Listen können gelöscht werden; über **+** lässt sich anschließend eine neue Liste anlegen.

Die Benutzeroberfläche ist derzeit auf Deutsch.

## Technologien

- Flutter / Dart
- SQLite über das Paket `sqflite`
- `path` für den Pfad zur Datenbankdatei
- `flutter_test` für automatisierte Tests

## Projektstruktur

```text
lib/
├── main.dart
├── models/
│   ├── shopping_category.dart
│   ├── shopping_item.dart
│   └── shopping_list.dart
├── repositories/
│   ├── shopping_repository.dart
│   └── shopping_list_repository.dart
├── screens/
│   ├── shopping_list_page.dart
│   └── shopping_lists_page.dart
├── services/
│   └── shopping_database.dart
└── widgets/
    └── shopping_category_field.dart

test/
├── shopping_item_test.dart
├── shopping_database_test.dart
├── shopping_repository_test.dart
├── shopping_list_page_test.dart
├── shopping_list_test.dart
├── shopping_list_repository_test.dart
└── shopping_lists_page_test.dart
```

- `main.dart`: Start und grundlegende Konfiguration der App.
- `shopping_item.dart`: Produktmodell mit `listId` und Konvertierung in und aus Maps.
- `shopping_list.dart`: Listenmodell mit ID und Namen.
- `shopping_list_repository.dart`: Listen lesen, anlegen, umbenennen und innerhalb einer Transaktion löschen.
- `shopping_lists_page.dart`: Startseite zum Auswählen, Anlegen, Umbenennen und Löschen von Listen.
- `shopping_category.dart`: Kategorien mit festen Datenbankcodes und deutschen Anzeigebezeichnungen.
- `shopping_repository.dart`: Produkte der ausgewählten Liste laden und hinzufügen, Namen, Menge und Kategorie bearbeiten, den Kaufstatus aktualisieren und Produkte löschen.
- `shopping_list_page.dart`: Produktansicht, Dialoge und Zustand der Benutzeroberfläche.
- `shopping_database.dart`: Datenbank öffnen, erstellen und migrieren.
- `shopping_category_field.dart`: Gemeinsames Kategorieauswahlfeld für das Hinzufügen und Bearbeiten; während des Speicherns deaktiviert.

Die Ansichten greifen über Repositories auf die Daten zu.

## Lokale Datenbank

Datenbankdatei: `shopping_list.db`

Aktuelle Schemaversion: `4`

Die Tabelle `shopping_lists` enthält `id` und `name`. Beim Erstellen der Datenbank wird die Liste `Einkaufsliste` mit der ID `1` angelegt. Sie kann wie jede andere Liste umbenannt oder gelöscht werden.

Die Tabelle `shopping_items` enthält:

| Feld | Beschreibung |
| --- | --- |
| `id` | Eindeutige Kennung |
| `name` | Produktname |
| `quantity` | Ganzzahlige Menge |
| `category` | Kategoriecode, Standardwert `other` |
| `isBought` | Kaufstatus: 0 oder 1 |
| `listId` | Zugehörige Liste des Produkts, Standardwert `1` |

Die Migration von Version 1 auf Version 2 ergänzt die Menge mit dem Standardwert 1. Bestehende Datensätze bleiben erhalten.

Die Migration von Version 2 auf Version 3 ergänzt die Kategorie mit dem Standardwert `other`. Die übrigen Felder bleiben erhalten.

Version 4 ergänzt die Listen und verknüpft Produkte über `listId` mit ihrer Liste. Migrationen von Version 1, 2 und 3 auf Version 4 werden unterstützt. Vorhandene Produkte werden der ursprünglichen Liste zugeordnet. Ihre Daten und die AUTOINCREMENT-Sequenz der IDs bleiben erhalten.

Der Fremdschlüssel verhindert das Speichern von Produkten mit einer nicht vorhandenen Liste. Ein Index auf `shopping_items.listId` unterstützt das Laden der Produkte einer Liste.

Die Daten werden lokal auf dem Gerät gespeichert. Es gibt keine Synchronisierung und kein Cloud-Backup.

## App in der Entwicklungsumgebung starten

Die App wird derzeit für Android entwickelt und getestet.

Benötigt werden ein mit `pubspec.yaml` kompatibles Flutter SDK, das Android SDK und ein verbundenes Android-Gerät oder ein Emulator.

Im Projektverzeichnis ausführen:

```powershell
flutter pub get
flutter devices
```

Die App auf dem gewünschten Android-Gerät starten. Dazu `<device-id>` durch dessen Geräte-ID ersetzen:

```powershell
flutter run -d <device-id>
```

Die vorhandenen Projektordner für andere Plattformen bedeuten nicht, dass die Funktionsfähigkeit auf diesen Plattformen bereits geprüft wurde.

## Tests und Codeanalyse

```powershell
flutter analyze
flutter test
```

Es gibt insgesamt **72 Tests**: 8 Modelltests, 5 Datenbanktests, 23 Repository-Tests und 36 Widget-Tests der Ansichten.

| Datei | Tests |
| --- | ---: |
| shopping_item_test.dart | 5 |
| shopping_list_test.dart | 3 |
| shopping_database_test.dart | 5 |
| shopping_repository_test.dart | 12 |
| shopping_list_repository_test.dart | 11 |
| shopping_list_page_test.dart | 18 |
| shopping_lists_page_test.dart | 18 |
| **Gesamt** | **72** |

### Modelle, Datenbank und grundlegende Repository-Funktionen

Die Tests prüfen:

- Standardwerte und Map-Konvertierungen von `ShoppingItem`.
- Die Standardkategorie und die Konvertierung des Kategoriecodes in und aus Maps.
- Das Erstellen einer Datenbank mit Version 4 und die SQLite-Standardwerte.
- Migrationen von Version 1, 2 und 3 auf Version 4 unter Beibehaltung der Produkte, ihrer Zuordnung zur ursprünglichen Liste und der ID-Sequenz.
- Das Zurückweisen von Produkten mit einer nicht vorhandenen Liste.
- Das Lesen einer leeren Liste.
- Das Hinzufügen und Abrufen von Produkten in Einfügereihenfolge.
- Das Ändern des Kaufstatus ausschließlich beim ausgewählten Produkt.
- Das Löschen ausschließlich des ausgewählten Produkts.
- Null betroffene Datensätze bei einer nicht vorhandenen ID.
- Die Weitergabe von Fehlern beim Öffnen der Datenbank an den aufrufenden Code.

### Produktansicht

Die ersten 8 Widget-Tests prüfen:

- Die Ladeanzeige und das Sperren der Hinzufügen-Funktion bis zum Abschluss des Ladens.
- Die Anzeige einer leeren Liste.
- Einen fehlgeschlagenen Ladevorgang mit anschließend erfolgreichem Wiederholungsversuch.
- Fehlgeschlagenes Hinzufügen mit Beibehaltung der Eingaben und erneutem Versuch.
- Das Verhindern doppelter Einträge durch wiederholtes Antippen von Hinzufügen.
- Eine fehlgeschlagene Aktualisierung des Kaufstatus mit erfolgreichem Wiederholungsversuch.
- Fehlgeschlagenes Löschen mit erfolgreichem Wiederholungsversuch.
- Den Abbruch des Löschens ohne Aufruf des Repositorys.

Die Produktbearbeitung wird durch 8 zusätzliche Tests geprüft.

Drei Repository-Tests:

- Nur das ausgewählte Produkt ändern und dabei ID und Kaufstatus beibehalten.
- Eine nicht vorhandene ID aktualisieren, ohne bestehende Produkte zu verändern.
- Ungültige Namen oder Mengen zurückweisen, ohne Daten zu verändern.

Fünf Widget-Tests:

- Ursprüngliche Werte anzeigen und Änderungen erfolgreich speichern.
- Ohne Speichern abbrechen und beim erneuten Öffnen die ursprünglichen Werte anzeigen.
- Ungültige Eingaben zurückweisen, bis sie korrigiert werden.
- Nach einem Speicherfehler einen erfolgreichen Wiederholungsversuch ermöglichen.
- Bei wiederholtem Antippen nur eine Aktualisierung ausführen.

Die Auswahl und Bearbeitung der Kategorie wird durch 5 zusätzliche Tests geprüft:

- Die Kategorie nur beim ausgewählten Produkt ändern und bei einer späteren Aktualisierung ohne Kategorieangabe beibehalten (Repository).
- Ein Produkt mit ausgewählter Kategorie hinzufügen und diese in der Liste anzeigen.
- Die Kategorie bearbeiten und die übrigen Produktdaten beibehalten.
- Eine Kategorieänderung ohne Speichern abbrechen.
- Nach einer fehlgeschlagenen Kategorieänderung die Auswahl beibehalten und einen erneuten Versuch ermöglichen.

### Mehrere Listen, Navigation und Umbenennen

Die Tests für mehrere Listen prüfen:

- Map-Konvertierungen des Listenmodells und das Beibehalten der `listId` eines Produkts.
- Das Lesen der ursprünglichen Liste, das Anlegen neuer Listen, die Einfügereihenfolge und die Namensvalidierung.
- Das Laden ausschließlich der Produkte der ausgewählten Liste.
- Das Beibehalten der Listenzuordnung in der Datenbank beim Bearbeiten eines Produkts.
- Die Übergabe der richtigen `listId` beim Hinzufügen aus der Produktansicht.
- Den Ladezustand, den leeren Zustand und das erneute Laden der Listenübersicht.
- Das Anlegen einer Liste einschließlich Validierung, Abbruch, Wiederholungsversuch nach einem Fehler und Schutz vor doppeltem Absenden.

Navigation und Umbenennen werden durch 9 zusätzliche Tests geprüft:

- Zwei unterschiedliche Listen mit den richtigen IDs, Titeln und Produkten öffnen und zur Startseite zurückkehren; dabei werden Test-Repositories verwendet.
- Nur die ausgewählte Liste umbenennen und dabei ID und Produkte beibehalten.
- Ungültige Namen zurückweisen, ohne Listen zu verändern.
- Null Aktualisierungen bei einer nicht vorhandenen Liste.
- Den ursprünglichen Namen anzeigen, Änderungen speichern und die Liste mit dem aktualisierten Namen erneut öffnen.
- Das Umbenennen ohne Speichern abbrechen.
- Ungültige Eingaben zurückweisen, bis sie korrigiert werden.
- Nach einem Fehler die Eingabe beibehalten und erfolgreich erneut speichern.
- Bei wiederholtem Antippen von Speichern nur eine Aktualisierung ausführen.

### Listen löschen

Die 8 zusätzlichen Tests zum Löschen von Listen prüfen:

- Nur die ausgewählte Liste und ihre Produkte löschen.
- Die ursprüngliche Liste löschen und anschließend eine neue Liste mit Produkten anlegen.
- Das Löschen der Produkte zurückrollen, wenn das Löschen der Liste fehlschlägt.
- Bei einer nicht vorhandenen ID den Wert `0` zurückgeben, ohne Daten zu verändern.
- Das Löschen in der Benutzeroberfläche bestätigen oder abbrechen.
- Die Liste nach einem Fehler beibehalten und erfolgreich erneut löschen.
- Aktionen während eines laufenden Löschvorgangs deaktivieren.

### Testumgebung und Grenzen

Die Widget-Tests verwenden Test-Repositories und greifen nicht auf die eigentliche Datenbank der App zu.

Die Datenbanktests verwenden `sqflite_common_ffi` und isolierte Testdatenbanken. Sie greifen nicht auf die Daten des Emulators zu.

Die Testabdeckung ist nicht vollständig. Noch nicht alle Navigationswege, wiederholten Checkbox- und Löschaktionen sowie möglichen SQLite-Fehler werden automatisch geprüft.

### Manuelle Prüfungen im Emulator

Zusätzlich wurden folgende Abläufe manuell geprüft:

- Produkte mit Mengen hinzufügen und ungültige Eingaben prüfen.
- Produkte als gekauft markieren und die Markierung wieder entfernen.
- Das Löschen abbrechen und bestätigen.
- Namen und Mengen bearbeiten sowie ohne Speichern abbrechen.
- Den Kaufstatus beim Bearbeiten beibehalten.
- Gespeicherte Änderungen nach Stop → Run beibehalten.
- Die Kategorie eines vorhandenen Produkts ändern, Änderungen abbrechen und die gespeicherte Kategorie nach Stop → Run beibehalten.
- Eine Liste auswählen, ihre Produkte öffnen und zur Startseite zurückkehren.
- Eine zweite Liste anlegen, Produkte getrennt verwalten und nach Stop → Run beibehalten.
- Listen umbenennen, den Vorgang abbrechen, leere Namen prüfen und den Titel aktualisieren.
- Den neuen Namen und die Produkte nach Stop → Run beibehalten.
- Alle Listen einschließlich der ursprünglichen löschen und den leeren Zustand anzeigen.
- Eine neue Liste mit zwei Produkten anlegen und nach Stop → Run beibehalten, ohne dass gelöschte Listen erneut erscheinen.

## Nächste Schritte

- Nach Abschluss und Dokumentation der Listenlöschung die nächste Funktion auswählen.

## Langfristiges Ziel

Schrittweise sollen Produkt- und Supermarktdaten, Preisvergleiche und die Berechnung des günstigsten gesamten Warenkorbs hinzukommen.

Die Entwicklung erfolgt Schritt für Schritt. Zuverlässigkeit und einfache Bedienung stehen dabei im Vordergrund.
