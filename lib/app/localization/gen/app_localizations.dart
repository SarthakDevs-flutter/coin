import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Coin Atelier'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Sort thoughtfully. Merge beautifully. Every move makes sense.'**
  String get tagline;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Opening the workshop…'**
  String get loading;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t open the puzzle collection.'**
  String get loadFailed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @recoveredFromBackup.
  ///
  /// In en, this message translates to:
  /// **'Your latest save was damaged, so we restored the last good copy.'**
  String get recoveredFromBackup;

  /// No description provided for @recoveredReset.
  ///
  /// In en, this message translates to:
  /// **'Your save couldn\'t be read, so a fresh profile was started. The damaged file was kept for support.'**
  String get recoveredReset;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save just now. We\'ll keep trying.'**
  String get saveFailed;

  /// No description provided for @sessionReset.
  ///
  /// In en, this message translates to:
  /// **'This level was updated, so it starts fresh. Your other progress is safe.'**
  String get sessionReset;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @tutorialWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to the Atelier! Tap the stack topped with two rubies, then tap the empty tray.'**
  String get tutorialWelcome;

  /// No description provided for @tutorialMove.
  ///
  /// In en, this message translates to:
  /// **'Tap the stack topped with two rubies, then tap the empty tray to move them.'**
  String get tutorialMove;

  /// No description provided for @tutorialUndo.
  ///
  /// In en, this message translates to:
  /// **'Changed your mind? Tap Undo to take a move back. Undo is always free.'**
  String get tutorialUndo;

  /// No description provided for @tutorialRedo.
  ///
  /// In en, this message translates to:
  /// **'Now move the rubies to the empty tray again.'**
  String get tutorialRedo;

  /// No description provided for @tutorialFuse.
  ///
  /// In en, this message translates to:
  /// **'A tray full of matching coins seals into your cabinet. Move the jade pair onto the single jade.'**
  String get tutorialFuse;

  /// No description provided for @tutorialFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish the board: move the last ruby onto its pair.'**
  String get tutorialFinish;

  /// No description provided for @tutorialFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow the glowing stacks for this lesson.'**
  String get tutorialFollow;

  /// No description provided for @skipText.
  ///
  /// In en, this message translates to:
  /// **'Hide tip'**
  String get skipText;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @levelN.
  ///
  /// In en, this message translates to:
  /// **'Level {n}'**
  String levelN(int n);

  /// No description provided for @chapters.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get chapters;

  /// No description provided for @cabinet.
  ///
  /// In en, this message translates to:
  /// **'Cabinet'**
  String get cabinet;

  /// No description provided for @shop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get shop;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @giltAmount.
  ///
  /// In en, this message translates to:
  /// **'{n} gilt'**
  String giltAmount(int n);

  /// No description provided for @dailyGift.
  ///
  /// In en, this message translates to:
  /// **'Daily gift'**
  String get dailyGift;

  /// No description provided for @claimGilt.
  ///
  /// In en, this message translates to:
  /// **'Claim {n} gilt'**
  String claimGilt(int n);

  /// No description provided for @giftClaimed.
  ///
  /// In en, this message translates to:
  /// **'Gift collected. Another one tomorrow — no streak to keep.'**
  String get giftClaimed;

  /// No description provided for @campaignComplete.
  ///
  /// In en, this message translates to:
  /// **'Every level solved! Replay any level from the chapter map.'**
  String get campaignComplete;

  /// No description provided for @chapterN.
  ///
  /// In en, this message translates to:
  /// **'Chapter {n}'**
  String chapterN(int n);

  /// No description provided for @chapter1.
  ///
  /// In en, this message translates to:
  /// **'First Light'**
  String get chapter1;

  /// No description provided for @chapter2.
  ///
  /// In en, this message translates to:
  /// **'The Forge'**
  String get chapter2;

  /// No description provided for @chapter3.
  ///
  /// In en, this message translates to:
  /// **'Veiled Vault'**
  String get chapter3;

  /// No description provided for @chapter4.
  ///
  /// In en, this message translates to:
  /// **'Frostworks'**
  String get chapter4;

  /// No description provided for @chapter1Desc.
  ///
  /// In en, this message translates to:
  /// **'Sort and seal matching coins.'**
  String get chapter1Desc;

  /// No description provided for @chapter2Desc.
  ///
  /// In en, this message translates to:
  /// **'Fuse coins into higher tiers.'**
  String get chapter2Desc;

  /// No description provided for @chapter3Desc.
  ///
  /// In en, this message translates to:
  /// **'Some coins stay veiled until uncovered.'**
  String get chapter3Desc;

  /// No description provided for @chapter4Desc.
  ///
  /// In en, this message translates to:
  /// **'Frost seals coins until nearby fusing thaws them.'**
  String get chapter4Desc;

  /// No description provided for @chapterProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} solved'**
  String chapterProgress(int done, int total);

  /// No description provided for @levelLocked.
  ///
  /// In en, this message translates to:
  /// **'Finish the previous level to unlock this one.'**
  String get levelLocked;

  /// No description provided for @objectiveClear.
  ///
  /// In en, this message translates to:
  /// **'Seal every coin'**
  String get objectiveClear;

  /// No description provided for @objectiveForge.
  ///
  /// In en, this message translates to:
  /// **'Forge {count} tier {tier} coins'**
  String objectiveForge(int count, int tier);

  /// No description provided for @progressFraction.
  ///
  /// In en, this message translates to:
  /// **'{done}/{total}'**
  String progressFraction(int done, int total);

  /// No description provided for @coinsLeft.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =0{No coins left} =1{1 coin left} other{{n} coins left}}'**
  String coinsLeft(int n);

  /// No description provided for @movesCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 move} other{{n} moves}}'**
  String movesCount(int n);

  /// No description provided for @fuseRule.
  ///
  /// In en, this message translates to:
  /// **'{n} alike fuse'**
  String fuseRule(int n);

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @hint.
  ///
  /// In en, this message translates to:
  /// **'Hint'**
  String get hint;

  /// No description provided for @extraTray.
  ///
  /// In en, this message translates to:
  /// **'Extra tray'**
  String get extraTray;

  /// No description provided for @restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @rejectMismatch.
  ///
  /// In en, this message translates to:
  /// **'Coins only land on a matching coin or an empty tray.'**
  String get rejectMismatch;

  /// No description provided for @rejectFull.
  ///
  /// In en, this message translates to:
  /// **'That tray is full.'**
  String get rejectFull;

  /// No description provided for @rejectDestinationFrozen.
  ///
  /// In en, this message translates to:
  /// **'Frosted coins can\'t be covered.'**
  String get rejectDestinationFrozen;

  /// No description provided for @rejectSourceFrozen.
  ///
  /// In en, this message translates to:
  /// **'That coin is sealed by frost. Fuse coins in this or a neighbouring tray to thaw it.'**
  String get rejectSourceFrozen;

  /// No description provided for @rejectCannotLift.
  ///
  /// In en, this message translates to:
  /// **'Nothing to lift from there.'**
  String get rejectCannotLift;

  /// No description provided for @rejectNothingToUndo.
  ///
  /// In en, this message translates to:
  /// **'No moves to undo yet.'**
  String get rejectNothingToUndo;

  /// No description provided for @rejectBonusUsed.
  ///
  /// In en, this message translates to:
  /// **'The extra tray is already in place.'**
  String get rejectBonusUsed;

  /// No description provided for @rejectNoneLeft.
  ///
  /// In en, this message translates to:
  /// **'None left. Solve levels or visit the shop for more.'**
  String get rejectNoneLeft;

  /// No description provided for @hintSearching.
  ///
  /// In en, this message translates to:
  /// **'Looking for a good move…'**
  String get hintSearching;

  /// No description provided for @hintNone.
  ///
  /// In en, this message translates to:
  /// **'No hint available right now. Undo or Restart are always free.'**
  String get hintNone;

  /// No description provided for @hintShown.
  ///
  /// In en, this message translates to:
  /// **'Hint: move from the tray with the up arrow to the tray with the down arrow.'**
  String get hintShown;

  /// No description provided for @deadEnd.
  ///
  /// In en, this message translates to:
  /// **'This board can\'t be finished from here. Undo or restart — both are free.'**
  String get deadEnd;

  /// No description provided for @blockedTitle.
  ///
  /// In en, this message translates to:
  /// **'No moves left'**
  String get blockedTitle;

  /// No description provided for @blockedBody.
  ///
  /// In en, this message translates to:
  /// **'No coin can move right now. Pick how to continue — nothing here costs money.'**
  String get blockedBody;

  /// No description provided for @backToMap.
  ///
  /// In en, this message translates to:
  /// **'Back to map'**
  String get backToMap;

  /// No description provided for @pausedTitle.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get pausedTitle;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @restartConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Restart level?'**
  String get restartConfirmTitle;

  /// No description provided for @restartConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The board returns to its starting layout and your current moves are cleared.'**
  String get restartConfirmBody;

  /// No description provided for @howToPlay.
  ///
  /// In en, this message translates to:
  /// **'How to play'**
  String get howToPlay;

  /// No description provided for @ruleMove.
  ///
  /// In en, this message translates to:
  /// **'Tap a stack to lift its top coins, then tap a tray to drop them.'**
  String get ruleMove;

  /// No description provided for @ruleLand.
  ///
  /// In en, this message translates to:
  /// **'Coins land on an empty tray or on coins of the same kind.'**
  String get ruleLand;

  /// No description provided for @ruleFuse.
  ///
  /// In en, this message translates to:
  /// **'When {n} alike meet at the top of a tray, they fuse.'**
  String ruleFuse(int n);

  /// No description provided for @ruleTier.
  ///
  /// In en, this message translates to:
  /// **'Below the top tier they fuse into one higher-tier coin; at the top tier they seal into your cabinet.'**
  String get ruleTier;

  /// No description provided for @ruleFrost.
  ///
  /// In en, this message translates to:
  /// **'Frosted coins thaw when coins fuse in their tray or a neighbouring one.'**
  String get ruleFrost;

  /// No description provided for @ruleHidden.
  ///
  /// In en, this message translates to:
  /// **'Veiled coins reveal themselves when they become the top coin.'**
  String get ruleHidden;

  /// No description provided for @winTitle.
  ///
  /// In en, this message translates to:
  /// **'Solved!'**
  String get winTitle;

  /// No description provided for @winMoves.
  ///
  /// In en, this message translates to:
  /// **'Solved in {n, plural, =1{1 move} other{{n} moves}}'**
  String winMoves(int n);

  /// No description provided for @rewardEarned.
  ///
  /// In en, this message translates to:
  /// **'+{n} gilt'**
  String rewardEarned(int n);

  /// No description provided for @rewardAlready.
  ///
  /// In en, this message translates to:
  /// **'Reward already collected for this level.'**
  String get rewardAlready;

  /// No description provided for @tutorialBonus.
  ///
  /// In en, this message translates to:
  /// **'+{n} hints for finishing the lesson'**
  String tutorialBonus(int n);

  /// No description provided for @nextLevel.
  ///
  /// In en, this message translates to:
  /// **'Next level'**
  String get nextLevel;

  /// No description provided for @replay.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get replay;

  /// No description provided for @newFamily.
  ///
  /// In en, this message translates to:
  /// **'New coin for your cabinet: {name}'**
  String newFamily(String name);

  /// No description provided for @introTitleForge.
  ///
  /// In en, this message translates to:
  /// **'New: Forging'**
  String get introTitleForge;

  /// No description provided for @introBodyForge.
  ///
  /// In en, this message translates to:
  /// **'Coins now have tiers. Fusing coins below the top tier makes one coin of the next tier. Fuse top-tier coins to seal them.'**
  String get introBodyForge;

  /// No description provided for @introTitleHidden.
  ///
  /// In en, this message translates to:
  /// **'New: Veiled coins'**
  String get introTitleHidden;

  /// No description provided for @introBodyHidden.
  ///
  /// In en, this message translates to:
  /// **'Some coins are veiled. They reveal themselves when they become the top coin and cannot join a fuse while veiled.'**
  String get introBodyHidden;

  /// No description provided for @introTitleFrost.
  ///
  /// In en, this message translates to:
  /// **'New: Frost seals'**
  String get introTitleFrost;

  /// No description provided for @introBodyFrost.
  ///
  /// In en, this message translates to:
  /// **'Frosted coins can\'t be lifted or covered. Each fuse in their tray or a neighbouring tray thaws them by one.'**
  String get introBodyFrost;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @cabinetTitle.
  ///
  /// In en, this message translates to:
  /// **'Collector\'s Cabinet'**
  String get cabinetTitle;

  /// No description provided for @cabinetFamilies.
  ///
  /// In en, this message translates to:
  /// **'Coin families'**
  String get cabinetFamilies;

  /// No description provided for @undiscovered.
  ///
  /// In en, this message translates to:
  /// **'Not yet discovered'**
  String get undiscovered;

  /// No description provided for @finishesTitle.
  ///
  /// In en, this message translates to:
  /// **'Coin finishes'**
  String get finishesTitle;

  /// No description provided for @finishesNote.
  ///
  /// In en, this message translates to:
  /// **'Finishes only change how coins look. They never change the rules.'**
  String get finishesNote;

  /// No description provided for @finishEnamel.
  ///
  /// In en, this message translates to:
  /// **'Enamel'**
  String get finishEnamel;

  /// No description provided for @finishSatin.
  ///
  /// In en, this message translates to:
  /// **'Satin'**
  String get finishSatin;

  /// No description provided for @finishGilded.
  ///
  /// In en, this message translates to:
  /// **'Gilded'**
  String get finishGilded;

  /// No description provided for @useFinish.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get useFinish;

  /// No description provided for @inUse.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get inUse;

  /// No description provided for @buyForGilt.
  ///
  /// In en, this message translates to:
  /// **'{n} gilt'**
  String buyForGilt(int n);

  /// No description provided for @familyJade.
  ///
  /// In en, this message translates to:
  /// **'Jade Leaf'**
  String get familyJade;

  /// No description provided for @familyRuby.
  ///
  /// In en, this message translates to:
  /// **'Ruby Flame'**
  String get familyRuby;

  /// No description provided for @familySapphire.
  ///
  /// In en, this message translates to:
  /// **'Sapphire Wave'**
  String get familySapphire;

  /// No description provided for @familyAmber.
  ///
  /// In en, this message translates to:
  /// **'Amber Sun'**
  String get familyAmber;

  /// No description provided for @familyAmethyst.
  ///
  /// In en, this message translates to:
  /// **'Amethyst Star'**
  String get familyAmethyst;

  /// No description provided for @familyPearl.
  ///
  /// In en, this message translates to:
  /// **'Pearl Moon'**
  String get familyPearl;

  /// No description provided for @familyOnyx.
  ///
  /// In en, this message translates to:
  /// **'Onyx Prism'**
  String get familyOnyx;

  /// No description provided for @familyCoral.
  ///
  /// In en, this message translates to:
  /// **'Coral Clover'**
  String get familyCoral;

  /// No description provided for @tierN.
  ///
  /// In en, this message translates to:
  /// **'Tier {n}'**
  String tierN(int n);

  /// No description provided for @shopTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get shopTitle;

  /// No description provided for @shopEarnedSection.
  ///
  /// In en, this message translates to:
  /// **'Spend earned gilt'**
  String get shopEarnedSection;

  /// No description provided for @shopHintPack.
  ///
  /// In en, this message translates to:
  /// **'3 hints'**
  String get shopHintPack;

  /// No description provided for @shopHintPackDesc.
  ///
  /// In en, this message translates to:
  /// **'Each hint highlights one move that leads toward a solution.'**
  String get shopHintPackDesc;

  /// No description provided for @shopBonusTray.
  ///
  /// In en, this message translates to:
  /// **'Extra tray'**
  String get shopBonusTray;

  /// No description provided for @shopBonusTrayDesc.
  ///
  /// In en, this message translates to:
  /// **'Adds one empty tray to a level. Undo history before it is cleared.'**
  String get shopBonusTrayDesc;

  /// No description provided for @owned.
  ///
  /// In en, this message translates to:
  /// **'You have {n}'**
  String owned(int n);

  /// No description provided for @notEnoughGilt.
  ///
  /// In en, this message translates to:
  /// **'Not enough gilt yet. Solving levels earns more.'**
  String get notEnoughGilt;

  /// No description provided for @purchasedItem.
  ///
  /// In en, this message translates to:
  /// **'Added to your satchel.'**
  String get purchasedItem;

  /// No description provided for @shopFreeSection.
  ///
  /// In en, this message translates to:
  /// **'Free with a video (optional)'**
  String get shopFreeSection;

  /// No description provided for @watchForHint.
  ///
  /// In en, this message translates to:
  /// **'Watch a video for 1 hint'**
  String get watchForHint;

  /// No description provided for @adUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No videos are available right now. You can still earn hints by solving levels.'**
  String get adUnavailable;

  /// No description provided for @adDismissed.
  ///
  /// In en, this message translates to:
  /// **'The video was closed early, so no hint was added.'**
  String get adDismissed;

  /// No description provided for @adRewarded.
  ///
  /// In en, this message translates to:
  /// **'1 hint added. Thanks!'**
  String get adRewarded;

  /// No description provided for @shopStoreSection.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get shopStoreSection;

  /// No description provided for @removeAdsTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove ads'**
  String get removeAdsTitle;

  /// No description provided for @removeAdsDesc.
  ///
  /// In en, this message translates to:
  /// **'Removes the banner and the occasional ad between levels. Optional reward videos stay available only if you choose them.'**
  String get removeAdsDesc;

  /// No description provided for @adPrivacyChoices.
  ///
  /// In en, this message translates to:
  /// **'Ad privacy choices'**
  String get adPrivacyChoices;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Update needed'**
  String get updateRequiredTitle;

  /// No description provided for @updateRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'This version of Coin Atelier is no longer supported. Please update to keep playing; your progress is kept.'**
  String get updateRequiredBody;

  /// No description provided for @updateOptionalTitle.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateOptionalTitle;

  /// No description provided for @updateOptionalBody.
  ///
  /// In en, this message translates to:
  /// **'A new version of Coin Atelier is ready with improvements and fixes.'**
  String get updateOptionalBody;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateNow;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @removeAdsOwned.
  ///
  /// In en, this message translates to:
  /// **'Ads removed. Thank you for supporting the Atelier!'**
  String get removeAdsOwned;

  /// No description provided for @storeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The store isn\'t available on this device right now.'**
  String get storeUnavailable;

  /// No description provided for @purchasePending.
  ///
  /// In en, this message translates to:
  /// **'Purchase pending. It will apply as soon as the store confirms it.'**
  String get purchasePending;

  /// No description provided for @purchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'The purchase didn\'t go through. You weren\'t charged by the game.'**
  String get purchaseFailed;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get restorePurchases;

  /// No description provided for @restoreDone.
  ///
  /// In en, this message translates to:
  /// **'Restore requested. Any owned purchases will apply automatically.'**
  String get restoreDone;

  /// No description provided for @settingsAudio.
  ///
  /// In en, this message translates to:
  /// **'Sound & feel'**
  String get settingsAudio;

  /// No description provided for @soundEffects.
  ///
  /// In en, this message translates to:
  /// **'Sound effects'**
  String get soundEffects;

  /// No description provided for @music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get music;

  /// No description provided for @haptics.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get haptics;

  /// No description provided for @settingsAccess.
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get settingsAccess;

  /// No description provided for @reducedMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduced motion'**
  String get reducedMotion;

  /// No description provided for @reducedMotionDesc.
  ///
  /// In en, this message translates to:
  /// **'Shorter, calmer animations and no particles.'**
  String get reducedMotionDesc;

  /// No description provided for @colorBlind.
  ///
  /// In en, this message translates to:
  /// **'Colour-blind assist'**
  String get colorBlind;

  /// No description provided for @colorBlindDesc.
  ///
  /// In en, this message translates to:
  /// **'Bolder rim patterns and family letters on every coin.'**
  String get colorBlindDesc;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @systemLanguage.
  ///
  /// In en, this message translates to:
  /// **'Device language'**
  String get systemLanguage;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy & data'**
  String get settingsPrivacy;

  /// No description provided for @analyticsConsent.
  ///
  /// In en, this message translates to:
  /// **'Share anonymous gameplay statistics'**
  String get analyticsConsent;

  /// No description provided for @analyticsConsentDesc.
  ///
  /// In en, this message translates to:
  /// **'Level and session counts only — never personal data. Off unless you turn it on.'**
  String get analyticsConsentDesc;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Help & support'**
  String get support;

  /// No description provided for @credits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get credits;

  /// No description provided for @resetProgress.
  ///
  /// In en, this message translates to:
  /// **'Reset local progress'**
  String get resetProgress;

  /// No description provided for @resetConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Erase all progress?'**
  String get resetConfirmTitle;

  /// No description provided for @resetConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your levels, gilt and items on this device. It cannot be undone.'**
  String get resetConfirmBody;

  /// No description provided for @resetConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get resetConfirmAction;

  /// No description provided for @devOverlay.
  ///
  /// In en, this message translates to:
  /// **'Developer overlay'**
  String get devOverlay;

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'Share anonymous statistics (level progress, region and app version) so we can tune the puzzles. No name, account or contact details. You can change this anytime in Settings.'**
  String get privacyBody;

  /// No description provided for @supportBody.
  ///
  /// In en, this message translates to:
  /// **'Having trouble? Undo and Restart are always free, and every level has a verified solution. If something looks wrong, the details below help us investigate. They contain no personal data.'**
  String get supportBody;

  /// No description provided for @supportContactPending.
  ///
  /// In en, this message translates to:
  /// **'A support contact will be listed here before release.'**
  String get supportContactPending;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {v}'**
  String appVersion(String v);

  /// No description provided for @recentIssues.
  ///
  /// In en, this message translates to:
  /// **'Recent diagnostic codes'**
  String get recentIssues;

  /// No description provided for @noIssues.
  ///
  /// In en, this message translates to:
  /// **'No issues recorded.'**
  String get noIssues;

  /// No description provided for @creditsBody.
  ///
  /// In en, this message translates to:
  /// **'Design, art, levels and sound are original to Coin Atelier. Sounds are synthesised in code.\n\nFonts: Fredoka (The Fredoka Project Authors) and Nunito (The Nunito Project Authors), both under the SIL Open Font License 1.1.\n\nBuilt with Flutter and Flame.'**
  String get creditsBody;

  /// No description provided for @a11yStack.
  ///
  /// In en, this message translates to:
  /// **'Tray {index}: {count, plural, =0{empty} =1{1 coin} other{{count} coins}}. {top}'**
  String a11yStack(int index, int count, String top);

  /// No description provided for @a11yTop.
  ///
  /// In en, this message translates to:
  /// **'Top coin {name} tier {tier}'**
  String a11yTop(String name, int tier);

  /// No description provided for @a11ySelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get a11ySelected;

  /// No description provided for @a11yTarget.
  ///
  /// In en, this message translates to:
  /// **'Can drop here'**
  String get a11yTarget;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @deal.
  ///
  /// In en, this message translates to:
  /// **'Deal'**
  String get deal;

  /// No description provided for @dealsLeft.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =0{No deals left} =1{1 deal left} other{{n} deals left}}'**
  String dealsLeft(int n);

  /// No description provided for @nextDeal.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextDeal;

  /// No description provided for @rejectNoDeals.
  ///
  /// In en, this message translates to:
  /// **'No deals left. Sort what\'s on the board.'**
  String get rejectNoDeals;

  /// No description provided for @rejectDealNoRoom.
  ///
  /// In en, this message translates to:
  /// **'Make room in the highlighted trays, then deal.'**
  String get rejectDealNoRoom;

  /// No description provided for @hintDeal.
  ///
  /// In en, this message translates to:
  /// **'Hint: press Deal now.'**
  String get hintDeal;

  /// No description provided for @introTitleDeal.
  ///
  /// In en, this message translates to:
  /// **'New: Deals'**
  String get introTitleDeal;

  /// No description provided for @introBodyDeal.
  ///
  /// In en, this message translates to:
  /// **'Press Deal to drop the next batch of coins into the trays. You can always see the next batch, and every level is solvable with its deals.'**
  String get introBodyDeal;

  /// No description provided for @chainText.
  ///
  /// In en, this message translates to:
  /// **'Chain ×{n}!'**
  String chainText(int n);

  /// No description provided for @goalSeal.
  ///
  /// In en, this message translates to:
  /// **'{name}: {n} left to seal'**
  String goalSeal(String name, int n);

  /// No description provided for @goalForge.
  ///
  /// In en, this message translates to:
  /// **'Tier {tier}: {n} left to forge'**
  String goalForge(int tier, int n);

  /// No description provided for @a11yDeal.
  ///
  /// In en, this message translates to:
  /// **'Deal next batch, {n, plural, =0{none left} =1{1 left} other{{n} left}}'**
  String a11yDeal(int n);

  /// No description provided for @ruleDeal.
  ///
  /// In en, this message translates to:
  /// **'Deal drops the next batch of coins; the next batch is always shown.'**
  String get ruleDeal;

  /// No description provided for @workshopLevel.
  ///
  /// In en, this message translates to:
  /// **'Level {n}'**
  String workshopLevel(int n);

  /// No description provided for @workshopUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get workshopUnlock;

  /// No description provided for @workshopTitle.
  ///
  /// In en, this message translates to:
  /// **'Workshop slot'**
  String get workshopTitle;

  /// No description provided for @workshopBody.
  ///
  /// In en, this message translates to:
  /// **'Adds a permanent empty tray to every level from now on. It never makes a level harder.'**
  String get workshopBody;

  /// No description provided for @workshopUnlockFor.
  ///
  /// In en, this message translates to:
  /// **'Unlock for {n} gilt'**
  String workshopUnlockFor(int n);

  /// No description provided for @workshopLocked.
  ///
  /// In en, this message translates to:
  /// **'Workshop slot, unlocks after level {n}'**
  String workshopLocked(int n);

  /// No description provided for @workshopReady.
  ///
  /// In en, this message translates to:
  /// **'Workshop slot, unlock for {n} gilt'**
  String workshopReady(int n);

  /// No description provided for @workshopUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Workshop slot added!'**
  String get workshopUnlocked;

  /// No description provided for @themes.
  ///
  /// In en, this message translates to:
  /// **'Themes'**
  String get themes;

  /// No description provided for @themesTitle.
  ///
  /// In en, this message translates to:
  /// **'Coin Themes'**
  String get themesTitle;

  /// No description provided for @themesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Play with the coins of your favourite currency. Every theme is free.'**
  String get themesSubtitle;

  /// No description provided for @themeInUse.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get themeInUse;

  /// No description provided for @themeUse.
  ///
  /// In en, this message translates to:
  /// **'Use theme'**
  String get themeUse;

  /// No description provided for @themeApplied.
  ///
  /// In en, this message translates to:
  /// **'{name} theme applied'**
  String themeApplied(String name);

  /// No description provided for @themeCurrency.
  ///
  /// In en, this message translates to:
  /// **'{currency} ({symbol})'**
  String themeCurrency(String currency, String symbol);

  /// No description provided for @chapter5.
  ///
  /// In en, this message translates to:
  /// **'Grand Hall'**
  String get chapter5;

  /// No description provided for @chapter5Desc.
  ///
  /// In en, this message translates to:
  /// **'Bigger boards and more coins to sort.'**
  String get chapter5Desc;

  /// No description provided for @chapter6.
  ///
  /// In en, this message translates to:
  /// **'Coin Rain'**
  String get chapter6;

  /// No description provided for @chapter6Desc.
  ///
  /// In en, this message translates to:
  /// **'Deals pour in fast. Keep room to spare.'**
  String get chapter6Desc;

  /// No description provided for @chapter7.
  ///
  /// In en, this message translates to:
  /// **'Twin Forge'**
  String get chapter7;

  /// No description provided for @chapter7Desc.
  ///
  /// In en, this message translates to:
  /// **'Fuse up a tier and fill forge orders.'**
  String get chapter7Desc;

  /// No description provided for @chapter8.
  ///
  /// In en, this message translates to:
  /// **'Shadow Market'**
  String get chapter8;

  /// No description provided for @chapter8Desc.
  ///
  /// In en, this message translates to:
  /// **'Most coins stay veiled until you dig them out.'**
  String get chapter8Desc;

  /// No description provided for @chapter9.
  ///
  /// In en, this message translates to:
  /// **'Winter Mint'**
  String get chapter9;

  /// No description provided for @chapter9Desc.
  ///
  /// In en, this message translates to:
  /// **'Deep frost needs fusing nearby, twice.'**
  String get chapter9Desc;

  /// No description provided for @chapter10.
  ///
  /// In en, this message translates to:
  /// **'Tall Towers'**
  String get chapter10;

  /// No description provided for @chapter10Desc.
  ///
  /// In en, this message translates to:
  /// **'Tall trays take many coins to fill.'**
  String get chapter10Desc;

  /// No description provided for @chapter11.
  ///
  /// In en, this message translates to:
  /// **'Midnight Vault'**
  String get chapter11;

  /// No description provided for @chapter11Desc.
  ///
  /// In en, this message translates to:
  /// **'Veils and frost together.'**
  String get chapter11Desc;

  /// No description provided for @chapter12.
  ///
  /// In en, this message translates to:
  /// **'Royal Treasury'**
  String get chapter12;

  /// No description provided for @chapter12Desc.
  ///
  /// In en, this message translates to:
  /// **'Forge tiers in the dark.'**
  String get chapter12Desc;

  /// No description provided for @chapter13.
  ///
  /// In en, this message translates to:
  /// **'Glacier Bank'**
  String get chapter13;

  /// No description provided for @chapter13Desc.
  ///
  /// In en, this message translates to:
  /// **'Frozen coins on the forge.'**
  String get chapter13Desc;

  /// No description provided for @chapter14.
  ///
  /// In en, this message translates to:
  /// **'Grand Bazaar'**
  String get chapter14;

  /// No description provided for @chapter14Desc.
  ///
  /// In en, this message translates to:
  /// **'All eight coins on the biggest boards.'**
  String get chapter14Desc;

  /// No description provided for @chapter15.
  ///
  /// In en, this message translates to:
  /// **'Iron Mint'**
  String get chapter15;

  /// No description provided for @chapter15Desc.
  ///
  /// In en, this message translates to:
  /// **'Tall trays, hidden coins, big drops.'**
  String get chapter15Desc;

  /// No description provided for @chapter16.
  ///
  /// In en, this message translates to:
  /// **'Crown Jewels'**
  String get chapter16;

  /// No description provided for @chapter16Desc.
  ///
  /// In en, this message translates to:
  /// **'Every trick at once.'**
  String get chapter16Desc;

  /// No description provided for @chapter17.
  ///
  /// In en, this message translates to:
  /// **'Master Atelier'**
  String get chapter17;

  /// No description provided for @chapter17Desc.
  ///
  /// In en, this message translates to:
  /// **'The final test of a master sorter.'**
  String get chapter17Desc;

  /// No description provided for @difficultyHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get difficultyHard;

  /// No description provided for @difficultyExpert.
  ///
  /// In en, this message translates to:
  /// **'Super hard'**
  String get difficultyExpert;

  /// No description provided for @difficultyBonus.
  ///
  /// In en, this message translates to:
  /// **'{label} level · ×{mult} gilt'**
  String difficultyBonus(String label, String mult);

  /// No description provided for @fillRule.
  ///
  /// In en, this message translates to:
  /// **'Fill a tray to seal'**
  String get fillRule;

  /// No description provided for @introTitleFill.
  ///
  /// In en, this message translates to:
  /// **'New: Taller trays'**
  String get introTitleFill;

  /// No description provided for @introBodyFill.
  ///
  /// In en, this message translates to:
  /// **'A tray seals when it is full of one kind of coin. Taller trays need more coins to fill. Deals drop several coins at once, so keep room to spare.'**
  String get introBodyFill;

  /// No description provided for @coachHint.
  ///
  /// In en, this message translates to:
  /// **'Stuck? Hint shows a move that keeps the level solvable.'**
  String get coachHint;

  /// No description provided for @coachExtraTray.
  ///
  /// In en, this message translates to:
  /// **'Out of room? Add an extra tray for this level.'**
  String get coachExtraTray;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Help improve the Atelier?'**
  String get privacyTitle;

  /// No description provided for @privacyAccept.
  ///
  /// In en, this message translates to:
  /// **'Share stats'**
  String get privacyAccept;

  /// No description provided for @privacyDecline.
  ///
  /// In en, this message translates to:
  /// **'No thanks'**
  String get privacyDecline;

  /// No description provided for @guideHand.
  ///
  /// In en, this message translates to:
  /// **'Tap here'**
  String get guideHand;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get tabMap;

  /// No description provided for @giftReadyShort.
  ///
  /// In en, this message translates to:
  /// **'Gift'**
  String get giftReadyShort;

  /// No description provided for @giftTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get giftTomorrow;

  /// No description provided for @giftCollected.
  ///
  /// In en, this message translates to:
  /// **'+{n} gilt collected!'**
  String giftCollected(int n);

  /// No description provided for @noAdsShort.
  ///
  /// In en, this message translates to:
  /// **'No ads'**
  String get noAdsShort;

  /// No description provided for @allSolved.
  ///
  /// In en, this message translates to:
  /// **'All solved'**
  String get allSolved;

  /// No description provided for @chapterLabel.
  ///
  /// In en, this message translates to:
  /// **'Chapter {n}'**
  String chapterLabel(int n);
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
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
