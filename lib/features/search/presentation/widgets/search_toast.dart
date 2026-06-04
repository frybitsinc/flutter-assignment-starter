import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../theme/app_assets.dart';
import '../../../../theme/app_theme.dart';
import '../layout/search_layout_spec.dart';

class SearchToast extends StatelessWidget {
  const SearchToast({required this.layout, required this.message, super.key});

  final SearchLayoutSpec layout;
  final String message;

  TextSpan _toastTextSpan(String message) {
    const highlight = '관심그룹';
    final baseStyle = AppTypography.searchToast;
    final index = message.indexOf(highlight);
    if (index < 0) {
      return TextSpan(text: message, style: baseStyle);
    }
    return TextSpan(
      style: baseStyle,
      children: [
        TextSpan(text: message.substring(0, index)),
        TextSpan(text: highlight),
        TextSpan(
          text: message.substring(index + highlight.length),
          style: baseStyle.copyWith(color: AppColors.text.text_3_9e9e9e),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            offset: Offset(0, 2),
            blurRadius: 10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: SearchLayoutSpec.toastHeight,
            padding: EdgeInsets.symmetric(
              horizontal: 16 * layout.horizontalScale,
            ),
            decoration: BoxDecoration(
              color: AppDerivedColors.searchToastBackground,
              border: Border.all(color: AppDerivedColors.searchToastBorder),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Stack(
                    children: [
                      AppAssetSlotIcon(
                        key: const Key('search-toast-favorite-icon'),
                        assetPath: AppAssets.favoriteHeart,
                        slotWidth: 20,
                        slotHeight: 20,
                        assetWidth: AppAssetSizes.favoriteHeart.width,
                        assetHeight: AppAssetSizes.favoriteHeart.height,
                        color: AppColors.mainAndAccent.up_f93f62,
                      ),
                      Positioned(
                        top: 6,
                        left: 7,
                        child: AppAssetSlotIcon(
                          key: const Key('search-toast-check-icon'),
                          assetPath: AppAssets.toastCheck,
                          slotWidth: 6,
                          slotHeight: 6,
                          assetWidth: AppAssetSizes.toastCheck.width,
                          assetHeight: AppAssetSizes.toastCheck.height,
                          color: AppColors.grays.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    _toastTextSpan(message),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
