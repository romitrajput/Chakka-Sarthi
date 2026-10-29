# Chakka Saarthi - Fleet Management App

A comprehensive Flutter-based fleet management application for managing vehicles, drivers, and trip assignments. Built with Supabase backend integration.

## 📱 App Features

### Admin Features
- **Dashboard**: Overview of fleet status, active trips, and alerts
- **Create Trip**: Assign vehicles and drivers to new trips
- **Trip Management**: View in-transit, assigned, and completed trips
- **Vehicle Management**: Add/import vehicles, manage availability & maintenance
- **Driver Management**: Add, view, and manage drivers
- **Reports**: Vehicle-wise reports, monthly reports, PDF export
- **Notifications**: Real-time push notifications for trip updates

### Driver Features
- **Dashboard**: View assigned trips and notifications
- **Trip Details**: View loading/unloading status
- **Loading/Unloading Forms**: Submit trip status updates
- **Multi-language Support**: English, Hindi, Marathi, and more

## 🚀 Tech Stack

| Component | Technology |
|-----------|------------|
| Framework | Flutter 3.x (Dart 3.12+) |
| Backend | Supabase (PostgreSQL) |
| State Management | Flutter Riverpod |
| Routing | Go Router |
| Authentication | Custom MPIN + Mobile auth |
| Notifications | flutter_local_notifications + ML Kit Translation |
| PDF Generation | pdf + printing packages |
| File Handling | image_picker, file_picker |

## 📋 Prerequisites

- Flutter SDK (^3.12.2)
- Dart (^3.12.2)
- Android Studio / Xcode (for mobile builds)
- A Supabase project (see setup below)

## 🛠️ Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/fleet.git
cd fleet
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Supabase

1. Create a `.env` file in the project root (copy from `.env.example`)
2. Set up your Supabase project at [supabase.com](https://supabase.com)
3. Create the required tables (see Database Schema below)
4. Add your Supabase URL and Anon Key to `.env`

### 4. Run the App

```bash
# For Android
flutter run -d android

# For iOS
flutter run -d ios

# For Web
flutter run -d chrome
```

## 📁 Project Structure

```
fleet/
├── lib/
│   ├── app.dart              # App configuration, routing, theme
│   ├── main.dart             # App entry point
│   ├── core/
│   │   ├── constants/        # Colors, strings, translations, Supabase config
│   │   ├── utils/            # Date formatting, notifications, PDF, translation
│   │   └── widgets/          # Reusable UI components
│   ├── models/               # Data models (Ticket, Vehicle, User, etc.)
│   ├── providers/            # Riverpod providers for state management
│   ├── repositories/         # Data access layer (Supabase queries)
│   └── screens/
│       ├── admin/            # Admin-specific screens
│       ├── driver/           # Driver-specific screens
│       └── auth/             # Login & MPIN screens
├── assets/
│   └── images/               # App images and assets
├── test/                     # Unit and widget tests
├── pubspec.yaml              # Dependencies
└── README.md
```

## 🗄️ Database Schema

### Tables

| Table | Description |
|-------|-------------|
| `companies` | Company information and settings |
| `users` | Driver and admin user accounts |
| `vehicles` | Vehicle fleet data |
| `tickets` | Trip/ticket records |
| `loading_status` | Loading trip details |
| `unloading_status` | Unloading trip details |
| `notifications` | User notifications |
| `trip_reassignments` | Trip reassignment history |

### Storage Buckets

| Bucket | Purpose |
|--------|---------|
| `trip-documents` | Trip completion PDFs |
| `challan-documents` | Challan/document images |
| `driver-documents` | Driver license/Aadhaar images |

## 🔐 Authentication Flow

1. **First Login**: User logs in with User ID + Mobile number, then sets MPIN
2. **Subsequent Logins**: User logs in with User ID + MPIN
3. **Reset MPIN**: Admin can reset MPIN, requiring mobile login again

## 🌐 Multi-language Support

Supported languages:
- English (en)
- Hindi (hi)
- Marathi (mr)
- Gujarati (gu)
- Bengali (bn)
- Tamil (ta)
- Telugu (te)
- Kannada (kn)
- Urdu (ur)

Translation uses Google ML Kit for offline translation of notifications.

## 🔧 Development

### Code Generation

This project uses `riverpod_generator` for code generation. After modifying providers:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Running Tests

```bash
flutter test
```

### Building APK

```bash
flutter build apk --release
```

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

### Quick Start for Contributors

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run `flutter pub get` and `flutter analyze`
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## 📄 License

This project is proprietary and confidential.

## 👥 Team

- **Sanjay Roadlines** - Original Author

## 📞 Support

For questions or issues, please open an issue in the GitHub repository.
