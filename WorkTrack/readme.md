# WorkTrack

Zelfgehoste workout tracker met meerdere frontends: een PHP webinterface, een Node.js API, een React dashboard, een React Native mobiele app en een Apple Watch app.

---

## Overzicht

| Component | Stack | Locatie |
|---|---|---|
| **PHP Webinterface** | PHP 8.1+ · MariaDB | `webapp/` |
| **API Backend** | Node.js · Express · SQLite | `backend/` |
| **Web Dashboard** | React · Vite · Chart.js | `web/` |
| **Mobiele app** | React Native · Expo | `mobile/` |
| **Apple Watch** | SwiftUI · CoreML · HealthKit | `watch/` · `ios/` |

---

## PHP Webinterface (webapp/)

De eenvoudigste manier om workouts bij te houden — geen Node.js of npm nodig. Werkt direct op een standaard LAMP/LEMP-stack.

### Vereisten

- PHP 8.1 of hoger
- MariaDB 10.6+ of MySQL 8+
- Apache of Nginx met PHP

### Installatie

**1. Database aanmaken**

```bash
mysql -u root -p < webapp/setup.sql
```

Dit maakt de `worktrack` database aan en vult 174 oefeningen in verdeeld over 13 spiergroepen.

**2. Config instellen**

```bash
cp webapp/config.example.php webapp/config.php
```

Pas `webapp/config.php` aan met je databasegegevens:

```php
define('DB_HOST', 'localhost');
define('DB_NAME', 'worktrack');
define('DB_USER', 'jouw_gebruiker');
define('DB_PASS', 'jouw_wachtwoord');
```

**3. Webserver configureren**

Wijs de document root van je webserver naar de projectmap zodat `/webapp/` bereikbaar is, of gebruik de ingebouwde PHP server voor lokaal gebruik:

```bash
php -S localhost:8080 -t .
```

Open de app op: `http://localhost:8080/webapp/`

### Functies

- **Dashboard** — totaalstatistieken, recente workouts
- **Workout loggen** — live timer, oefeningen zoeken en toevoegen, sets loggen met gewicht/reps of tijd/afstand, warming-up sets, auto-save
- **Geschiedenis** — alle workouts per maand, uitklapbare detailweergave
- **Oefeningenbibliotheek** — 174 ingebouwde oefeningen, eigen oefeningen toevoegen
- **Instellingen** — metrisch (kg/km) of imperiaal (lbs/miles), donker/licht thema
- **Geen npm/composer nodig** — puur PHP + vanilla JS

### Bestandsstructuur

```
webapp/
├── setup.sql               Database schema + 174 oefeningen
├── config.php              Databaseconfiguratie (niet in git)
├── config.example.php      Voorbeeld config
├── index.php               Dashboard
├── workout.php             Workout loggen
├── history.php             Workout geschiedenis
├── exercises.php           Oefeningenbibliotheek
├── settings.php            Instellingen
├── import.php              Oefeningen importeren (extra)
├── includes/
│   ├── db.php              PDO databaseverbinding
│   ├── functions.php       Hulpfuncties (eenheden, opmaak)
│   ├── header.php          Navigatie + HTML head
│   └── footer.php          Scripts + HTML close
├── api/
│   ├── workouts.php        REST API voor workouts/sets
│   ├── exercises.php       REST API voor oefeningen
│   └── import.php          Bulk import API
├── data/
│   └── exercises.php       Volledige oefeningen dataset
└── assets/
    ├── css/style.css       Stylesheet (donker thema)
    └── js/app.js           Vanilla JavaScript
```

---

## Node.js API Backend (backend/)

### Vereisten

- Node.js 22+ (LTS)
- npm 9+

### Starten

```bash
cd backend
npm install
node server.js
```

API draait op: `http://localhost:3001`

### Docker

```bash
docker build -t worktrack-backend ./backend
docker run -p 3001:3001 worktrack-backend
```

---

## React Web Dashboard (web/)

### Vereisten

- Node.js 22+

### Starten

```bash
cd web
npm install
npm run dev
```

Dashboard op: `http://localhost:5173`

### Functies

- Geauthenticeerd dashboard met grafieken en samenvattingen
- Publieke deelbare pagina's per gebruiker: `http://localhost:5173/public/<userId>`

---

## React Native Mobiele App (mobile/)

### Vereisten

- Node.js 22+
- Expo CLI

```bash
npm install -g expo-cli
```

### Starten

```bash
cd mobile
npm install
npx expo start
```

Scan de QR-code met de Expo Go app (Android/iOS). Zorg dat de backend draait op `http://localhost:3001`.

---

## Apple Watch App (watch/ · ios/)

1. Open `WorkoutWatchApp.xcodeproj` in Xcode
2. Zorg dat `ExerciseClassifier.mlmodel` is opgenomen in het Watch target
3. Build en run op je gekoppelde Apple Watch

De watch-app gebruikt **CoreML** voor bewegingsclassificatie en synchroniseert resultaten automatisch naar de backend.

---

## Alles tegelijk starten (Docker Compose)

```bash
docker compose up --build
```

- Backend: `http://localhost:3001`
- Web dashboard: `http://localhost:5173`

> De mobiele app en Apple Watch vereisen nog steeds de native omgeving (Expo/Xcode).

---

## Snel overzicht

| Onderdeel | Technologie |
|---|---|
| PHP webinterface | PHP 8.1 · MariaDB · Vanilla JS |
| API backend | Node.js · Express · SQLite |
| Web dashboard | React · Vite · Chart.js |
| Mobiele app | React Native · Expo |
| Apple Watch | SwiftUI · CoreML · HealthKit |
| Oefeningenbibliotheek | 174 oefeningen · 13 spiergroepen |
| Eenheden | Metrisch (NL) standaard · Imperiaal optioneel |
