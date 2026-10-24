/// One row of the soft-currency audit ledger.
final class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.amount,
    required this.reason,
    required this.at,
  });

  /// Idempotency key: the same id is never applied twice.
  final String id;
  final int amount;
  final String reason;
  final DateTime at;

  Map<String, Object?> toJson() => {
    'id': id,
    'amount': amount,
    'reason': reason,
    'at': at.toUtc().toIso8601String(),
  };

  factory LedgerEntry.fromJson(Map<String, Object?> j) => LedgerEntry(
    id: j['id']! as String,
    amount: j['amount']! as int,
    reason: j['reason']! as String,
    at: DateTime.parse(j['at']! as String),
  );
}

final class CompletionRecord {
  const CompletionRecord({
    required this.levelVersion,
    required this.bestMoves,
    required this.firstCompletedAt,
  });

  final int levelVersion;
  final int bestMoves;
  final DateTime firstCompletedAt;

  Map<String, Object?> toJson() => {
    'version': levelVersion,
    'best': bestMoves,
    'first': firstCompletedAt.toUtc().toIso8601String(),
  };

  factory CompletionRecord.fromJson(Map<String, Object?> j) => CompletionRecord(
    levelVersion: j['version']! as int,
    bestMoves: j['best']! as int,
    firstCompletedAt: DateTime.parse(j['first']! as String),
  );
}

enum InventoryItem { hint, bonusTray }

/// Everything the player owns or has achieved. Immutable.
final class PlayerProfile {
  PlayerProfile({
    required this.gilt,
    required Map<InventoryItem, int> inventory,
    required Map<String, CompletionRecord> completions,
    required Set<String> appliedTransactions,
    required List<LedgerEntry> ledger,
    required Set<String> discoveredFamilies,
    required Set<String> ownedFinishes,
    required this.activeFinish,
    required Set<String> seenIntroductions,
    this.tutorialDone = false,
    this.lastStipendDay,
    this.removeAds = false,
    this.levelsCompletedSinceInterstitial = 0,
    this.workshopSlots = 0,
  }) : inventory = Map.unmodifiable(inventory),
       completions = Map.unmodifiable(completions),
       appliedTransactions = Set.unmodifiable(appliedTransactions),
       ledger = List.unmodifiable(ledger),
       discoveredFamilies = Set.unmodifiable(discoveredFamilies),
       ownedFinishes = Set.unmodifiable(ownedFinishes),
       seenIntroductions = Set.unmodifiable(seenIntroductions);

  factory PlayerProfile.fresh() => PlayerProfile(
    gilt: 0,
    inventory: const {InventoryItem.hint: 3, InventoryItem.bonusTray: 1},
    completions: const {},
    appliedTransactions: const {},
    ledger: const [],
    discoveredFamilies: const {},
    ownedFinishes: const {'enamel'},
    activeFinish: 'enamel',
    seenIntroductions: const {},
  );

  static const int ledgerLimit = 200;

  final int gilt;
  final Map<InventoryItem, int> inventory;
  final Map<String, CompletionRecord> completions;

  /// Idempotency keys of every reward, purchase and ad grant applied.
  final Set<String> appliedTransactions;
  final List<LedgerEntry> ledger;
  final Set<String> discoveredFamilies;
  final Set<String> ownedFinishes;
  final String activeFinish;
  final Set<String> seenIntroductions;
  final bool tutorialDone;

  /// yyyy-mm-dd of the last claimed daily stipend (local calendar day).
  final String? lastStipendDay;
  final bool removeAds;
  final int levelsCompletedSinceInterstitial;

  /// Number of permanent top-row workshop slots unlocked.
  final int workshopSlots;

  int count(InventoryItem item) => inventory[item] ?? 0;
  bool isCompleted(String levelId) => completions.containsKey(levelId);

  PlayerProfile copyWith({
    int? gilt,
    Map<InventoryItem, int>? inventory,
    Map<String, CompletionRecord>? completions,
    Set<String>? appliedTransactions,
    List<LedgerEntry>? ledger,
    Set<String>? discoveredFamilies,
    Set<String>? ownedFinishes,
    String? activeFinish,
    Set<String>? seenIntroductions,
    bool? tutorialDone,
    String? lastStipendDay,
    bool? removeAds,
    int? levelsCompletedSinceInterstitial,
    int? workshopSlots,
  }) => PlayerProfile(
    gilt: gilt ?? this.gilt,
    inventory: inventory ?? this.inventory,
    completions: completions ?? this.completions,
    appliedTransactions: appliedTransactions ?? this.appliedTransactions,
    ledger: ledger ?? this.ledger,
    discoveredFamilies: discoveredFamilies ?? this.discoveredFamilies,
    ownedFinishes: ownedFinishes ?? this.ownedFinishes,
    activeFinish: activeFinish ?? this.activeFinish,
    seenIntroductions: seenIntroductions ?? this.seenIntroductions,
    tutorialDone: tutorialDone ?? this.tutorialDone,
    lastStipendDay: lastStipendDay ?? this.lastStipendDay,
    removeAds: removeAds ?? this.removeAds,
    levelsCompletedSinceInterstitial:
        levelsCompletedSinceInterstitial ??
        this.levelsCompletedSinceInterstitial,
    workshopSlots: workshopSlots ?? this.workshopSlots,
  );

  Map<String, Object?> toJson() => {
    'gilt': gilt,
    'inventory': {for (final e in inventory.entries) e.key.name: e.value},
    'completions': {
      for (final e in completions.entries) e.key: e.value.toJson(),
    },
    'applied': appliedTransactions.toList()..sort(),
    'ledger': [for (final l in ledger) l.toJson()],
    'families': discoveredFamilies.toList()..sort(),
    'finishes': ownedFinishes.toList()..sort(),
    'activeFinish': activeFinish,
    'intros': seenIntroductions.toList()..sort(),
    'tutorialDone': tutorialDone,
    'lastStipendDay': ?lastStipendDay,
    'removeAds': removeAds,
    'sinceInterstitial': levelsCompletedSinceInterstitial,
    'workshopSlots': workshopSlots,
  };

  factory PlayerProfile.fromJson(Map<String, Object?> j) {
    List<String> strings(String k) => [
      for (final v in (j[k] as List?) ?? const []) v as String,
    ];
    return PlayerProfile(
      gilt: j['gilt']! as int,
      inventory: {
        for (final e in ((j['inventory'] as Map?) ?? const {}).entries)
          if (InventoryItem.values.any((i) => i.name == e.key))
            InventoryItem.values.byName(e.key as String): e.value as int,
      },
      completions: {
        for (final e in ((j['completions'] as Map?) ?? const {}).entries)
          e.key as String: CompletionRecord.fromJson((e.value as Map).cast()),
      },
      appliedTransactions: strings('applied').toSet(),
      ledger: [
        for (final l in (j['ledger'] as List?) ?? const [])
          LedgerEntry.fromJson((l as Map).cast()),
      ],
      discoveredFamilies: strings('families').toSet(),
      ownedFinishes: {'enamel', ...strings('finishes')},
      activeFinish: (j['activeFinish'] as String?) ?? 'enamel',
      seenIntroductions: strings('intros').toSet(),
      tutorialDone: (j['tutorialDone'] as bool?) ?? false,
      lastStipendDay: j['lastStipendDay'] as String?,
      removeAds: (j['removeAds'] as bool?) ?? false,
      levelsCompletedSinceInterstitial: (j['sinceInterstitial'] as int?) ?? 0,
      workshopSlots: (j['workshopSlots'] as int?) ?? 0,
    );
  }
}
