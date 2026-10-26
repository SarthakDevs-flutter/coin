import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../application/ports/ports.dart';
import 'ad_units.dart';
import 'admob_banner.dart';
import 'preloaded_ad.dart';

/// Google AdMob behind [AdsPort].
///
/// Other ad networks join through AdMob mediation: add the network's
/// `gma_mediation_*` adapter package and its mediation group in the AdMob
/// console. Nothing in this class changes; consent gathered here through the
/// UMP SDK (IAB TCF / US state privacy) is forwarded to every adapter.
final class AdmobAds implements AdsPort {
  AdmobAds(this.units, {this.onFullScreenChanged, DateTime Function()? now})
    : _now = now ?? DateTime.now {
    _interstitial = PreloadedAd<InterstitialAd>(
      name: 'interstitial',
      ttl: const Duration(minutes: 55),
      load: _loadInterstitial,
      release: (ad) => ad.dispose(),
      now: _now,
      log: _log,
    );
    _rewarded = PreloadedAd<RewardedAd>(
      name: 'rewarded',
      ttl: const Duration(minutes: 55),
      load: _loadRewarded,
      release: (ad) => ad.dispose(),
      now: _now,
      log: _log,
    );
    _appOpen = PreloadedAd<AppOpenAd>(
      name: 'app_open',
      ttl: const Duration(hours: 4) - const Duration(minutes: 5),
      load: _loadAppOpen,
      release: (ad) => ad.dispose(),
      now: _now,
      log: _log,
    );
  }

  final AdUnits units;

  /// Pause and resume game audio around full-screen ads.
  final void Function(bool showing)? onFullScreenChanged;
  final DateTime Function() _now;

  late final PreloadedAd<InterstitialAd> _interstitial;
  late final PreloadedAd<RewardedAd> _rewarded;
  late final PreloadedAd<AppOpenAd> _appOpen;

  Future<void>? _starting;
  bool _sdkReady = false;
  bool _interruptions = false;
  bool _showing = false;
  DateTime? _lastClosed;
  var _seq = 0;

  /// Drives every banner: true once the SDK runs and interruptions are on.
  final _bannersOn = ValueNotifier<bool>(false);

  static const _request = AdRequest();

  @override
  bool get isConfigured => true;

  @override
  bool get isShowingFullScreen => _showing;

  @override
  DateTime? get lastFullScreenClosedAt => _lastClosed;

  // ---- lifecycle ------------------------------------------------------------

  @override
  Future<void> start() => _starting ??= _start();

  Future<void> _start() async {
    // Consent from an earlier session lets ads start before the (network)
    // consent refresh returns.
    if (await _canRequestAds()) await _initSdk();
    await _refreshConsent();
    if (_sdkReady) return;
    if (await _canRequestAds()) {
      await _initSdk();
    } else if (!kReleaseMode) {
      // Sample app ids have no consent message in any AdMob account, so UMP
      // always fails in development. Test ads carry no personal data.
      _log('consent unavailable; starting with test ads (debug only)');
      await _initSdk();
    }
  }

