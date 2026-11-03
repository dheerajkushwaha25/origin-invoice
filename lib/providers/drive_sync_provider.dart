import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ezinvoice/services/drive_sync_service.dart';

final driveSyncProvider = Provider<DriveSyncService>((ref) => DriveSyncService());
