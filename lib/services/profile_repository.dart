import '../models/profile.dart';
import 'auth_service.dart';

class AccountProfile {
  final Profile profile;
  final bool onboarded;
  final bool trainer;
  AccountProfile(this.profile, {required this.onboarded, this.trainer = false});
}

abstract class ProfileRepository {
  Future<AccountProfile> loadOrCreate(AccountIdentity user);
  Future<void> save(String uid, Profile profile, {required bool onboarded});
}
