class AppStrings {
  // App
  static const String appName = 'Chakka Saarthi';
  static const String fleetManagement = 'Fleet Management';

  // Auth
  static const String login = 'Login';
  static const String userId = 'User ID';
  static const String password = 'Password';
  static const String mpin = 'MPIN';
  static const String enterUserId = 'Enter User ID';
  static const String enterPassword = 'Enter Password';
  static const String enterMpin = 'Enter 4-Digit MPIN';
  static const String confirmMpin = 'Confirm Your MPIN';
  static const String loginWithMpin = 'Login with MPIN';
  static const String loginWithMobile = 'Login with Mobile Number';
  static const String setMpinSubtitle = 'You will use this to login next time';
  static const String mpinMismatch = 'MPINs do not match. Please try again.';

  // Dashboard
  static const String createNewTrip = 'Create New Trip';
  static const String inTransit = 'In Transit';
  static const String completedTrips = 'Completed Trips';
  static const String vehicleAvailable = 'Vehicle Available';
  static const String maintenance = 'Maintenance';
  static const String reports = 'Reports';
  static const String assignedTickets = 'Assigned Tickets';

  // Forms
  static const String selectVehicle = 'Select Vehicle';
  static const String selectDriver = 'Select Driver';
  static const String lrNumber = 'LR Number';
  static const String journeyFrom = 'Journey From';
  static const String journeyTo = 'Journey To';
  static const String consigneeName = 'Consigner Name';
  static const String product = 'Product';
  static const String loadingWeight = 'Loading Weight (Kgs)';
  static const String unloadingWeight = 'Unloading Weight (Kgs)';
  static const String shortageWeight = 'Shortage (Kgs)';
  static const String loadingDate = 'Loading Date';
  static const String unloadingDate = 'Unloading Date';
  static const String reason = 'Reason';
  static const String expectedReturn = 'Expected Return';
  static const String reportingDate = 'Reporting Date';
  static const String challanDocument = 'Challan/Document';
  static const String scanUpload = 'Scan & Upload';

  // Buttons
  static const String assignTicket = 'ASSIGN TICKET';
  static const String submitLoading = 'SUBMIT LOADING STATUS';
  static const String submitUnloading = 'SUBMIT UNLOADING STATUS';
  static const String markAvailable = 'Mark Available';
  static const String addMaintenance = 'Add to Maintenance';
  static const String addDriver = 'Add Driver';
  static const String addVehicle = 'Add Vehicle';
  static const String resetMpin = 'Reset MPIN';
  static const String exportExcel = 'Export Excel';
  static const String exportReport = 'Export Report';
  static const String reassignTrip = 'Reassign Trip';
  static const String importVehicles = 'Import Vehicles';
  static const String exportMonthlyReport = 'Export Monthly Report';
  static const String tripCompletionReport = 'Trip Completion Report';

  // Status
  static const String statusAvailable = 'Available';
  static const String statusInTransit = 'In Transit';
  static const String statusMaintenance = 'Maintenance';
  static const String statusCompleted = 'Completed';
  static const String statusAssigned = 'Assigned';
  static const String statusCancelled = 'Cancelled';

  // Messages
  static const String loadingSubmitted = 'Loading details submitted. Trip is now in transit.';
  static const String unloadingSubmitted = 'Trip completed successfully.';
  static const String noTripsInTransit = 'No trips in transit';
  static const String noCompletedTrips = 'No completed trips';
  static const String allVehiclesAssigned = 'All vehicles are currently assigned';
  static const String driverActiveTripError = 'Driver already has an active trip';
  static const String completeLoadingFirst = 'Please complete Loading Status first';
  static const String challanRequired = 'Please scan and upload challan/document before submitting';
  static const String tripReassigned = 'Trip has been reassigned successfully';
  static const String reportingDateRequired = 'Reporting date is required';
  static const String weightMustBeNumeric = 'Weight must be a numeric value';

  // Driver Section
  static const String loadingDetails = 'Loading Details';
  static const String unloadingDetails = 'Unloading Details';
  static const String tripSequence = 'Complete trip in sequence: Loading → Unloading → Reporting → Upload Challan';
  static const String detentionDays = 'Detention Days';

  // Vehicle Import
  static const String importFromCSV = 'Import from CSV';
  static const String importFromExcel = 'Import from Excel';
  static const String selectFile = 'Select File';
  static const String uploading = 'Uploading...';

  // Driver Management
  static const String driverName = 'Driver Name';
  static const String phoneNumber = 'Phone Number';
  static const String drivingLicense = 'Driving License';
  static const String aadhaarCard = 'Aadhaar Card';
  static const String uploadDocument = 'Upload Document';
  static const String removeDriver = 'Remove Driver';
  static const String deactivateDriver = 'DEACTIVATE DRIVER';
  static const String activateDriver = 'ACTIVATE DRIVER';

  // Language
  static const String language = 'Language';
  static const String english = 'English';
  static const String hindi = 'Hindi';

  // Reports
  static const String overallSummary = 'Trip Summary';
  static const String vehicleWise = 'Vehicle-wise';
  static const String monthlyReport = 'Monthly Report';
  static const String consolidatedReport = 'Consolidated Report';
}
