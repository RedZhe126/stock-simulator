import 'package:hive/hive.dart';

part 'user_asset.g.dart';

@HiveType(typeId: 0)
class UserAsset extends HiveObject {
  @HiveField(0)
  double balance;

  @HiveField(1)
  double initialCapital;

  @HiveField(2)
  double totalInvested;

  UserAsset({
    required this.balance,
    required this.initialCapital,
    this.totalInvested = 0.0,
  });

  double get totalAssets => balance + totalInvested;
  double get totalReturn => (totalAssets - initialCapital) / initialCapital;
}
