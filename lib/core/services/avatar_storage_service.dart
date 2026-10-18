import 'cloud_image_storage.dart';

/// Оставлено под прежним именем, чтобы UserProfileProvider работал без
/// изменений. Теперь внутри — Supabase Storage вместо Firebase Storage.
class AvatarStorageService {
  AvatarStorageService._();
  static final AvatarStorageService instance = AvatarStorageService._();

  Future<String?> uploadAvatar(String localFilePath) =>
      CloudImageStorage.instance.uploadAvatar(localFilePath);

  Future<void> deleteAvatar() => CloudImageStorage.instance.deleteAvatar();
}
