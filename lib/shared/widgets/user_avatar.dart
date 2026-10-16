import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../core/theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.radius = 20});
  final AppUser user;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final initials = user.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0])
        .join()
        .toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: context.palette.greenLight,
      backgroundImage: user.avatarBytes == null
          ? null
          : MemoryImage(user.avatarBytes!),
      child: user.avatarBytes != null
          ? null
          : Text(
              initials,
              style: TextStyle(
                color: context.palette.greenDark,
                fontSize: radius * .65,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}
