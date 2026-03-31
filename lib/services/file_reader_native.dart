import 'dart:io';
import 'dart:typed_data';

/// Native file reading implementation using dart:io
Future<String?> readFileAsString(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) {
      return await file.readAsString();
    }
  } catch (_) {
    // If readAsString fails (binary file), try reading bytes
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      return String.fromCharCodes(bytes);
    } catch (_) {}
  }
  return null;
}

/// Read file as raw bytes
Future<Uint8List?> readFileAsBytes(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
  } catch (_) {}
  return null;
}

/// Write string to file
Future<String?> writeStringToFile(String path, String content) async {
  try {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return file.path;
  } catch (_) {}
  return null;
}

/// Write bytes to file
Future<String?> writeBytesToFile(String path, Uint8List bytes) async {
  try {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file.path;
  } catch (_) {}
  return null;
}
