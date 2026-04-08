import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class AppTheme {
  // ── Light Color Palette ──
  static const Color primary = Color(0xFFF8F6F2); 
  static const Color surface = Color(0xFFFCFBF9);
  static const Color card = Color(0xFFFCFBF9);
  static const Color cardBorder = Color(0xFFE5E7EB);
  static const Color accentIndigo = Color(0xFF4F46E5);
  static const Color accentViolet = Color(0xFF8B5CF6);
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentOrange = Color(0xFFF97316);
  static const Color accentPink = Color(0xFFEC4899);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textTertiary = Color(0xFF9CA3AF);

  // ── Dark Color Palette ──
  static const Color darkPrimary = Color(0xFF0F0F0F);
  static const Color darkSurface = Color(0xFF1A1A1A);
  static const Color darkCard = Color(0xFF1E1E1E);
  static const Color darkCardBorder = Color(0xFF2E2E2E);
  static const Color darkTextPrimary = Color(0xFFE8E8E8);
  static const Color darkTextSecondary = Color(0xFFA0A0A0);
  static const Color darkTextTertiary = Color(0xFF606060);
  static const Color darkSidebar = Color(0xFF141414);
  static const Color darkSidebarBorder = Color(0xFF252525);

  // ── Reusable Text Styles ──
  static const TextStyle sectionHeaderStyle = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w600,
    color: textPrimary, letterSpacing: -0.3,
  );
  static const TextStyle chipLabelStyle = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w600,
  );
  static const TextStyle hintStyle = TextStyle(
    color: textTertiary, fontSize: 14,
  );
  static const TextStyle bodyStyle = TextStyle(
    color: textPrimary, fontSize: 15, height: 1.6,
  );
  static const TextStyle captionStyle = TextStyle(
    color: textSecondary, fontSize: 12,
  );

  // ── Shared Markdown StyleSheet for light theme ──
  static MarkdownStyleSheet get markdownStyle => MarkdownStyleSheet(
        p: GoogleFonts.inter(color: textPrimary, fontSize: 15, height: 1.6),
        h1: GoogleFonts.inter(color: textPrimary, fontSize: 22, fontWeight: FontWeight.w700, height: 1.4),
        h2: GoogleFonts.inter(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600, height: 1.4),
        h3: GoogleFonts.inter(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
        h4: GoogleFonts.inter(color: textSecondary, fontSize: 15, fontWeight: FontWeight.w600),
        strong: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w700),
        em: GoogleFonts.inter(color: textSecondary, fontStyle: FontStyle.italic),
        a: GoogleFonts.inter(color: accentIndigo, decoration: TextDecoration.underline, decorationColor: accentIndigo),
        code: GoogleFonts.firaCode(color: accentViolet, backgroundColor: const Color(0xFFF3F4F6), fontSize: 13),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cardBorder),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquote: GoogleFonts.inter(color: textSecondary, fontSize: 15, height: 1.6),
        blockquoteDecoration: BoxDecoration(
          color: accentIndigo.withValues(alpha: 0.05),
          borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
          border: const Border(left: BorderSide(color: accentIndigo, width: 3)),
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        listBullet: GoogleFonts.inter(color: textSecondary),
        listIndent: 24,
        horizontalRuleDecoration: const BoxDecoration(border: Border(top: BorderSide(color: cardBorder, width: 1))),
        tableHead: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
        tableBody: GoogleFonts.inter(color: textSecondary, fontSize: 14),
        tableBorder: TableBorder.all(color: cardBorder, width: 1, borderRadius: BorderRadius.circular(8)),
        tableHeadAlign: TextAlign.left,
        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tableColumnWidth: const IntrinsicColumnWidth(),
      );

  // ── Dark Markdown StyleSheet ──
  static MarkdownStyleSheet get darkMarkdownStyle => MarkdownStyleSheet(
        p: GoogleFonts.inter(color: darkTextPrimary, fontSize: 15, height: 1.6),
        h1: GoogleFonts.inter(color: darkTextPrimary, fontSize: 22, fontWeight: FontWeight.w700, height: 1.4),
        h2: GoogleFonts.inter(color: darkTextPrimary, fontSize: 18, fontWeight: FontWeight.w600, height: 1.4),
        h3: GoogleFonts.inter(color: darkTextPrimary, fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
        h4: GoogleFonts.inter(color: darkTextSecondary, fontSize: 15, fontWeight: FontWeight.w600),
        strong: GoogleFonts.inter(color: darkTextPrimary, fontWeight: FontWeight.w700),
        em: GoogleFonts.inter(color: darkTextSecondary, fontStyle: FontStyle.italic),
        a: GoogleFonts.inter(color: const Color(0xFF818CF8), decoration: TextDecoration.underline, decorationColor: const Color(0xFF818CF8)),
        code: GoogleFonts.firaCode(color: const Color(0xFFA78BFA), backgroundColor: const Color(0xFF262626), fontSize: 13),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: darkCardBorder),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquote: GoogleFonts.inter(color: darkTextSecondary, fontSize: 15, height: 1.6),
        blockquoteDecoration: BoxDecoration(
          color: const Color(0xFF818CF8).withValues(alpha: 0.08),
          borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
          border: const Border(left: BorderSide(color: Color(0xFF818CF8), width: 3)),
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        listBullet: GoogleFonts.inter(color: darkTextSecondary),
        listIndent: 24,
        horizontalRuleDecoration: const BoxDecoration(border: Border(top: BorderSide(color: darkCardBorder, width: 1))),
        tableHead: GoogleFonts.inter(color: darkTextPrimary, fontWeight: FontWeight.w700, fontSize: 14),
        tableBody: GoogleFonts.inter(color: darkTextSecondary, fontSize: 14),
        tableBorder: TableBorder.all(color: darkCardBorder, width: 1, borderRadius: BorderRadius.circular(8)),
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
    colors: [Color(0xFFF9FAFB), Color(0xFFF3F4F6)],
  );

  static const LinearGradient shimmerGradient = LinearGradient(
    colors: [Color(0x00FFFFFF), Color(0x80FFFFFF), Color(0x00FFFFFF)],
  );

  // ── Light Theme Data ──
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: primary,
      colorScheme: const ColorScheme.light(
        primary: accentIndigo,
        secondary: accentViolet,
        tertiary: accentCyan,
        surface: surface,
        onSurface: textPrimary,
        onPrimary: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.5),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: textPrimary),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textPrimary),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: textSecondary),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: textSecondary),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
      )),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w600, color: textPrimary),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: cardBorder, width: 1)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cardBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cardBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: accentIndigo, width: 2)),
        hintStyle: const TextStyle(color: textTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentIndigo,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: accentIndigo, foregroundColor: Colors.white),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(backgroundColor: surface, selectedItemColor: accentIndigo, unselectedItemColor: textTertiary),
      dividerColor: cardBorder,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Dark Theme Data ──
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkPrimary,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF818CF8), // lighter indigo for dark
        secondary: Color(0xFFA78BFA),
        tertiary: Color(0xFF22D3EE),
        surface: darkSurface,
        onSurface: darkTextPrimary,
        onPrimary: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: darkTextPrimary, letterSpacing: -0.5),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: darkTextPrimary),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: darkTextPrimary),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: darkTextPrimary),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: darkTextSecondary),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: darkTextSecondary),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: darkTextPrimary),
      )),
      appBarTheme: AppBarTheme(
        backgroundColor: darkPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w600, color: darkTextPrimary),
        iconTheme: const IconThemeData(color: darkTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: darkCardBorder, width: 1)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: darkCardBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: darkCardBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF818CF8), width: 2)),
        hintStyle: const TextStyle(color: darkTextTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF818CF8),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: Color(0xFF818CF8), foregroundColor: Colors.white),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(backgroundColor: darkSurface, selectedItemColor: Color(0xFF818CF8), unselectedItemColor: darkTextTertiary),
      dividerColor: darkCardBorder,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkCardBorder,
        contentTextStyle: const TextStyle(color: Colors.white),
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
  double opacity = 0.05,
}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(borderRadius),
    color: Colors.black.withValues(alpha: opacity),
    border: Border.all(
      color: borderColor ?? Colors.black.withValues(alpha: 0.05),
    ),
  );
}
