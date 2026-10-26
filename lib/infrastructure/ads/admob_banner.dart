import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Large anchored adaptive banner, sized to the parent's width.
///
/// Takes no space until an ad has loaded, so a no-fill never leaves a hole.
/// Releases the ad while its route is covered by another full-screen route
/// (TickerMode off), so hidden banners never refresh or count impressions,
/// and reloads when the route returns.
class AdmobBanner extends StatefulWidget {
  const AdmobBanner({super.key, required this.adUnitId, required this.request});

  final String adUnitId;
  final AdRequest request;

  @override
  State<AdmobBanner> createState() => _AdmobBannerState();
}

class _AdmobBannerState extends State<AdmobBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _loading = false;
  int _width = 0;
  int _failures = 0;
  Timer? _retry;
  bool _visible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible == _visible) return;
    _visible = visible;
    if (visible) {
      _load();
    } else {
      _release();
    }
  }

  Future<void> _load() async {
    if (!_visible || _loading || _ad != null || _width <= 0) return;
    _loading = true;
    final width = _width;
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (!mounted || size == null || !_visible || width != _width) {
      _loading = false;
      return;
    }
    final ad = BannerAd(
      adUnitId: widget.adUnitId,
      request: widget.request,
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted || _ad != ad) {
            ad.dispose();
            return;
          }
          _failures = 0;
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (_ad != ad) return;
          _ad = null;
          if (mounted) setState(() => _loaded = false);
          _scheduleRetry();
        },
      ),
    );
    _ad = ad;
    _loading = false;
    await ad.load();
  }

  void _scheduleRetry() {
    _failures++;
    final seconds = math.min(15 * (1 << math.min(_failures - 1, 4)), 240);
    _retry?.cancel();
    _retry = Timer(Duration(seconds: seconds), () {
      _retry = null;
      if (mounted) _load();
    });
  }

  void _release() {
    _retry?.cancel();
    _retry = null;
    _ad?.dispose();
    _ad = null;
    if (mounted && _loaded) setState(() => _loaded = false);
    _loaded = false;
  }

  @override
  void dispose() {
    _retry?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth.isFinite
          ? constraints.maxWidth.truncate()
          : MediaQuery.sizeOf(context).width.truncate();
      if (width != _width) {
        _width = width;
        // Width changed (rotation, split screen): size a fresh banner.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _release();
          _load();
        });
      }
      final ad = _ad;
      if (!_loaded || ad == null) return const SizedBox.shrink();
      return SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      );
    },
  );
}
