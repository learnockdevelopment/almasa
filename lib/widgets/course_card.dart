import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:elmasa/utils/iconly.dart';
import 'package:elmasa/providers/language_provider.dart';

class CourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final bool isEnrolled;
  final bool allowPaymentInApp;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteTap;
  final LanguageProvider lang;
  final String? currency;

  const CourseCard({
    super.key,
    required this.course,
    required this.isEnrolled,
    required this.allowPaymentInApp,
    required this.isFavorite,
    required this.onTap,
    this.onFavoriteTap,
    required this.lang,
    this.currency,
  });

  static String _stripHtml(String? html) {
    if (html == null || html.isEmpty) return '';
    String result = html
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
    result = result.replaceAll(RegExp(r'<[^>]*>'), '');
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.primaryColor;
    final onSurface = theme.colorScheme.onSurface;

    final String title = course['title'] ?? '';
    final String desc = _stripHtml(course['description']?.toString());
    final String thumb = course['thumbnail_url']?.toString() ?? course['image_url']?.toString() ?? '';
    final String cat = course['category_name']?.toString() ?? '';
    final bool hasDemo = course['demo_video_url'] != null && course['demo_video_url'].toString().isNotEmpty;

    final bool isFree = course['is_free'] == 1 || course['is_free'] == '1' || course['is_free'] == true
        || course['price'] == '0.00' || course['price'] == 0 || course['price'] == '0';
    final String priceStr = course['price']?.toString() ?? '0.00';
    final double progress = double.tryParse(course['progress']?.toString() ?? '0') ?? 0.0;

    final String lecturesCount = course['total_materials']?.toString()
        ?? course['materials_count']?.toString() ?? '0';
    final String studentsCount = course['total_students']?.toString()
        ?? course['enrollment_count']?.toString()
        ?? course['members_count']?.toString() ?? '0';

    final Color freeColor = const Color(0xFF10B981);

    Widget thumbPlaceholder() => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primary.withOpacity(0.35), primary.withOpacity(0.08)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Icon(IconlyLight.image, color: primary, size: 34),
        );

    Widget metaPill(IconData icon, String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: onSurface.withOpacity(isDark ? 0.07 : 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: primary),
              const SizedBox(width: 4),
              Text(
                text,
                style: GoogleFonts.cairo(
                  color: onSurface.withOpacity(0.75),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF1E293B), Color.alphaBlend(primary.withOpacity(0.08), const Color(0xFF1E293B))]
                    : [Colors.white, Color.alphaBlend(primary.withOpacity(0.05), Colors.white)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: primary.withOpacity(isDark ? 0.18 : 0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withOpacity(0.35) : primary.withOpacity(0.10),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── THUMBNAIL ─────────────────────────────────────────────
                SizedBox(
                  width: 104,
                  height: 112,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: thumb.isNotEmpty
                              ? Image.network(
                                  thumb,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => thumbPlaceholder(),
                                )
                              : thumbPlaceholder(),
                        ),
                      ),
                      // bottom fade for readability
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withOpacity(0.18)],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (hasDemo)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.92),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 10),
                              ],
                            ),
                            child: Icon(IconlyBold.play, color: primary, size: 16),
                          ),
                        ),
                      if (isEnrolled)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: freeColor, shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded, color: Colors.white, size: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // ── DETAILS ───────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          if (cat.isNotEmpty)
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: primary.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  cat.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.cairo(
                                    color: primary,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ),
                          const Spacer(),
                          if (onFavoriteTap != null)
                            InkWell(
                              onTap: onFavoriteTap,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isFavorite
                                      ? const Color(0xFFEF4444).withOpacity(0.12)
                                      : onSurface.withOpacity(0.06),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isFavorite ? IconlyBold.heart : IconlyLight.heart,
                                  color: isFavorite ? const Color(0xFFEF4444) : onSurface.withOpacity(0.45),
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: GoogleFonts.cairo(
                          color: onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          desc,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            color: onSurface.withOpacity(0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (isEnrolled)
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: (progress / 100).clamp(0.0, 1.0),
                                  backgroundColor: primary.withOpacity(0.14),
                                  valueColor: AlwaysStoppedAnimation<Color>(primary),
                                  minHeight: 6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${progress.round()}%',
                              style: GoogleFonts.cairo(
                                color: primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  metaPill(IconlyLight.document, lecturesCount),
                                  metaPill(IconlyLight.user, studentsCount),
                                ],
                              ),
                            ),
                            if (allowPaymentInApp)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isFree ? freeColor.withOpacity(0.14) : primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  isFree ? lang.translate('free') : '$priceStr ${currency ?? ''}',
                                  style: GoogleFonts.cairo(
                                    color: isFree ? freeColor : Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
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
