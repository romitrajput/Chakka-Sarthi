import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Comprehensive translations for all supported languages
class AppTranslations {
  static const Map<String, Map<String, String>> _translations = {
    'en': {
      // General
      'appName': 'Sanjay Roadlines',
      'fleetManagement': 'Fleet Management',
      'loading': 'Loading...',
      'error': 'Error',
      'cancel': 'Cancel',
      'ok': 'OK',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'close': 'Close',
      'back': 'Back',
      'next': 'Next',
      'yes': 'Yes',
      'no': 'No',
      
      // Auth
      'login': 'Login',
      'logout': 'Logout',
      'logoutConfirm': 'Are you sure you want to logout?',
      'userId': 'User ID',
      'password': 'Password',
      'mpin': 'MPIN',
      'enterUserId': 'Enter User ID',
      'enterPassword': 'Enter Password',
      'enterMpin': 'Enter 4-Digit MPIN',
      'confirmMpin': 'Confirm Your MPIN',
      'loginWithMpin': 'Login with MPIN',
      'loginWithMobile': 'Login with Mobile Number',
      
      // Dashboard
      'welcomeBack': 'Welcome back',
      'hello': 'Hello',
      'createNewTrip': 'Create New Trip',
      'inTransit': 'In Transit',
      'completedTrips': 'Completed Trips',
      'vehicleAvailable': 'Vehicle Available',
      'vehicles': 'Vehicles',
      'maintenance': 'Maintenance',
      'dashboard': 'Dashboard',
      'manageDrivers': 'Manage Drivers',
      'assignedTickets': 'Assigned Tickets',
      'notifications': 'Notifications',
      
      // Stats
      'totalVehicles': 'Total Vehicles',
      'completedToday': 'Completed Today',
      'pendingMaintenance': 'Pending Maintenance',
      'available': 'Available',
      
      // Vehicle
      'selectVehicle': 'Select Vehicle',
      'vehicleNumber': 'Vehicle Number',
      'sendToMaintenance': 'Send to Maintenance',
      'markAvailable': 'Mark Available',
      'removeVehicle': 'Remove Vehicle',
      'noVehiclesAvailable': 'No vehicles available',
      'noVehiclesMaintenance': 'No vehicles in maintenance',
      'vehiclesAvailable': 'vehicles available',
      'vehiclesMaintenance': 'vehicles in maintenance',
      
      // Maintenance
      'addMaintenance': 'Add to Maintenance',
      'reason': 'Reason',
      'from': 'From',
      'expectedReturn': 'Expected Return',
      'maintenanceReason': 'Maintenance Reason',
      'addMaintenanceTitle': 'Add to Maintenance',
      'saveMaintenance': 'SAVE MAINTENANCE',
      'noMaintenanceVehicles': 'No vehicles in maintenance',
      
      // Trip
      'assignTicket': 'ASSIGN TICKET',
      'selectDriver': 'Select Driver',
      'assignVehicleDriver': 'Assign Vehicle & Driver',
      'ticketAssigned': 'Ticket Assigned Successfully',
      'driverAlreadyActive': 'Driver already has an active trip',
      'vehicleNotAvailable': 'Vehicle is not available',
      
      // Loading/Unloading
      'loadingDetails': 'Loading Details',
      'unloadingDetails': 'Unloading Details',
      'submitLoading': 'SUBMIT LOADING STATUS',
      'submitUnloading': 'SUBMIT UNLOADING STATUS',
      'loadingStatus': 'LOADING STATUS',
      'unloadingStatus': 'UNLOADING STATUS',
      'lrNumber': 'LR Number',
      'journeyFrom': 'Journey From',
      'journeyTo': 'Journey To',
      'consigneeName': 'Consigner Name',
      'product': 'Product',
      'loadingWeight': 'Loading Weight (Kgs)',
      'unloadingWeight': 'Unloading Weight (Kgs)',
      'shortage': 'Shortage (Kgs)',
      'loadingDate': 'Loading Date',
      'unloadingDate': 'Unloading Date',
      'reportingDate': 'Reporting Date',
      'challanDocument': 'Challan/Document',
      'camera': 'Camera',
      'gallery': 'Gallery',
      
      // Trip Detail
      'vehicle': 'Vehicle',
      'driver': 'Driver',
      'assigned': 'Assigned',
      'status': 'Status',
      'completed': 'Completed',
      'detention': 'Detention',
      'days': 'days',
      
      // Reports
      'reports': 'Dashboard',
      'tripSummary': 'Trip Summary',
      'vehicleWise': 'Vehicle-wise',
      'exportReport': 'Export Report',
      'totalTrips': 'Total Trips',
      'exportReportTitle': 'Vehicle-wise Export Report',
      'exportReportDesc': 'Select a date range and vehicle to generate a consolidated PDF report.',
      'selectDateRange': 'Select Date Range',
      'exportPdf': 'EXPORT REPORT',
      
      // Notifications
      'popUpNotifications': 'Pop-up Notifications',
      'popUpNotificationsDesc': 'Receive pop-ups for trip updates',
      'noUnreadNotifications': 'No unread notifications',
      'tripReassigned': 'Trip Reassigned',
      
      // Language
      'selectLanguage': 'Select Language',
      'selectLanguageDesc': 'Choose your preferred language for the app',
      'switchingTo': 'Switching to',
      'languageChanged': 'Language changed to',
      
      // Account Settings
      'accountSettings': 'Account Settings',
      'resetMpin': 'Reset MPIN',
      'resetMpinDesc': 'Reset MPIN and login with mobile number',
      'resetMpinConfirm': 'Your MPIN will be reset. You will need to login with your mobile number to set a new MPIN. Do you want to continue?',
      'mpinResetSuccess': 'MPIN has been reset. You can now login with your mobile number.',
      'mpinResetFailed': 'Failed to reset MPIN',
      
      // Messages
      'allClear': 'All clear!',
      'noActiveTrips': 'No active trips',
      'tripWaiting': 'trip(s) waiting for you',
      'noTripsInTransit': 'No trips in transit',
      'noCompletedTrips': 'No completed trips',
      
      // Fleet Overview
      'fleetOverview': 'Fleet Overview',
      'inTransitLabel': 'In Transit',
      
      // Alerts
      'recentAlerts': 'Recent Alerts',
      'maintenanceDue': 'Maintenance due',
      'pendingTrips': 'Pending trips',
      'tripsActive': 'trip(s) active',
    },
    'hi': {
      // General
      'appName': 'संजय रोडलाइन्स',
      'fleetManagement': 'फ्लीट प्रबंधन',
      'loading': 'लोड हो रहा है...',
      'error': 'त्रुटि',
      'cancel': 'रद्द करें',
      'ok': 'ठीक है',
      'save': 'सहेजें',
      'delete': 'हटाएं',
      'edit': 'संपादित करें',
      'close': 'बंद करें',
      'back': 'वापस',
      'next': 'अगला',
      'yes': 'हाँ',
      'no': 'नहीं',
      
      // Auth
      'login': 'लॉगिन',
      'logout': 'लॉगआउट',
      'logoutConfirm': 'क्या आप वाकई लॉगआउट करना चाहते हैं?',
      'userId': 'यूजर आईडी',
      'password': 'पासवर्ड',
      'mpin': 'एमपिन',
      'enterUserId': 'यूजर आईडी दर्ज करें',
      'enterPassword': 'पासवर्ड दर्ज करें',
      'enterMpin': '4 अंकों का एमपिन दर्ज करें',
      'confirmMpin': 'अपना एमपिन पुष्टि करें',
      'loginWithMpin': 'एमपिन से लॉगिन करें',
      'loginWithMobile': 'मोबाइल नंबर से लॉगिन करें',
      
      // Dashboard
      'welcomeBack': 'वापस स्वागत है',
      'hello': 'नमस्ते',
      'createNewTrip': 'नई यात्रा बनाएं',
      'inTransit': 'रास्ते में',
      'completedTrips': 'पूर्ण यात्राएं',
      'vehicleAvailable': 'वाहन उपलब्ध',
      'vehicles': 'वाहन',
      'maintenance': 'रखरखाव',
      'dashboard': 'डैशबोर्ड',
      'manageDrivers': 'चालक प्रबंधन',
      'assignedTickets': 'सौंपे गए टिकट',
      'notifications': 'सूचनाएं',
      
      // Stats
      'totalVehicles': 'कुल वाहन',
      'completedToday': 'आज पूर्ण',
      'pendingMaintenance': 'लंबित रखरखाव',
      'available': 'उपलब्ध',
      
      // Vehicle
      'selectVehicle': 'वाहन चुनें',
      'vehicleNumber': 'वाहन नंबर',
      'sendToMaintenance': 'रखरखाव में भेजें',
      'markAvailable': 'उपलब्ध चिह्नित करें',
      'removeVehicle': 'वाहन हटाएं',
      'noVehiclesAvailable': 'कोई वाहन उपलब्ध नहीं',
      'noVehiclesMaintenance': 'रखरखाव में कोई वाहन नहीं',
      'vehiclesAvailable': 'वाहन उपलब्ध',
      'vehiclesMaintenance': 'वाहन रखरखाव में',
      
      // Maintenance
      'addMaintenance': 'रखरखाव में जोड़ें',
      'reason': 'कारण',
      'from': 'से',
      'expectedReturn': 'अपेक्षित वापसी',
      'maintenanceReason': 'रखरखाव कारण',
      'addMaintenanceTitle': 'रखरखाव में जोड़ें',
      'saveMaintenance': 'रखरखाव सहेजें',
      'noMaintenanceVehicles': 'रखरखाव में कोई वाहन नहीं',
      
      // Trip
      'assignTicket': 'टिकट सौंपें',
      'selectDriver': 'चालक चुनें',
      'assignVehicleDriver': 'वाहन और चालक सौंपें',
      'ticketAssigned': 'टिकट सफलतापूर्वक सौंपा गया',
      'driverAlreadyActive': 'चालक के पास पहले से एक सक्रिय यात्रा है',
      'vehicleNotAvailable': 'वाहन उपलब्ध नहीं है',
      
      // Loading/Unloading
      'loadingDetails': 'लोडिंग विवरण',
      'unloadingDetails': 'अनलोडिंग विवरण',
      'submitLoading': 'लोडिंग स्थिति सबमिट करें',
      'submitUnloading': 'अनलोडिंग स्थिति सबमिट करें',
      'loadingStatus': 'लोडिंग स्थिति',
      'unloadingStatus': 'अनलोडिंग स्थिति',
      'lrNumber': 'एलआर नंबर',
      'journeyFrom': 'यात्रा कहां से',
      'journeyTo': 'यात्रा कहां तक',
      'consigneeName': 'संवाहक का नाम',
      'product': 'उत्पाद',
      'loadingWeight': 'लोडिंग वजन (किग्रा)',
      'unloadingWeight': 'अनलोडिंग वजन (किग्रा)',
      'shortage': 'कमी (किग्रा)',
      'loadingDate': 'लोडिंग तिथि',
      'unloadingDate': 'अनलोडिंग तिथि',
      'reportingDate': 'रिपोर्टिंग तिथि',
      'challanDocument': 'चालान/दस्तावेज',
      'camera': 'कैमरा',
      'gallery': 'गैलरी',
      
      // Trip Detail
      'vehicle': 'वाहन',
      'driver': 'चालक',
      'assigned': 'सौंपा गया',
      'status': 'स्थिति',
      'completed': 'पूर्ण',
      'detention': 'अवरोध',
      'days': 'दिन',
      
      // Reports
      'reports': 'डैशबोर्ड',
      'tripSummary': 'यात्रा सारांश',
      'vehicleWise': 'वाहन-वार',
      'exportReport': 'रिपोर्ट निर्यात करें',
      'totalTrips': 'कुल यात्राएं',
      'exportReportTitle': 'वाहन-वार रिपोर्ट निर्यात',
      'exportReportDesc': 'एक समेकित PDF रिपोर्ट बनाने के लिए तिथि सीमा और वाहन चुनें।',
      'selectDateRange': 'तिथि सीमा चुनें',
      'exportPdf': 'रिपोर्ट निर्यात करें',
      
      // Notifications
      'popUpNotifications': 'पॉप-अप सूचनाएं',
      'popUpNotificationsDesc': 'यात्रा अपडेट के लिए पॉप-अप सूचनाएं प्राप्त करें',
      'noUnreadNotifications': 'कोई अपठित सूचना नहीं',
      'tripReassigned': 'यात्रा पुनर्नियुक्त',
      
      // Language
      'selectLanguage': 'भाषा चुनें',
      'selectLanguageDesc': 'ऐप के लिए अपनी पसंदीदा भाषा चुनें',
      'switchingTo': 'स्विच कर रहे हैं',
      'languageChanged': 'भाषा बदली गई',
      
      // Account Settings
      'accountSettings': 'खाता सेटिंग्स',
      'resetMpin': 'एमपिन रीसेट करें',
      'resetMpinDesc': 'एमपिन रीसेट करें और मोबाइल नंबर से लॉगिन करें',
      'resetMpinConfirm': 'आपका MPIN रीसेट हो जाएगा। आपको अपने मोबाइल नंबर से लॉगिन करके नया MPIN सेट करना होगा। क्या आप जारी रखना चाहते हैं?',
      'mpinResetSuccess': 'MPIN रीसेट हो गया। अब आप मोबाइल नंबर से लॉगिन कर सकते हैं।',
      'mpinResetFailed': 'MPIN रीसेट विफल रहा',
      
      // Messages
      'allClear': 'सब स्पष्ट है!',
      'noActiveTrips': 'कोई सक्रिय यात्रा नहीं',
      'tripWaiting': 'यात्रा आपकी प्रतीक्षा में',
      'noTripsInTransit': 'कोई यात्रा रास्ते में नहीं',
      'noCompletedTrips': 'कोई पूर्ण यात्रा नहीं',
      
      // Fleet Overview
      'fleetOverview': 'फ्लीट अवलोकन',
      'inTransitLabel': 'रास्ते में',
      
      // Alerts
      'recentAlerts': 'हाल की चेतावनी',
      'maintenanceDue': 'रखरखाव बकाया',
      'pendingTrips': 'लंबित यात्राएं',
      'tripsActive': 'यात्रा सक्रिय',
    },
    'mr': {
      // General
      'appName': 'संजय रोडलाइन्स',
      'fleetManagement': 'फ्लीट व्यवस्थापन',
      'loading': 'लोड होत आहे...',
      'error': 'त्रुटी',
      'cancel': 'रद्द करा',
      'ok': 'ठीक आहे',
      'save': 'जतन करा',
      'delete': 'हटवा',
      'edit': 'संपादित करा',
      'close': 'बंद करा',
      'back': 'मागे',
      'next': 'पुढे',
      'yes': 'हो',
      'no': 'नाही',
      
      // Auth
      'login': 'लॉगिन',
      'logout': 'लॉगआउट',
      'logoutConfirm': 'तुम्हाला खात्रीने लॉगआउट करायचे आहे का?',
      'userId': 'यूझर आयडी',
      'password': 'पासवर्ड',
      'mpin': 'एमपिन',
      'enterUserId': 'यूझर आयडी प्रविष्ट करा',
      'enterPassword': 'पासवर्ड प्रविष्ट करा',
      'enterMpin': '4 अंकी एमपिन प्रविष्ट करा',
      'confirmMpin': 'तुमचा एमपिन पुष्टी करा',
      'loginWithMpin': 'एमपिनने लॉगिन करा',
      'loginWithMobile': 'मोबाइल नंबरने लॉगिन करा',
      
      // Dashboard
      'welcomeBack': 'परत स्वागत आहे',
      'hello': 'नमस्कार',
      'createNewTrip': 'नवीन प्रवास तयार करा',
      'inTransit': 'मार्गावर',
      'completedTrips': 'पूर्ण प्रवास',
      'vehicleAvailable': 'वाहन उपलब्ध',
      'vehicles': 'वाहने',
      'maintenance': 'देखभाल',
      'dashboard': 'डॅशबोर्ड',
      'manageDrivers': 'चालक व्यवस्थापन',
      'assignedTickets': 'सोपवलेले तिकीट',
      'notifications': 'सूचना',
      
      // Stats
      'totalVehicles': 'एकूण वाहने',
      'completedToday': 'आज पूर्ण',
      'pendingMaintenance': 'प्रलंबित देखभाल',
      'available': 'उपलब्ध',
      
      // Vehicle
      'selectVehicle': 'वाहन निवडा',
      'vehicleNumber': 'वाहन क्रमांक',
      'sendToMaintenance': 'देखभालीसाठी पाठवा',
      'markAvailable': 'उपलब्ध म्हणून चिन्हांकित करा',
      'removeVehicle': 'वाहन काढा',
      'noVehiclesAvailable': 'कोणतीही वाहने उपलब्ध नाहीत',
      'noVehiclesMaintenance': 'देखभालीत कोणतीही वाहने नाहीत',
      'vehiclesAvailable': 'वाहने उपलब्ध',
      'vehiclesMaintenance': 'वाहने देखभालीत',
      
      // Maintenance
      'addMaintenance': 'देखभालीत जोडा',
      'reason': 'कारण',
      'from': 'पासून',
      'expectedReturn': 'अपेक्षित परत',
      'maintenanceReason': 'देखभाल कारण',
      'addMaintenanceTitle': 'देखभालीत जोडा',
      'saveMaintenance': 'देखभाल जतन करा',
      'noMaintenanceVehicles': 'देखभालीत कोणतीही वाहने नाहीत',
      
      // Trip
      'assignTicket': 'तिकीट सोपवा',
      'selectDriver': 'चालक निवडा',
      'assignVehicleDriver': 'वाहन आणि चालक सोपवा',
      'ticketAssigned': 'तिकीट यशस्वीरित्या सोपवले',
      'driverAlreadyActive': 'चालकाकडे आधीच एक सक्रिय प्रवास आहे',
      'vehicleNotAvailable': 'वाहन उपलब्ध नाही',
      
      // Loading/Unloading
      'loadingDetails': 'लोडिंग तपशील',
      'unloadingDetails': 'अनलोडिंग तपशील',
      'submitLoading': 'लोडिंग स्थिती सबमिट करा',
      'submitUnloading': 'अनलोडिंग स्थिती सबमिट करा',
      'loadingStatus': 'लोडिंग स्थिती',
      'unloadingStatus': 'अनलोडिंग स्थिती',
      'lrNumber': 'एलआर नंबर',
      'journeyFrom': 'प्रवास कुठून',
      'journeyTo': 'प्रवास कुठपर्यंत',
      'consigneeName': 'संवाहकाचे नाव',
      'product': 'उत्पादन',
      'loadingWeight': 'लोडिंग वजन (किलो)',
      'unloadingWeight': 'अनलोडिंग वजन (किलो)',
      'shortage': 'तरी (किलो)',
      'loadingDate': 'लोडिंग तारीख',
      'unloadingDate': 'अनलोडिंग तारीख',
      'reportingDate': 'अहवाल तारीख',
      'challanDocument': 'चालान/दस्तऐवज',
      'camera': 'कॅमेरा',
      'gallery': 'गॅलरी',
      
      // Trip Detail
      'vehicle': 'वाहन',
      'driver': 'चालक',
      'assigned': 'सोपवले',
      'status': 'स्थिती',
      'completed': 'पूर्ण',
      'detention': 'अटक',
      'days': 'दिवस',
      
      // Reports
      'reports': 'डॅशबोर्ड',
      'tripSummary': 'प्रवास सारांश',
      'vehicleWise': 'वाहन-वार',
      'exportReport': 'अहवाल निर्यात करा',
      'totalTrips': 'एकूण प्रवास',
      'exportReportTitle': 'वाहन-वार अहवाल निर्यात',
      'exportReportDesc': 'एक समेकित PDF अहवाल तयार करण्यासाठी तारीख श्रेणी आणि वाहन निवडा.',
      'selectDateRange': 'तारीख श्रेणी निवडा',
      'exportPdf': 'अहवाल निर्यात करा',
      
      // Notifications
      'popUpNotifications': 'पॉप-अप सूचना',
      'popUpNotificationsDesc': 'प्रवास अपडेटसाठी पॉप-अप सूचना मिळवा',
      'noUnreadNotifications': 'कोणतीही न वाचलेली सूचना नाही',
      'tripReassigned': 'प्रवास पुन्हा नियुक्त',
      
      // Language
      'selectLanguage': 'भाषा निवडा',
      'selectLanguageDesc': 'अॅपसाठी तुमची पसंदीदा भाषा निवडा',
      'switchingTo': 'बदलत आहे',
      'languageChanged': 'भाषा बदलली',
      
      // Account Settings
      'accountSettings': 'खाते सेटिंग्ज',
      'resetMpin': 'एमपिन रीसेट करा',
      'resetMpinDesc': 'एमपिन रीसेट करा आणि मोबाइल नंबरने लॉगिन करा',
      'resetMpinConfirm': 'तुमचा MPIN रीसेट होईल. तुम्हाला नवीन MPIN सेट करण्यासाठी मोबाइल नंबरने लॉगिन करावा लागेल. तुम्हाला सुरू ठेवायचे आहे का?',
      'mpinResetSuccess': 'MPIN रीसेट झाला. आता तुम्ही मोबाइल नंबरने लॉगिन करू शकता.',
      'mpinResetFailed': 'MPIN रीसेट अयशस्वी',
      
      // Messages
      'allClear': 'सर्व स्पष्ट आहे!',
      'noActiveTrips': 'कोणताही सक्रिय प्रवास नाही',
      'tripWaiting': 'प्रवास तुमच्या प्रतीक्षेत',
      'noTripsInTransit': 'कोणताही प्रवास मार्गावर नाही',
      'noCompletedTrips': 'कोणताही पूर्ण प्रवास नाही',
      
      // Fleet Overview
      'fleetOverview': 'फ्लीट आढावा',
      'inTransitLabel': 'मार्गावर',
      
      // Alerts
      'recentAlerts': 'अलीकडील सूचना',
      'maintenanceDue': 'देखभाल देय',
      'pendingTrips': 'प्रलंबित प्रवास',
      'tripsActive': 'प्रवास सक्रिय',
    },
  };

  /// Get translated string for given key and locale
  static String translate(String key, Locale locale) {
    final langCode = locale.languageCode;
    return _translations[langCode]?[key] ?? _translations['en']?[key] ?? key;
  }

  /// Save language preference
  static Future<void> saveLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', languageCode);
  }

  /// Load saved language preference
  static Future<String> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('app_language') ?? 'en';
  }

  /// Get Locale from saved preference
  static Future<Locale> getSavedLocale() async {
    final code = await loadLanguage();
    return Locale(code);
  }
}

/// Helper extension for easy access
extension TranslateExtension on BuildContext {
  String tr(String key) {
    final locale = Localizations.localeOf(this);
    return AppTranslations.translate(key, locale);
  }
}
