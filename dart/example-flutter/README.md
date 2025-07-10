# WinCC Monitor Flutter App

A Flutter application that connects to WinCC Unified GraphQL servers to monitor SCADA system data.

## Features

- **Login Page**: Connect to any WinCC Unified GraphQL server
- **Real-time Dashboard**: Display live tag values with quality indicators
- **Power Gauges**: Visual gauges for power meter readings
- **Historical Charts**: Line charts showing 3-hour power history
- **Alerts Page**: View active alarms and alerts

## Tag Monitoring

The app monitors these demo tags:
- `HMI_Tag_1` and `HMI_Tag_2` (demo values display)
- `Meter_Input_WattAct`, `Meter_Output_WattAct`, `PV_Power_WattAct` (live gauges)

For historical data, it uses these logging tags:
- `Meter_Input_Value:LoggingTag_1`
- `Meter_Output_Value:LoggingTag_1` 
- `PV_Power_WattAct:LoggingTag_1`

## Prerequisites

1. **Flutter SDK** installed on your system
2. **Android Studio/Xcode** or any IDE with Flutter support  
3. **Device/Emulator** (Android device, iOS device, emulator, or desktop)

## How to Build and Start

### **Step 1: Navigate to the App Directory**
```bash
cd /path/to/winccua-graphql-libs/dart/flutter_app
```

### **Step 2: Install Dependencies**
```bash
flutter pub get
```

### **Step 3: Check Available Devices**
```bash
flutter devices
```
This shows all connected devices and emulators.

### **Step 4: Run the App**

**For any available device:**
```bash
flutter run
```

**For specific device:**
```bash
flutter run -d <device-id>
```

**Platform-specific commands:**
```bash
# Android device/emulator
flutter run -d android

# iOS device/simulator (macOS only)
flutter run -d ios

# Linux desktop
flutter run -d linux

# Windows desktop  
flutter run -d windows

# macOS desktop
flutter run -d macos

# Web browser
flutter run -d chrome
```

### **Step 5: Development Mode**
For development with hot reload:
```bash
flutter run --debug
```

### **Step 6: Build Release**
To create release builds:
```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS (on macOS)
flutter build ios --release

# Linux desktop
flutter build linux --release

# Windows desktop
flutter build windows --release

# Web
flutter build web --release
```

### **Troubleshooting**

**If you get dependency errors:**
```bash
flutter clean
flutter pub get
```

**If you need to check for issues:**
```bash
flutter doctor
flutter analyze
```

**During development:**
- Press `r` in terminal for hot reload
- Press `R` for hot restart  
- Press `q` to quit

**Android SDK issues:**
```bash
# Set Android SDK path if needed
export ANDROID_HOME=/path/to/android/sdk
export PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools
```

## Usage

1. **Login**: Enter your WinCC Unified GraphQL server URL (e.g., `https://server/graphql`)
2. **Credentials**: Provide your username and password
3. **Dashboard**: View real-time tag values and power meters
4. **Charts**: Monitor 3-hour historical trends
5. **Alerts**: Check active alarms (refresh manually)

## Architecture

- **State Management**: Provider pattern
- **GraphQL Client**: WinCC UA GraphQL Client library
- **Charts**: FL Chart for line charts
- **Gauges**: Syncfusion Flutter Gauges
- **Local Storage**: SharedPreferences for server URL

## Dependencies

- `winccua_graphql_client`: Local WinCC UA client library
- `syncfusion_flutter_gauges`: Gauge widgets
- `fl_chart`: Line charts
- `provider`: State management
- `shared_preferences`: Local storage