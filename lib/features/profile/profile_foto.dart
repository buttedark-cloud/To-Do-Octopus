import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:to_do/core/providers/user_profile_provider.dart';

class ProfileFoto extends StatefulWidget {
  const ProfileFoto({super.key});

  @override
  State<ProfileFoto> createState() => _ProfileFotoState();
}

class _ProfileFotoState extends State<ProfileFoto> {
  final ImagePicker _picker = ImagePicker();

  // Выбор фото из галереи + кадрирование — пользователь сам выбирает,какой фрагмент картинки станет аватаркой.
  Future<void> _pickAndCropAvatar() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile == null) return; // пользователь ничего не выбрал

      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Настройте фото',
            toolbarColor: const Color(0xFF1E1435),
            toolbarWidgetColor: Colors.white,
            backgroundColor: const Color(0xFF1E1435),
            activeControlsWidgetColor: const Color(0xFF46D3D3),
            lockAspectRatio: false,
            hideBottomControls: false,
            cropStyle: CropStyle.circle,
          ),
          
          IOSUiSettings(
            title: 'Настройте фото',
            aspectRatioLockEnabled: false,
            cropStyle: CropStyle.circle,
          ),
        ],
      );

      if (croppedFile == null) return; // пользователь отменил кадрирование
      if (!mounted) return;

    
      await context.read<UserProfileProvider>().updatePhoto(croppedFile.path);
    } catch (e) {
      debugPrint('Ошибка при выборе/обрезке фото: $e');
    }
  }

  Future<void> _deleteImage() async {
    await context.read<UserProfileProvider>().updatePhoto(null);
    debugPrint('Фото профиля удалено');
  }

  // На некоторых телефонах (особенно с жестовой навигацией без физических
  // кнопок) пункты шторки стояли слишком близко к самому краю экрана —
  // добавляем явный отступ и полоску-индикатор сверху.
  void _openAvatarOptions(BuildContext context, bool hasPhoto) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF261936),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          minimum: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library,
                    color: Color(0xFF46D3D3),
                  ),
                  title: const Text(
                    'Выбрать из галереи',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndCropAvatar();
                  },
                ),
                if (hasPhoto)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever,
                      color: Color(0xFFEF4444),
                    ),
                    title: const Text(
                      'Удалить текущее фото',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _deleteImage();
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // Путь может быть либо локальным файлом (выбран из галереи на этом
  // телефоне), либо http-ссылкой (аватар из Google, в том числе
  // прилетевший через облачную синхронизацию с другого устройства).
  ImageProvider? _resolveImage(String? photoPath) {
    if (photoPath == null || photoPath.isEmpty) return null;
    if (photoPath.startsWith('http')) return NetworkImage(photoPath);
    final file = File(photoPath);
    return file.existsSync() ? FileImage(file) : null;
  }

  @override
  Widget build(BuildContext context) {
    final photoPath = context.watch<UserProfileProvider>().photoPath;
    final image = _resolveImage(photoPath);

    return GestureDetector(
      onTap: () => _openAvatarOptions(context, image != null),
      child: Stack(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFF1E1435),
            backgroundImage: image,
            child: image == null
                ? const Icon(Icons.person, size: 50, color: Colors.white)
                : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF46D3D3),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF1E1435), width: 2),
              ),
              child: const Icon(Icons.edit, size: 16, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
