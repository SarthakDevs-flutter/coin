// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Coin Atelier';

  @override
  String get tagline =>
      'Sort thoughtfully. Merge beautifully. Every move makes sense.';

  @override
  String get loading => 'Opening the workshop…';

  @override
  String get loadFailed => 'We couldn\'t open the puzzle collection.';

  @override
  String get retry => 'Try again';

  @override
  String get recoveredFromBackup =>
      'Your latest save was damaged, so we restored the last good copy.';

  @override
  String get recoveredReset =>
      'Your save couldn\'t be read, so a fresh profile was started. The damaged file was kept for support.';

  @override
  String get saveFailed => 'Couldn\'t save just now. We\'ll keep trying.';

  @override
  String get sessionReset =>
      'This level was updated, so it starts fresh. Your other progress is safe.';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get welcomeTitle => 'Welcome to the Atelier';

  @override
  String get welcomeBody =>
      'Stack matching coins until they fuse. A short hands-on lesson shows you how.';

  @override
  String get startTutorial => 'Start the lesson';

  @override
  String get tutorialMove =>
      'Tap the stack topped with two rubies, then tap the empty tray to move them.';

  @override
  String get tutorialUndo =>
      'Changed your mind? Tap Undo to take a move back. Undo is always free.';

  @override
  String get tutorialRedo => 'Now move the rubies to the empty tray again.';

  @override
  String get tutorialFuse =>
      'A tray full of matching coins seals into your cabinet. Move the jade pair onto the single jade.';

  @override
  String get tutorialFinish =>
      'Finish the board: move the last ruby onto its pair.';

  @override
  String get tutorialFollow => 'Follow the glowing stacks for this lesson.';

  @override
  String get skipText => 'Hide tip';

  @override
  String get continueButton => 'Continue';

  @override
  String levelN(int n) {
    return 'Level $n';
  }

  @override
  String get chapters => 'Chapters';

  @override
  String get cabinet => 'Cabinet';

  @override
  String get shop => 'Shop';

  @override
  String get settings => 'Settings';

  @override
  String giltAmount(int n) {
    return '$n gilt';
  }

  @override
  String get dailyGift => 'Daily gift';

  @override
  String claimGilt(int n) {
    return 'Claim $n gilt';
  }

  @override
  String get giftClaimed =>
      'Gift collected. Another one tomorrow — no streak to keep.';

  @override
  String get campaignComplete =>
      'Every level solved! Replay any level from the chapter map.';

  @override
  String chapterN(int n) {
    return 'Chapter $n';
  }

  @override
  String get chapter1 => 'First Light';

  @override
  String get chapter2 => 'The Forge';

  @override
  String get chapter3 => 'Veiled Vault';

  @override
  String get chapter4 => 'Frostworks';

  @override
  String get chapter1Desc => 'Sort and seal matching coins.';

  @override
  String get chapter2Desc => 'Fuse coins into higher tiers.';

  @override
  String get chapter3Desc => 'Some coins stay veiled until uncovered.';

  @override
  String get chapter4Desc =>
      'Frost seals coins until nearby fusing thaws them.';

  @override
  String chapterProgress(int done, int total) {
    return '$done of $total solved';
  }

  @override
  String get levelLocked => 'Finish the previous level to unlock this one.';

  @override
  String get objectiveClear => 'Seal every coin';

  @override
  String objectiveForge(int count, int tier) {
    return 'Forge $count tier $tier coins';
  }

  @override
  String progressFraction(int done, int total) {
    return '$done/$total';
  }

  @override
  String coinsLeft(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n coins left',
      one: '1 coin left',
      zero: 'No coins left',
    );
    return '$_temp0';
  }

  @override
  String movesCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n moves',
      one: '1 move',
    );
    return '$_temp0';
  }

  @override
  String fuseRule(int n) {
    return '$n alike fuse';
  }

  @override
  String get undo => 'Undo';

  @override
  String get hint => 'Hint';

  @override
  String get extraTray => 'Extra tray';

  @override
  String get restart => 'Restart';

  @override
  String get pause => 'Pause';

  @override
  String get rejectMismatch =>
      'Coins only land on a matching coin or an empty tray.';

  @override
  String get rejectFull => 'That tray is full.';

  @override
  String get rejectDestinationFrozen => 'Frosted coins can\'t be covered.';

  @override
  String get rejectSourceFrozen =>
      'That coin is sealed by frost. Fuse coins in this or a neighbouring tray to thaw it.';

  @override
  String get rejectCannotLift => 'Nothing to lift from there.';

  @override
  String get rejectNothingToUndo => 'No moves to undo yet.';

  @override
  String get rejectBonusUsed => 'The extra tray is already in place.';

  @override
  String get rejectNoneLeft =>
      'None left. Solve levels or visit the shop for more.';

  @override
  String get hintSearching => 'Looking for a good move…';

  @override
  String get hintNone =>
      'No hint available right now. Undo or Restart are always free.';

  @override
  String get hintShown =>
      'Hint: move from the tray with the up arrow to the tray with the down arrow.';

  @override
  String get deadEnd =>
      'This board can\'t be finished from here. Undo or restart — both are free.';

  @override
  String get blockedTitle => 'No moves left';

  @override
  String get blockedBody =>
      'No coin can move right now. Pick how to continue — nothing here costs money.';

  @override
  String get backToMap => 'Back to map';

  @override
  String get pausedTitle => 'Paused';

  @override
  String get resume => 'Resume';

  @override
  String get restartConfirmTitle => 'Restart level?';

  @override
  String get restartConfirmBody =>
      'The board returns to its starting layout and your current moves are cleared.';

  @override
  String get howToPlay => 'How to play';

  @override
  String get ruleMove =>
      'Tap a stack to lift its top coins, then tap a tray to drop them.';

  @override
  String get ruleLand =>
      'Coins land on an empty tray or on coins of the same kind.';

  @override
  String ruleFuse(int n) {
    return 'When $n alike meet at the top of a tray, they fuse.';
  }

  @override
  String get ruleTier =>
      'Below the top tier they fuse into one higher-tier coin; at the top tier they seal into your cabinet.';

  @override
  String get ruleFrost =>
      'Frosted coins thaw when coins fuse in their tray or a neighbouring one.';

  @override
  String get ruleHidden =>
      'Veiled coins reveal themselves when they become the top coin.';

  @override
  String get winTitle => 'Solved!';

  @override
  String winMoves(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n moves',
      one: '1 move',
    );
    return 'Solved in $_temp0';
  }

  @override
  String rewardEarned(int n) {
    return '+$n gilt';
  }

  @override
  String get rewardAlready => 'Reward already collected for this level.';

  @override
  String tutorialBonus(int n) {
    return '+$n hints for finishing the lesson';
  }

  @override
  String get nextLevel => 'Next level';

  @override
  String get replay => 'Replay';

  @override
  String newFamily(String name) {
    return 'New coin for your cabinet: $name';
  }

  @override
  String get introTitleForge => 'New: Forging';

  @override
  String get introBodyForge =>
      'Coins now have tiers. Fusing coins below the top tier makes one coin of the next tier. Fuse top-tier coins to seal them.';

  @override
  String get introTitleHidden => 'New: Veiled coins';

  @override
  String get introBodyHidden =>
      'Some coins are veiled. They reveal themselves when they become the top coin and cannot join a fuse while veiled.';

  @override
  String get introTitleFrost => 'New: Frost seals';

  @override
  String get introBodyFrost =>
      'Frosted coins can\'t be lifted or covered. Each fuse in their tray or a neighbouring tray thaws them by one.';

  @override
  String get gotIt => 'Got it';

  @override
  String get cabinetTitle => 'Collector\'s Cabinet';

  @override
  String get cabinetFamilies => 'Coin families';

  @override
  String get undiscovered => 'Not yet discovered';

  @override
  String get finishesTitle => 'Coin finishes';

  @override
  String get finishesNote =>
      'Finishes only change how coins look. They never change the rules.';

  @override
  String get finishEnamel => 'Enamel';

  @override
  String get finishSatin => 'Satin';

  @override
  String get finishGilded => 'Gilded';

  @override
  String get useFinish => 'Use';

  @override
  String get inUse => 'In use';

  @override
  String buyForGilt(int n) {
    return '$n gilt';
  }

  @override
  String get familyJade => 'Jade Leaf';

  @override
  String get familyRuby => 'Ruby Flame';

  @override
  String get familySapphire => 'Sapphire Wave';

  @override
  String get familyAmber => 'Amber Sun';

  @override
  String get familyAmethyst => 'Amethyst Star';

  @override
  String get familyPearl => 'Pearl Moon';

  @override
  String get familyOnyx => 'Onyx Prism';

  @override
  String get familyCoral => 'Coral Clover';

  @override
  String tierN(int n) {
    return 'Tier $n';
  }

  @override
  String get shopTitle => 'Shop';

  @override
  String get shopEarnedSection => 'Spend earned gilt';

  @override
  String get shopHintPack => '3 hints';

  @override
  String get shopHintPackDesc =>
      'Each hint highlights one move that leads toward a solution.';

  @override
  String get shopBonusTray => 'Extra tray';

  @override
  String get shopBonusTrayDesc =>
      'Adds one empty tray to a level. Undo history before it is cleared.';

  @override
  String owned(int n) {
    return 'You have $n';
  }

  @override
  String get notEnoughGilt => 'Not enough gilt yet. Solving levels earns more.';

  @override
  String get purchasedItem => 'Added to your satchel.';

  @override
  String get shopFreeSection => 'Free with a video (optional)';

  @override
  String get watchForHint => 'Watch a video for 1 hint';

  @override
  String get adUnavailable =>
      'No videos are available right now. You can still earn hints by solving levels.';

  @override
  String get adDismissed => 'The video was closed early, so no hint was added.';

  @override
  String get adRewarded => '1 hint added. Thanks!';

  @override
  String get shopStoreSection => 'Store';

  @override
  String get removeAdsTitle => 'Remove ads';

  @override
  String get removeAdsDesc =>
      'Removes the occasional ad between levels. Optional reward videos stay available only if you choose them.';

  @override
  String get removeAdsOwned =>
      'Ads removed. Thank you for supporting the Atelier!';

  @override
  String get storeUnavailable =>
      'The store isn\'t available on this device right now.';

  @override
  String get purchasePending =>
      'Purchase pending. It will apply as soon as the store confirms it.';

  @override
  String get purchaseFailed =>
      'The purchase didn\'t go through. You weren\'t charged by the game.';

  @override
  String get restorePurchases => 'Restore purchases';

  @override
  String get restoreDone =>
      'Restore requested. Any owned purchases will apply automatically.';

  @override
  String get settingsAudio => 'Sound & feel';

  @override
  String get soundEffects => 'Sound effects';

  @override
  String get music => 'Music';

  @override
  String get haptics => 'Vibration';

  @override
  String get settingsAccess => 'Accessibility';

  @override
  String get reducedMotion => 'Reduced motion';

  @override
  String get reducedMotionDesc =>
      'Shorter, calmer animations and no particles.';

  @override
  String get colorBlind => 'Colour-blind assist';

  @override
  String get colorBlindDesc =>
      'Bolder rim patterns and family letters on every coin.';

  @override
  String get language => 'Language';

  @override
  String get systemLanguage => 'Device language';

  @override
  String get settingsPrivacy => 'Privacy & data';

  @override
  String get analyticsConsent => 'Share anonymous gameplay statistics';

  @override
  String get analyticsConsentDesc =>
      'Level and session counts only — never personal data. Off unless you turn it on.';

  @override
  String get privacy => 'Privacy';

  @override
  String get support => 'Help & support';

  @override
  String get credits => 'Credits';

  @override
  String get resetProgress => 'Reset local progress';

  @override
  String get resetConfirmTitle => 'Erase all progress?';

  @override
  String get resetConfirmBody =>
      'This permanently deletes your levels, gilt and items on this device. It cannot be undone.';

  @override
  String get resetConfirmAction => 'Erase';

  @override
  String get devOverlay => 'Developer overlay';

  @override
  String get privacyBody =>
      'Coin Atelier works fully offline. Your progress is stored only on this device. Gameplay statistics are collected only if you opt in, and contain no personal information. No advertising or purchase services are active in this build.';

  @override
  String get supportBody =>
      'Having trouble? Undo and Restart are always free, and every level has a verified solution. If something looks wrong, the details below help us investigate. They contain no personal data.';

  @override
  String get supportContactPending =>
      'A support contact will be listed here before release.';

  @override
  String appVersion(String v) {
    return 'Version $v';
  }

  @override
  String get recentIssues => 'Recent diagnostic codes';

  @override
  String get noIssues => 'No issues recorded.';

  @override
  String get creditsBody =>
      'Design, art, levels and sound are original to Coin Atelier. Sounds are synthesised in code.\n\nFonts: Fredoka (The Fredoka Project Authors) and Nunito (The Nunito Project Authors), both under the SIL Open Font License 1.1.\n\nBuilt with Flutter and Flame.';

  @override
  String a11yStack(int index, int count, String top) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count coins',
      one: '1 coin',
      zero: 'empty',
    );
    return 'Tray $index: $_temp0. $top';
  }

  @override
  String a11yTop(String name, int tier) {
    return 'Top coin $name tier $tier';
  }

  @override
  String get a11ySelected => 'Selected';

  @override
  String get a11yTarget => 'Can drop here';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get deal => 'Deal';

  @override
  String dealsLeft(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n deals left',
      one: '1 deal left',
      zero: 'No deals left',
    );
    return '$_temp0';
  }

  @override
  String get nextDeal => 'Next';

  @override
  String get rejectNoDeals => 'No deals left. Sort what\'s on the board.';

  @override
  String get rejectDealNoRoom =>
      'Make room in the highlighted trays, then deal.';

  @override
  String get hintDeal => 'Hint: press Deal now.';

  @override
  String get introTitleDeal => 'New: Deals';

  @override
  String get introBodyDeal =>
      'Press Deal to drop the next batch of coins into the trays. You can always see the next batch, and every level is solvable with its deals.';

  @override
  String chainText(int n) {
    return 'Chain ×$n!';
  }

  @override
  String goalSeal(String name, int n) {
    return '$name: $n left to seal';
  }

  @override
  String goalForge(int tier, int n) {
    return 'Tier $tier: $n left to forge';
  }

  @override
  String a11yDeal(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n left',
      one: '1 left',
      zero: 'none left',
    );
    return 'Deal next batch, $_temp0';
  }

  @override
  String get ruleDeal =>
      'Deal drops the next batch of coins; the next batch is always shown.';

  @override
  String workshopLevel(int n) {
    return 'Level $n';
  }

  @override
  String get workshopUnlock => 'Unlock';

  @override
  String get workshopTitle => 'Workshop slot';

  @override
  String get workshopBody =>
      'Adds a permanent empty tray to every level from now on. It never makes a level harder.';

  @override
  String workshopUnlockFor(int n) {
    return 'Unlock for $n gilt';
  }

  @override
  String workshopLocked(int n) {
    return 'Workshop slot, unlocks after level $n';
  }

  @override
  String workshopReady(int n) {
    return 'Workshop slot, unlock for $n gilt';
  }

  @override
  String get workshopUnlocked => 'Workshop slot added!';

  @override
  String get themes => 'Themes';

  @override
  String get themesTitle => 'Coin Themes';

  @override
  String get themesSubtitle =>
      'Play with the coins of your favourite currency. Every theme is free.';

  @override
  String get themeInUse => 'In use';

  @override
  String get themeUse => 'Use theme';

  @override
  String themeApplied(String name) {
    return '$name theme applied';
  }

  @override
  String themeCurrency(String currency, String symbol) {
    return '$currency ($symbol)';
  }

  @override
  String get chapter5 => 'Grand Hall';

  @override
  String get chapter5Desc => 'Bigger boards and more coins to sort.';

  @override
  String get chapter6 => 'Coin Rain';

  @override
  String get chapter6Desc => 'Deals pour in fast. Keep room to spare.';

  @override
  String get chapter7 => 'Twin Forge';

  @override
  String get chapter7Desc => 'Fuse up a tier and fill forge orders.';

  @override
  String get chapter8 => 'Shadow Market';

  @override
  String get chapter8Desc => 'Most coins stay veiled until you dig them out.';

  @override
  String get chapter9 => 'Winter Mint';

  @override
  String get chapter9Desc => 'Deep frost needs fusing nearby, twice.';

  @override
  String get chapter10 => 'Tall Towers';

  @override
  String get chapter10Desc => 'Tall trays take many coins to fill.';

  @override
  String get chapter11 => 'Midnight Vault';

  @override
  String get chapter11Desc => 'Veils and frost together.';

  @override
  String get chapter12 => 'Royal Treasury';

  @override
  String get chapter12Desc => 'Forge tiers in the dark.';

  @override
  String get chapter13 => 'Glacier Bank';

  @override
  String get chapter13Desc => 'Frozen coins on the forge.';

  @override
  String get chapter14 => 'Grand Bazaar';

  @override
  String get chapter14Desc => 'All eight coins on the biggest boards.';

  @override
  String get chapter15 => 'Iron Mint';

  @override
  String get chapter15Desc => 'Tall trays, hidden coins, big drops.';

  @override
  String get chapter16 => 'Crown Jewels';

  @override
  String get chapter16Desc => 'Every trick at once.';

  @override
  String get chapter17 => 'Master Atelier';

  @override
  String get chapter17Desc => 'The final test of a master sorter.';

  @override
  String get difficultyHard => 'Hard';

  @override
  String get difficultyExpert => 'Super hard';

  @override
  String difficultyBonus(String label, String mult) {
    return '$label level · ×$mult gilt';
  }

  @override
  String get fillRule => 'Fill a tray to seal';

  @override
  String get introTitleFill => 'New: Taller trays';

  @override
  String get introBodyFill =>
      'A tray seals when it is full of one kind of coin. Taller trays need more coins to fill. Deals drop several coins at once, so keep room to spare.';
}
