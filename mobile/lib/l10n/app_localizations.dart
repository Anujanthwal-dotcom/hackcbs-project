import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'KisaanBandhu'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Crop Disease & Pest Diagnosis'**
  String get appSubtitle;

  /// No description provided for @sihBranding.
  ///
  /// In en, this message translates to:
  /// **'KisaanBandhu • SIH 2026'**
  String get sihBranding;

  /// No description provided for @initializingApp.
  ///
  /// In en, this message translates to:
  /// **'Initializing KisaanBandhu...'**
  String get initializingApp;

  /// No description provided for @navScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get navScan;

  /// No description provided for @navMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get navMap;

  /// No description provided for @navHelpDesk.
  ///
  /// In en, this message translates to:
  /// **'Help Desk'**
  String get navHelpDesk;

  /// No description provided for @navAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get navAssistant;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to KisaanBandhu'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to access crop diagnosis and advisory'**
  String get loginSubtitle;

  /// No description provided for @createAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccountTitle;

  /// No description provided for @createAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join KisaanBandhu for smart farm management'**
  String get createAccountSubtitle;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullNameLabel;

  /// No description provided for @fullNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get fullNameHint;

  /// No description provided for @fullNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Full Name is required.'**
  String get fullNameRequired;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'farmer@example.com'**
  String get emailHint;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address.'**
  String get emailRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get emailInvalid;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password.'**
  String get passwordRequired;

  /// No description provided for @passwordLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get passwordLength;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPasswordLabel;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your password'**
  String get confirmPasswordHint;

  /// No description provided for @confirmPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password.'**
  String get confirmPasswordRequired;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get passwordsDoNotMatch;

  /// No description provided for @signInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signInButton;

  /// No description provided for @registerButton.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get registerButton;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @signOutButton.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutButton;

  /// No description provided for @signOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutConfirmTitle;

  /// No description provided for @signOutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out of your account?'**
  String get signOutConfirmMessage;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @editNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Name'**
  String get editNameTitle;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully.'**
  String get profileUpdated;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Farmer Profile'**
  String get profileTitle;

  /// No description provided for @accountInformation.
  ///
  /// In en, this message translates to:
  /// **'Account Information'**
  String get accountInformation;

  /// No description provided for @memberSince.
  ///
  /// In en, this message translates to:
  /// **'Member Since'**
  String get memberSince;

  /// No description provided for @userIdLabel.
  ///
  /// In en, this message translates to:
  /// **'User ID (UID)'**
  String get userIdLabel;

  /// No description provided for @guestUser.
  ///
  /// In en, this message translates to:
  /// **'Guest User'**
  String get guestUser;

  /// No description provided for @diagnosisHistory.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis History'**
  String get diagnosisHistory;

  /// No description provided for @diagnosisHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'View saved crop disease & pest detections'**
  String get diagnosisHistorySubtitle;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language / भाषा'**
  String get languageTitle;

  /// No description provided for @languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select your preferred language'**
  String get languageSubtitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageHindi.
  ///
  /// In en, this message translates to:
  /// **'हिन्दी (Hindi)'**
  String get languageHindi;

  /// No description provided for @scanHeader.
  ///
  /// In en, this message translates to:
  /// **'Smart Crop Scan'**
  String get scanHeader;

  /// No description provided for @scanInstruction.
  ///
  /// In en, this message translates to:
  /// **'Point camera at crop leaves and hold steady'**
  String get scanInstruction;

  /// No description provided for @analyzingCrop.
  ///
  /// In en, this message translates to:
  /// **'Analyzing Crop...'**
  String get analyzingCrop;

  /// No description provided for @tapToScan.
  ///
  /// In en, this message translates to:
  /// **'Tap to scan crop'**
  String get tapToScan;

  /// No description provided for @uploadFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Upload from Gallery'**
  String get uploadFromGallery;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// No description provided for @uploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload Image'**
  String get uploadPhoto;

  /// No description provided for @uploadImage.
  ///
  /// In en, this message translates to:
  /// **'Upload Image'**
  String get uploadImage;

  /// No description provided for @flashOn.
  ///
  /// In en, this message translates to:
  /// **'Flash On'**
  String get flashOn;

  /// No description provided for @flashOff.
  ///
  /// In en, this message translates to:
  /// **'Flash Off'**
  String get flashOff;

  /// No description provided for @switchCamera.
  ///
  /// In en, this message translates to:
  /// **'Switch Camera'**
  String get switchCamera;

  /// No description provided for @deepScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Detailed Crop Diagnosis'**
  String get deepScanTitle;

  /// No description provided for @realtimeMetrics.
  ///
  /// In en, this message translates to:
  /// **'Real-time Metrics'**
  String get realtimeMetrics;

  /// No description provided for @confidenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get confidenceLabel;

  /// No description provided for @marginLabel.
  ///
  /// In en, this message translates to:
  /// **'Margin'**
  String get marginLabel;

  /// No description provided for @clarityScoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Clarity Score'**
  String get clarityScoreLabel;

  /// No description provided for @inferenceTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Inference Time'**
  String get inferenceTimeLabel;

  /// No description provided for @mapTitle.
  ///
  /// In en, this message translates to:
  /// **'Farm Map'**
  String get mapTitle;

  /// No description provided for @markMyFarm.
  ///
  /// In en, this message translates to:
  /// **'Mark My Farm'**
  String get markMyFarm;

  /// No description provided for @editFarmBoundary.
  ///
  /// In en, this message translates to:
  /// **'Edit Boundary'**
  String get editFarmBoundary;

  /// No description provided for @saveBoundary.
  ///
  /// In en, this message translates to:
  /// **'Save Boundary'**
  String get saveBoundary;

  /// No description provided for @clearBoundary.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearBoundary;

  /// No description provided for @boundaryInstruction.
  ///
  /// In en, this message translates to:
  /// **'Tap points on the map to define your farm boundary'**
  String get boundaryInstruction;

  /// No description provided for @insideFarm.
  ///
  /// In en, this message translates to:
  /// **'Inside Farm'**
  String get insideFarm;

  /// No description provided for @outsideFarm.
  ///
  /// In en, this message translates to:
  /// **'Outside Farm'**
  String get outsideFarm;

  /// No description provided for @gpsHigh.
  ///
  /// In en, this message translates to:
  /// **'GPS: High'**
  String get gpsHigh;

  /// No description provided for @gpsMedium.
  ///
  /// In en, this message translates to:
  /// **'GPS: Medium'**
  String get gpsMedium;

  /// No description provided for @gpsLow.
  ///
  /// In en, this message translates to:
  /// **'GPS: Low'**
  String get gpsLow;

  /// No description provided for @gpsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'GPS: Unavailable'**
  String get gpsUnavailable;

  /// No description provided for @currentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current Location'**
  String get currentLocation;

  /// No description provided for @farmArea.
  ///
  /// In en, this message translates to:
  /// **'Farm Area'**
  String get farmArea;

  /// No description provided for @geotaggedScans.
  ///
  /// In en, this message translates to:
  /// **'geotagged scans'**
  String get geotaggedScans;

  /// No description provided for @navigate.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get navigate;

  /// No description provided for @askAssistant.
  ///
  /// In en, this message translates to:
  /// **'Ask Assistant'**
  String get askAssistant;

  /// No description provided for @target.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get target;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @farmMarkerAttachedPhoto.
  ///
  /// In en, this message translates to:
  /// **'Follow-up photo attached'**
  String get farmMarkerAttachedPhoto;

  /// No description provided for @assistantTitle.
  ///
  /// In en, this message translates to:
  /// **'Agricultural Assistant'**
  String get assistantTitle;

  /// No description provided for @assistantHeader.
  ///
  /// In en, this message translates to:
  /// **'KisaanBandhu Assistant'**
  String get assistantHeader;

  /// No description provided for @assistantWelcome.
  ///
  /// In en, this message translates to:
  /// **'Hello Kisan! Ask me anything about crop diseases, pest management, fertilizers, or current weather advisory.'**
  String get assistantWelcome;

  /// No description provided for @askQuestionHint.
  ///
  /// In en, this message translates to:
  /// **'Ask about crops, pests, fertilizers...'**
  String get askQuestionHint;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @quickPrompt1.
  ///
  /// In en, this message translates to:
  /// **'How to control pink bollworm?'**
  String get quickPrompt1;

  /// No description provided for @quickPrompt2.
  ///
  /// In en, this message translates to:
  /// **'Weather advisory for cotton'**
  String get quickPrompt2;

  /// No description provided for @quickPrompt3.
  ///
  /// In en, this message translates to:
  /// **'Soybean whitefly prevention'**
  String get quickPrompt3;

  /// No description provided for @quickPrompt4.
  ///
  /// In en, this message translates to:
  /// **'Organic fertilizers for crops'**
  String get quickPrompt4;

  /// No description provided for @sourceChunks.
  ///
  /// In en, this message translates to:
  /// **'Verified Knowledge Sources'**
  String get sourceChunks;

  /// No description provided for @weatherContextUsed.
  ///
  /// In en, this message translates to:
  /// **'Local weather data applied'**
  String get weatherContextUsed;

  /// No description provided for @evaluatingWithGemma.
  ///
  /// In en, this message translates to:
  /// **'Evaluating progression with Gemma…'**
  String get evaluatingWithGemma;

  /// No description provided for @runningMlClassifier.
  ///
  /// In en, this message translates to:
  /// **'Running V4 ML classifier…'**
  String get runningMlClassifier;

  /// No description provided for @followUpPhotoAttached.
  ///
  /// In en, this message translates to:
  /// **'Follow-up Photo Attached'**
  String get followUpPhotoAttached;

  /// No description provided for @askFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Ask Follow-up'**
  String get askFollowUp;

  /// No description provided for @takeAnotherPhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Another Photo'**
  String get takeAnotherPhoto;

  /// No description provided for @backToMap.
  ///
  /// In en, this message translates to:
  /// **'Back to Map'**
  String get backToMap;

  /// No description provided for @pointHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Point Assessment History'**
  String get pointHistoryTitle;

  /// No description provided for @pointAssessmentHistory.
  ///
  /// In en, this message translates to:
  /// **'Point Assessment History'**
  String get pointAssessmentHistory;

  /// No description provided for @visitsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} visits'**
  String visitsCount(Object count);

  /// No description provided for @noPreviousAssessments.
  ///
  /// In en, this message translates to:
  /// **'No previous assessments at this field point.'**
  String get noPreviousAssessments;

  /// No description provided for @visitNumber.
  ///
  /// In en, this message translates to:
  /// **'Visit #{number}'**
  String visitNumber(Object number);

  /// No description provided for @diagnosisLabel.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis'**
  String get diagnosisLabel;

  /// No description provided for @adviceLabel.
  ///
  /// In en, this message translates to:
  /// **'Advice'**
  String get adviceLabel;

  /// No description provided for @cropSoybean.
  ///
  /// In en, this message translates to:
  /// **'Soybean'**
  String get cropSoybean;

  /// No description provided for @cropCotton.
  ///
  /// In en, this message translates to:
  /// **'Cotton'**
  String get cropCotton;

  /// No description provided for @cropUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown Crop'**
  String get cropUnknown;

  /// No description provided for @cropUnclear.
  ///
  /// In en, this message translates to:
  /// **'Unclear'**
  String get cropUnclear;

  /// No description provided for @conditionHealthy.
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get conditionHealthy;

  /// No description provided for @conditionBacterialBlight.
  ///
  /// In en, this message translates to:
  /// **'Bacterial Blight'**
  String get conditionBacterialBlight;

  /// No description provided for @conditionWhitefly.
  ///
  /// In en, this message translates to:
  /// **'Whitefly'**
  String get conditionWhitefly;

  /// No description provided for @conditionPinkBollworm.
  ///
  /// In en, this message translates to:
  /// **'Pink Bollworm'**
  String get conditionPinkBollworm;

  /// No description provided for @conditionImageUnclear.
  ///
  /// In en, this message translates to:
  /// **'Image Unclear'**
  String get conditionImageUnclear;

  /// No description provided for @conditionUncertain.
  ///
  /// In en, this message translates to:
  /// **'Uncertain Detection'**
  String get conditionUncertain;

  /// No description provided for @conditionNegative.
  ///
  /// In en, this message translates to:
  /// **'Unsupported / Negative'**
  String get conditionNegative;

  /// No description provided for @stateImageUnclear.
  ///
  /// In en, this message translates to:
  /// **'Image Unclear'**
  String get stateImageUnclear;

  /// No description provided for @stateUncertainLow.
  ///
  /// In en, this message translates to:
  /// **'Low Confidence'**
  String get stateUncertainLow;

  /// No description provided for @stateUncertainMargin.
  ///
  /// In en, this message translates to:
  /// **'Ambiguous Detection'**
  String get stateUncertainMargin;

  /// No description provided for @stateNegative.
  ///
  /// In en, this message translates to:
  /// **'Non-Target Plant'**
  String get stateNegative;

  /// No description provided for @stateValid.
  ///
  /// In en, this message translates to:
  /// **'Valid Detection'**
  String get stateValid;

  /// No description provided for @severityEarly.
  ///
  /// In en, this message translates to:
  /// **'Early Stage'**
  String get severityEarly;

  /// No description provided for @severityModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get severityModerate;

  /// No description provided for @severityWorsening.
  ///
  /// In en, this message translates to:
  /// **'Worsening'**
  String get severityWorsening;

  /// No description provided for @severitySevere.
  ///
  /// In en, this message translates to:
  /// **'Severe'**
  String get severitySevere;

  /// No description provided for @severityUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unspecified'**
  String get severityUnknown;

  /// No description provided for @progressionInitial.
  ///
  /// In en, this message translates to:
  /// **'Initial Detection'**
  String get progressionInitial;

  /// No description provided for @progressionStable.
  ///
  /// In en, this message translates to:
  /// **'Stable'**
  String get progressionStable;

  /// No description provided for @progressionImproved.
  ///
  /// In en, this message translates to:
  /// **'Improved'**
  String get progressionImproved;

  /// No description provided for @progressionWorsening.
  ///
  /// In en, this message translates to:
  /// **'Worsening'**
  String get progressionWorsening;

  /// No description provided for @actionMonitor.
  ///
  /// In en, this message translates to:
  /// **'Regular Monitoring'**
  String get actionMonitor;

  /// No description provided for @actionIntegrated.
  ///
  /// In en, this message translates to:
  /// **'Integrated Pest Management (IPM)'**
  String get actionIntegrated;

  /// No description provided for @actionChemical.
  ///
  /// In en, this message translates to:
  /// **'Targeted Treatment'**
  String get actionChemical;

  /// No description provided for @actionExpert.
  ///
  /// In en, this message translates to:
  /// **'Expert Agricultural Consultation'**
  String get actionExpert;

  /// No description provided for @weatherTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get weatherTemperature;

  /// No description provided for @weatherHumidity.
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get weatherHumidity;

  /// No description provided for @weatherPrecipitation.
  ///
  /// In en, this message translates to:
  /// **'Rainfall'**
  String get weatherPrecipitation;

  /// No description provided for @weatherWind.
  ///
  /// In en, this message translates to:
  /// **'Wind Speed'**
  String get weatherWind;

  /// No description provided for @weatherRiskLow.
  ///
  /// In en, this message translates to:
  /// **'Low Disease Risk'**
  String get weatherRiskLow;

  /// No description provided for @weatherRiskMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium Disease Risk'**
  String get weatherRiskMedium;

  /// No description provided for @weatherRiskHigh.
  ///
  /// In en, this message translates to:
  /// **'High Disease Risk'**
  String get weatherRiskHigh;

  /// No description provided for @weatherConditions.
  ///
  /// In en, this message translates to:
  /// **'Weather Conditions'**
  String get weatherConditions;

  /// No description provided for @notificationChannelName.
  ///
  /// In en, this message translates to:
  /// **'Agricultural Alerts'**
  String get notificationChannelName;

  /// No description provided for @notificationChannelDesc.
  ///
  /// In en, this message translates to:
  /// **'Weather and disease risk alerts from KisaanBandhu'**
  String get notificationChannelDesc;

  /// No description provided for @helpDeskTitle.
  ///
  /// In en, this message translates to:
  /// **'Help Desk'**
  String get helpDeskTitle;

  /// No description provided for @helpDeskSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find agricultural support near you'**
  String get helpDeskSubtitle;

  /// No description provided for @helpDeskLocating.
  ///
  /// In en, this message translates to:
  /// **'Acquiring your location...'**
  String get helpDeskLocating;

  /// No description provided for @helpDeskSearchingNear.
  ///
  /// In en, this message translates to:
  /// **'Searching near {location}'**
  String helpDeskSearchingNear(Object location);

  /// No description provided for @helpDeskSearchingCurrent.
  ///
  /// In en, this message translates to:
  /// **'Searching near your current location'**
  String get helpDeskSearchingCurrent;

  /// No description provided for @helpDeskSearching.
  ///
  /// In en, this message translates to:
  /// **'Finding agricultural support near you...'**
  String get helpDeskSearching;

  /// No description provided for @helpDeskNoResults.
  ///
  /// In en, this message translates to:
  /// **'No agricultural support found nearby.'**
  String get helpDeskNoResults;

  /// No description provided for @helpDeskSearchWider.
  ///
  /// In en, this message translates to:
  /// **'Search Wider Area ({radius} km)'**
  String helpDeskSearchWider(Object radius);

  /// No description provided for @helpDeskSearchAgain.
  ///
  /// In en, this message translates to:
  /// **'Search Again'**
  String get helpDeskSearchAgain;

  /// No description provided for @helpDeskPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission is required to find agricultural support near you.'**
  String get helpDeskPermissionDenied;

  /// No description provided for @helpDeskPermissionPermDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission is permanently disabled. Please enable it in Settings.'**
  String get helpDeskPermissionPermDenied;

  /// No description provided for @helpDeskLocationDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location services are turned off. Please enable location to find nearby agricultural support.'**
  String get helpDeskLocationDisabled;

  /// No description provided for @helpDeskOfflineError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load nearby agricultural services. Please check your internet connection and try again.'**
  String get helpDeskOfflineError;

  /// No description provided for @helpDeskTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get helpDeskTryAgain;

  /// No description provided for @helpDeskOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get helpDeskOpenSettings;

  /// No description provided for @categoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get categoryAll;

  /// No description provided for @categoryLabs.
  ///
  /// In en, this message translates to:
  /// **'Labs'**
  String get categoryLabs;

  /// No description provided for @categoryExperts.
  ///
  /// In en, this message translates to:
  /// **'Experts & KVK'**
  String get categoryExperts;

  /// No description provided for @categoryResearch.
  ///
  /// In en, this message translates to:
  /// **'Research'**
  String get categoryResearch;

  /// No description provided for @categoryGovernment.
  ///
  /// In en, this message translates to:
  /// **'Government'**
  String get categoryGovernment;

  /// No description provided for @categoryDiseaseHelp.
  ///
  /// In en, this message translates to:
  /// **'Disease Help'**
  String get categoryDiseaseHelp;

  /// No description provided for @actionCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get actionCall;

  /// No description provided for @actionDirections.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get actionDirections;

  /// No description provided for @actionWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get actionWebsite;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
