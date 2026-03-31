import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WSService {
  WebSocketChannel? _channel;
  final StreamController<WSMessage> _messageController =
      StreamController<WSMessage>.broadcast();

  Stream<WSMessage> get messages => _messageController.stream;
  bool get isConnected => _channel != null;

  /// Stream solve responses via WebSocket
  Stream<WSMessage> streamSolve(
    String baseUrl,
    String kbName,
    String question,
  ) {
    final wsUrl = baseUrl.replaceFirst('http', 'ws');
    final controller = StreamController<WSMessage>();

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/ws/solve'),
      );

      // Send the question
      _channel!.sink.add(jsonEncode({
        'kb_name': kbName,
        'question': question,
      }));

      // Listen for streamed tokens
      _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data.toString());
            final msg = WSMessage.fromJson(json);
            controller.add(msg);
            _messageController.add(msg);
          } catch (_) {
            // Raw text token
            controller.add(WSMessage(
              type: WSMessageType.token,
              content: data.toString(),
            ));
          }
        },
        onDone: () {
          controller.add(WSMessage(
            type: WSMessageType.done,
            content: '',
          ));
          controller.close();
        },
        onError: (error) {
          controller.addError(error);
          controller.close();
        },
      );
    } catch (e) {
      controller.addError(e);
      controller.close();
    }

    return controller.stream;
  }

  /// Stream research results
  Stream<WSMessage> streamResearch(
    String baseUrl,
    String topic,
    String preset,
  ) {
    final wsUrl = baseUrl.replaceFirst('http', 'ws');
    final controller = StreamController<WSMessage>();

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/ws/research'),
      );

      _channel!.sink.add(jsonEncode({
        'topic': topic,
        'preset': preset,
      }));

      _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data.toString());
            controller.add(WSMessage.fromJson(json));
          } catch (_) {
            controller.add(WSMessage(
              type: WSMessageType.token,
              content: data.toString(),
            ));
          }
        },
        onDone: () {
          controller.add(WSMessage(type: WSMessageType.done, content: ''));
          controller.close();
        },
        onError: (error) {
          controller.addError(error);
          controller.close();
        },
      );
    } catch (e) {
      controller.addError(e);
      controller.close();
    }

    return controller.stream;
  }

  void close() {
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    close();
    _messageController.close();
  }
}

enum WSMessageType { token, citation, status, error, done }

class WSMessage {
  final WSMessageType type;
  final String content;
  final Map<String, dynamic>? metadata;

  WSMessage({
    required this.type,
    required this.content,
    this.metadata,
  });

  factory WSMessage.fromJson(Map<String, dynamic> json) {
    WSMessageType type;
    switch (json['type']?.toString().toLowerCase()) {
      case 'token':
        type = WSMessageType.token;
        break;
      case 'citation':
        type = WSMessageType.citation;
        break;
      case 'status':
        type = WSMessageType.status;
        break;
      case 'error':
        type = WSMessageType.error;
        break;
      case 'done':
        type = WSMessageType.done;
        break;
      default:
        type = WSMessageType.token;
    }

    return WSMessage(
      type: type,
      content: json['content']?.toString() ?? json['data']?.toString() ?? '',
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
