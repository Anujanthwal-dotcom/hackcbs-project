// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'KisaanBandhu';

  @override
  String get appSubtitle => 'Smart Crop Disease & Pest Diagnosis';

  @override
  String get sihBranding => 'KisaanBandhu • SIH 2026';

  @override
  String get initializingApp => 'Initializing KisaanBandhu...';

  @override
  String get navScan => 'Scan';

  @override
  String get navMap => 'Map';

  @override
  String get navHelpDesk => 'Help Desk';

  @override
  String get navAssistant => 'Assistant';

  @override
  String get navProfile => 'Profile';

  @override
  String get loginTitle => 'Welcome to KisaanBandhu';

  @override
  String get loginSubtitle => 'Sign in to access crop diagnosis and advisory';

  @override
  String get createAccountTitle => 'Create Account';

  @override
  String get createAccountSubtitle =>
      'Join KisaanBandhu for smart farm management';

  @override
  String get fullNameLabel => 'Full Name';

  @override
  String get fullNameHint => 'Enter your full name';

  @override
  String get fullNameRequired => 'Full Name is required.';

  @override
  String get emailLabel => 'Email Address';

  @override
  String get emailHint => 'farmer@example.com';

  @override
  String get emailRequired => 'Please enter your email address.';

  @override
  String get emailInvalid => 'Please enter a valid email address.';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get passwordRequired => 'Please enter your password.';

  @override
  String get passwordLength => 'Password must be at least 6 characters.';

  @override
  String get confirmPasswordLabel => 'Confirm Password';

  @override
  String get confirmPasswordHint => 'Re-enter your password';

  @override
  String get confirmPasswordRequired => 'Please confirm your password.';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match.';

  @override
  String get signInButton => 'Sign In';

  @override
  String get registerButton => 'Create Account';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get signOutButton => 'Sign Out';

  @override
  String get signOutConfirmTitle => 'Sign Out';

  @override
  String get signOutConfirmMessage =>
      'Are you sure you want to sign out of your account?';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get editNameTitle => 'Edit Name';

  @override
  String get profileUpdated => 'Profile updated successfully.';

  @override
  String get profileTitle => 'Farmer Profile';

  @override
  String get accountInformation => 'Account Information';

  @override
  String get memberSince => 'Member Since';

  @override
  String get userIdLabel => 'User ID (UID)';

  @override
  String get guestUser => 'Guest User';

  @override
  String get diagnosisHistory => 'Diagnosis History';

  @override
  String get diagnosisHistorySubtitle =>
      'View saved crop disease & pest detections';

  @override
  String get languageTitle => 'Language / भाषा';

  @override
  String get languageSubtitle => 'Select your preferred language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHindi => 'हिन्दी (Hindi)';

  @override
  String get scanHeader => 'Smart Crop Scan';

  @override
  String get scanInstruction => 'Point camera at crop leaves and hold steady';

  @override
  String get analyzingCrop => 'Analyzing Crop...';

  @override
  String get tapToScan => 'Tap to scan crop';

  @override
  String get uploadFromGallery => 'Upload from Gallery';

  @override
  String get takePhoto => 'Take Photo';

  @override
  String get uploadPhoto => 'Upload Image';

  @override
  String get uploadImage => 'Upload Image';

  @override
  String get flashOn => 'Flash On';

  @override
  String get flashOff => 'Flash Off';

  @override
  String get switchCamera => 'Switch Camera';

  @override
  String get deepScanTitle => 'Detailed Crop Diagnosis';

  @override
  String get realtimeMetrics => 'Real-time Metrics';

  @override
  String get confidenceLabel => 'Confidence';

  @override
  String get marginLabel => 'Margin';

  @override
  String get clarityScoreLabel => 'Clarity Score';

  @override
  String get inferenceTimeLabel => 'Inference Time';

  @override
  String get mapTitle => 'Farm Map';

  @override
  String get markMyFarm => 'Mark My Farm';

  @override
  String get editFarmBoundary => 'Edit Boundary';

  @override
  String get saveBoundary => 'Save Boundary';

  @override
  String get clearBoundary => 'Clear';

  @override
  String get boundaryInstruction =>
      'Tap points on the map to define your farm boundary';

  @override
  String get insideFarm => 'Inside Farm';

  @override
  String get outsideFarm => 'Outside Farm';

  @override
  String get gpsHigh => 'GPS: High';

  @override
  String get gpsMedium => 'GPS: Medium';

  @override
  String get gpsLow => 'GPS: Low';

  @override
  String get gpsUnavailable => 'GPS: Unavailable';

  @override
  String get currentLocation => 'Current Location';

  @override
  String get farmArea => 'Farm Area';

  @override
  String get geotaggedScans => 'geotagged scans';

  @override
  String get navigate => 'Navigate';

  @override
  String get askAssistant => 'Ask Assistant';

  @override
  String get target => 'Target';

  @override
  String get location => 'Location';

  @override
  String get farmMarkerAttachedPhoto => 'Follow-up photo attached';

  @override
  String get assistantTitle => 'Agricultural Assistant';

  @override
  String get assistantHeader => 'KisaanBandhu Assistant';

  @override
  String get assistantWelcome =>
      'Hello Kisan! Ask me anything about crop diseases, pest management, fertilizers, or current weather advisory.';

  @override
  String get askQuestionHint => 'Ask about crops, pests, fertilizers...';

  @override
  String get send => 'Send';

  @override
  String get quickPrompt1 => 'How to control pink bollworm?';

  @override
  String get quickPrompt2 => 'Weather advisory for cotton';

  @override
  String get quickPrompt3 => 'Soybean whitefly prevention';

  @override
  String get quickPrompt4 => 'Organic fertilizers for crops';

  @override
  String get sourceChunks => 'Verified Knowledge Sources';

  @override
  String get weatherContextUsed => 'Local weather data applied';

  @override
  String get evaluatingWithGemma => 'Evaluating progression with Gemma…';

  @override
  String get runningMlClassifier => 'Running V4 ML classifier…';

  @override
  String get followUpPhotoAttached => 'Follow-up Photo Attached';

  @override
  String get askFollowUp => 'Ask Follow-up';

  @override
  String get takeAnotherPhoto => 'Take Another Photo';

  @override
  String get backToMap => 'Back to Map';

  @override
  String get pointHistoryTitle => 'Point Assessment History';

  @override
  String get pointAssessmentHistory => 'Point Assessment History';

  @override
  String visitsCount(Object count) {
    return '$count visits';
  }

  @override
  String get noPreviousAssessments =>
      'No previous assessments at this field point.';

  @override
  String visitNumber(Object number) {
    return 'Visit #$number';
  }

  @override
  String get diagnosisLabel => 'Diagnosis';

  @override
  String get adviceLabel => 'Advice';

  @override
  String get cropSoybean => 'Soybean';

  @override
  String get cropCotton => 'Cotton';

  @override
  String get cropUnknown => 'Unknown Crop';

  @override
  String get cropUnclear => 'Unclear';

  @override
  String get conditionHealthy => 'Healthy';

  @override
  String get conditionBacterialBlight => 'Bacterial Blight';

  @override
  String get conditionWhitefly => 'Whitefly';

  @override
  String get conditionPinkBollworm => 'Pink Bollworm';

  @override
  String get conditionImageUnclear => 'Image Unclear';

  @override
  String get conditionUncertain => 'Uncertain Detection';

  @override
  String get conditionNegative => 'Unsupported / Negative';

  @override
  String get stateImageUnclear => 'Image Unclear';

  @override
  String get stateUncertainLow => 'Low Confidence';

  @override
  String get stateUncertainMargin => 'Ambiguous Detection';

  @override
  String get stateNegative => 'Non-Target Plant';

  @override
  String get stateValid => 'Valid Detection';

  @override
  String get severityEarly => 'Early Stage';

  @override
  String get severityModerate => 'Moderate';

  @override
  String get severityWorsening => 'Worsening';

  @override
  String get severitySevere => 'Severe';

  @override
  String get severityUnknown => 'Unspecified';

  @override
  String get progressionInitial => 'Initial Detection';

  @override
  String get progressionStable => 'Stable';

  @override
  String get progressionImproved => 'Improved';

  @override
  String get progressionWorsening => 'Worsening';

  @override
  String get actionMonitor => 'Regular Monitoring';

  @override
  String get actionIntegrated => 'Integrated Pest Management (IPM)';

  @override
  String get actionChemical => 'Targeted Treatment';

  @override
  String get actionExpert => 'Expert Agricultural Consultation';

  @override
  String get weatherTemperature => 'Temperature';

  @override
  String get weatherHumidity => 'Humidity';

  @override
  String get weatherPrecipitation => 'Rainfall';

  @override
  String get weatherWind => 'Wind Speed';

  @override
  String get weatherRiskLow => 'Low Disease Risk';

  @override
  String get weatherRiskMedium => 'Medium Disease Risk';

  @override
  String get weatherRiskHigh => 'High Disease Risk';

  @override
  String get weatherConditions => 'Weather Conditions';

  @override
  String get notificationChannelName => 'Agricultural Alerts';

  @override
  String get notificationChannelDesc =>
      'Weather and disease risk alerts from KisaanBandhu';

  @override
  String get helpDeskTitle => 'Help Desk';

  @override
  String get helpDeskSubtitle => 'Find agricultural support near you';

  @override
  String get helpDeskLocating => 'Acquiring your location...';

  @override
  String helpDeskSearchingNear(Object location) {
    return 'Searching near $location';
  }

  @override
  String get helpDeskSearchingCurrent => 'Searching near your current location';

  @override
  String get helpDeskSearching => 'Finding agricultural support near you...';

  @override
  String get helpDeskNoResults => 'No agricultural support found nearby.';

  @override
  String helpDeskSearchWider(Object radius) {
    return 'Search Wider Area ($radius km)';
  }

  @override
  String get helpDeskSearchAgain => 'Search Again';

  @override
  String get helpDeskPermissionDenied =>
      'Location permission is required to find agricultural support near you.';

  @override
  String get helpDeskPermissionPermDenied =>
      'Location permission is permanently disabled. Please enable it in Settings.';

  @override
  String get helpDeskLocationDisabled =>
      'Location services are turned off. Please enable location to find nearby agricultural support.';

  @override
  String get helpDeskOfflineError =>
      'Unable to load nearby agricultural services. Please check your internet connection and try again.';

  @override
  String get helpDeskTryAgain => 'Try Again';

  @override
  String get helpDeskOpenSettings => 'Open Settings';

  @override
  String get categoryAll => 'All';

  @override
  String get categoryLabs => 'Labs';

  @override
  String get categoryExperts => 'Experts & KVK';

  @override
  String get categoryResearch => 'Research';

  @override
  String get categoryGovernment => 'Government';

  @override
  String get categoryDiseaseHelp => 'Disease Help';

  @override
  String get actionCall => 'Call';

  @override
  String get actionDirections => 'Directions';

  @override
  String get actionWebsite => 'Website';
}
