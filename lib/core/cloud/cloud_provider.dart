import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'focusday_cloud_storage.dart';

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final focusDayCloudStorageProvider = Provider<FocusDayCloudStorage>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return FocusDayCloudStorage(firestore);
});