  Future<void> _refreshConsent() async {
    final updated = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        // Shows the form only where required (EEA, UK, US states...) and
        // only until the player has answered.
        await ConsentForm.loadAndShowConsentFormIfRequired((error) {
          if (error != null) _log('consent form: ${error.message}');
        });
        if (!updated.isCompleted) updated.complete();
      },
      (error) {
        _log('consent update: ${error.message}');
        if (!updated.isCompleted) updated.complete();
      },
    );
    await updated.future;
  }

  Future<bool> _canRequestAds() async {
    try {
      return await ConsentInformation.instance.canRequestAds();
    } on Object catch (e) {
      _log('canRequestAds: $e');
      return false;
    }
  }

  Future<void> _initSdk() async {
    if (_sdkReady) return;
    final status = await MobileAds.instance.initialize();
    if (kDebugMode) {
      for (final MapEntry(:key, :value) in status.adapterStatuses.entries) {
        _log('adapter $key: ${value.state.name} ${value.description}');
      }
    }
    _sdkReady = true;
    _rewarded.enable();
    _applyInterruptions();
  }

  @override
  void setInterruptionsEnabled(bool enabled) {
    if (_interruptions == enabled) return;
    _interruptions = enabled;
    _applyInterruptions();
  }

  void _applyInterruptions() {
    final on = _sdkReady && _interruptions;
    if (on) {
      _interstitial.enable();
      _appOpen.enable();
    } else {
      _interstitial.disable();
      _appOpen.disable();
    }
    _bannersOn.value = on;
  }

  // ---- privacy --------------------------------------------------------------

  @override
  Future<bool> privacyOptionsRequired() async {
    try {
      return await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } on Object catch (e) {
      _log('privacy options status: $e');
      return false;
    }
  }

  @override
  Future<void> showPrivacyOptions() async {
    final done = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((error) {
      if (error != null) _log('privacy options: ${error.message}');
      if (!done.isCompleted) done.complete();
    });
    await done.future;
    // A withdrawn consent may stop ads; a new one may allow them.
    if (!_sdkReady && await _canRequestAds()) await _initSdk();
  }

  // ---- loading --------------------------------------------------------------

  Future<InterstitialAd> _loadInterstitial() {
    final c = Completer<InterstitialAd>();
    InterstitialAd.load(
      adUnitId: units.interstitial,
      request: _request,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: c.complete,
        onAdFailedToLoad: c.completeError,
      ),
    );
    return c.future;
  }

  Future<RewardedAd> _loadRewarded() {
    final c = Completer<RewardedAd>();
    RewardedAd.load(
      adUnitId: units.rewarded,
      request: _request,
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: c.complete,
        onAdFailedToLoad: c.completeError,
      ),
    );
    return c.future;
  }

  Future<AppOpenAd> _loadAppOpen() {
    final c = Completer<AppOpenAd>();
    AppOpenAd.load(
      adUnitId: units.appOpen,
      request: _request,
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: c.complete,
        onAdFailedToLoad: c.completeError,
      ),
    );
    return c.future;
  }

  // ---- showing --------------------------------------------------------------

  @override
  Future<bool> isRewardedReady() async =>
      _sdkReady && await _rewarded.waitUntilReady(const Duration(seconds: 4));

  @override
  Future<({AdOutcome outcome, String token})> showRewarded(
    String placement,
  ) async {
    final token = 'admob-${_now().microsecondsSinceEpoch}-${_seq++}';
    var earned = false;
    final outcome = await _present<RewardedAd>(
      _rewarded,
      (ad, cb) => ad.fullScreenContentCallback = cb,
      (ad) => ad.show(onUserEarnedReward: (_, _) => earned = true),
    );
    return (
      outcome: switch (outcome) {
        AdOutcome.completed when earned => AdOutcome.completed,
        AdOutcome.completed => AdOutcome.dismissed,
        _ => outcome,
      },
      token: token,
    );
  }

  @override
  Future<AdOutcome> showInterstitial(String placement) =>
      _present<InterstitialAd>(
        _interstitial,
        (ad, cb) => ad.fullScreenContentCallback = cb,
        (ad) => ad.show(),
      );

  @override
  Future<AdOutcome> showAppOpen(String placement) => _present<AppOpenAd>(
    _appOpen,
    (ad, cb) => ad.fullScreenContentCallback = cb,
    (ad) => ad.show(),
  );

  /// Shows one cached ad and completes when it closes. [AdOutcome.completed]
  /// means it was shown and dismissed normally.
  Future<AdOutcome> _present<T extends AdWithoutView>(
    PreloadedAd<T> slot,
    void Function(T ad, FullScreenContentCallback<T> cb) attach,
    Future<void> Function(T ad) show,
  ) async {
    if (!_sdkReady || _showing) return AdOutcome.unavailable;
    final ad = slot.take();
    if (ad == null) return AdOutcome.unavailable;
    final closed = Completer<AdOutcome>();
    attach(
      ad,
      FullScreenContentCallback<T>(
        onAdDismissedFullScreenContent: (a) {
          a.dispose();
          if (!closed.isCompleted) closed.complete(AdOutcome.completed);
        },
        onAdFailedToShowFullScreenContent: (a, error) {
          _log('${slot.name} show failed: ${error.message}');
          a.dispose();
          if (!closed.isCompleted) closed.complete(AdOutcome.failed);
        },
      ),
    );
    _setShowing(true);
    try {
      await show(ad);
      return await closed.future;
    } on Object catch (e) {
      _log('${slot.name} show threw: $e');
      ad.dispose();
      return AdOutcome.failed;
    } finally {
      _setShowing(false);
      slot.ensureLoaded();
    }
  }

  void _setShowing(bool showing) {
    if (_showing == showing) return;
    _showing = showing;
    if (!showing) _lastClosed = _now();
    onFullScreenChanged?.call(showing);
  }

  // ---- banner ---------------------------------------------------------------

  @override
  Widget banner(String placement) => ValueListenableBuilder<bool>(
    valueListenable: _bannersOn,
    builder: (context, on, _) => on
        ? AdmobBanner(adUnitId: units.banner, request: _request)
        : const SizedBox.shrink(),
  );

  static void _log(String message) {
    if (kDebugMode) debugPrint('ads: $message');
  }
}
