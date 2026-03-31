import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class AppTheme {
  // ── Color Palette ──
  static const Color primaryDark = Color(0xFF0D0B1A);
  static const Color surfaceDark = Color(0xFF151229);
  static const Color cardDark = Color(0xFF1C1838);
  static const Color cardBorder = Color(0xFF2A2650);
  static const Color accentIndigo = Color(0xFF6C63FF);
  static const Color accentViolet = Color(0xFF9D4EDD);
  static const Color accentCyan = Color(0xFF00D4FF);
  static const Color accentGreen = Color(0xFF00E676);
  static const Color accentOrange = Color(0xFFFF9100);
  static const Color accentPink = Color(0xFFFF4081);
  static const Color textPrimary = Color(0xFFF0ECF7);
  static const Color textSecondary = Color(0xFF9E97B8);
  static const Color textTertiary = Color(0xFF6B648A);

  // ── Shared Markdown StyleSheet for dark theme ──
  // Use this everywhere markdown is rendered to ensure
  // readable colors on the dark background.
  static MarkdownStyleSheet get markdownStyle => MarkdownStyleSheet(
        // ── Body text ──
        p: const TextStyle(
          color: textPrimary,
          fontSize: 15,
          height: 1.6,
        ),
        // ── Headers ──
        h1: const TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
        h2: const TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        h3: const TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        h4: const TextStyle(
          color: textSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        // ── Bold / italic ──
        strong: const TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        em: const TextStyle(
          color: textSecondary,
          fontStyle: FontStyle.italic,
        ),
        // ── Links ──
        a: const TextStyle(
          color: accentCyan,
          decoration: TextDecoration.underline,
          decorationColor: accentCyan,
        ),
        // ── Code ──
        code: const TextStyle(
          color: accentCyan,
          backgroundColor: primaryDark,
          fontSize: 13,
          fontFamily: 'monospace',
        ),
        codeblockDecoration: BoxDecoration(
          color: primaryDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cardBorder),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        // ── Blockquotes (the main fix!) ──
        blockquote: const TextStyle(
          color: textPrimary,
          fontSize: 15,
          height: 1.6,
        ),
        blockquoteDecoration: BoxDecoration(
          color: accentIndigo.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
          border: const Border(
            left: BorderSide(color: accentIndigo, width: 3),
          ),
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        // ── Lists ──
        listBullet: const TextStyle(color: textSecondary),
        listIndent: 24,
        // ── Horizontal rule ──
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: cardBorder.withValues(alpha: 0.5), width: 1),
          ),
        ),
        // ── Tables ──
        tableHead: const TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        tableBody: const TextStyle(
          color: textSecondary,
          fontSize: 14,
        ),
        tableBorder: TableBorder.all(
          color: cardBorder,
          width: 1,
          borderRadius: BorderRadius.circular(8),
        ),
        tableHeadAlign: TextAlign.left,
        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tableColumnWidth: const IntrinsicColumnWidth(),
      );

  // ── Gradients ──
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentIndigo, accentViolet],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E1A3A),
      Color(0xFF14112A),
    ],
  );

  static const LinearGradient shimmerGradient = LinearGradient(
    colors: [
      Color(0x00FFFFFF),
      Color(0x14FFFFFF),
      Color(0x00FFFFFF),
    ],
  );

  // ── Theme Data ──
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: primaryDark,
      colorScheme: const ColorScheme.dark(
        primary: accentIndigo,
        secondary: accentViolet,
        tertiary: accentCyan,
        surface: surfaceDark,
        onSurface: textPrimary,
        onPrimary: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -0.5,
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: textPrimary,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: textSecondary,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: textSecondary,
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentIndigo, width: 2),
        ),
        hintStyle: const TextStyle(color: textTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentIndigo,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentIndigo,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceDark,
        selectedItemColor: accentIndigo,
        unselectedItemColor: textTertiary,
      ),
      dividerColor: cardBorder,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardDark,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ── Glassmorphism Decoration ──
BoxDecoration glassDecoration({
  double borderRadius = 16,
  Color? borderColor,
  double opacity = 0.06,
}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(borderRadius),
    color: Colors.white.withValues(alpha: opacity),
    border: Border.all(
      color: borderColor ?? Colors.white.withValues(alpha: 0.08),
    ),
  );
}
