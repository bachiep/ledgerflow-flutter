import 'package:drift/drift.dart';

@DataClassName('WalletRow')
class Wallets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get currency => text().withDefault(const Constant('VND'))();
  IntColumn get initialBalanceMinor =>
      integer().withDefault(const Constant(0))();
  BoolColumn get isShared => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAtEpochMs => integer()();
  IntColumn get deletedAtEpochMs => integer().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get type => text()();
  TextColumn get iconName => text()();
  IntColumn get colorHex => integer()();
  IntColumn get monthlyBudgetMinor =>
      integer().withDefault(const Constant(0))();
  IntColumn get updatedAtEpochMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TransactionRow')
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get walletId => text().references(Wallets, #id)();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get type => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get occurredAtEpochMs => integer()();
  IntColumn get updatedAtEpochMs => integer()();
  IntColumn get deletedAtEpochMs => integer().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SyncOutboxRow')
class SyncOutbox extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  TextColumn get payloadJson => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  IntColumn get createdAtEpochMs => integer()();
  IntColumn get processedAtEpochMs => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SyncMetadataRow')
class SyncMetadata extends Table {
  TextColumn get metaKey => text()();
  TextColumn get metaValue => text()();

  @override
  Set<Column<Object>> get primaryKey => {metaKey};
}
