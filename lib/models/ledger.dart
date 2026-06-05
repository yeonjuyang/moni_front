class LedgerModel {
  final int ledgerId;
  final String ledgerName;
  final String ledgerType;
  final String? inviteCode;
  final String? myNickname;

  const LedgerModel({
    required this.ledgerId,
    required this.ledgerName,
    required this.ledgerType,
    this.inviteCode,
    this.myNickname,
  });

  factory LedgerModel.fromJson(Map<String, dynamic> json) => LedgerModel(
        ledgerId: (json['ledgerId'] as num).toInt(),
        ledgerName: json['ledgerName'] as String,
        ledgerType: json['ledgerType'] as String,
        inviteCode: json['inviteCode'] as String?,
        myNickname: json['myNickname'] as String?,
      );
}
