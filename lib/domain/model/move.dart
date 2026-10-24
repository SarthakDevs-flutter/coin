/// Player intent: lift the top run from [from] and drop it on [to].
/// The number of coins moved is decided by the rules, never by the UI.
final class MoveCommand {
  const MoveCommand(this.from, this.to);

  /// The Deal action. Shares the move pipeline (validation, undo, solver
  /// paths, hints) so it can never diverge from regular moves.
  static const deal = MoveCommand(dealToken, dealToken);
  static const dealToken = '*deal';

  bool get isDeal => from == dealToken;

  final String from;
  final String to;

  Map<String, Object?> toJson() => {'from': from, 'to': to};

  factory MoveCommand.fromJson(Map<String, Object?> json) =>
      MoveCommand(json['from']! as String, json['to']! as String);

  @override
  bool operator ==(Object other) =>
      other is MoveCommand && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => '$from→$to';
}
