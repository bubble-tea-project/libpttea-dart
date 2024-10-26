import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:logging/logging.dart';
import './utils.dart';

final Logger logger = Logger('websocket_client');
final Logger loggerMessages = Logger('websocket_client_messages');

class WebSocketClient {
  final String url;
  final String origin;
  WebSocket? _connection;
  final StreamController<List<int>> _receiveController = StreamController<List<int>>();
  final AsyncQueue<List<int>> receiveQueue = AsyncQueue<List<int>>();
  
  final StreamController<Uint8List> _sendController = StreamController<Uint8List>();
  bool connected = false;

  WebSocketClient({this.url = 'wss://ws.ptt.cc/bbs/', this.origin = 'https://term.ptt.cc'});

  Future<void> connect() async {
    try {
      _connection = await WebSocket.connect(
        url,
        headers: {'Origin': origin},
      );
      connected = true;
      logger.info('Connected to WebSocket at $url');

      // Start listening to messages
      _receiveHandler();
      // Start handling outgoing messages
      _sendHandler();
    } catch (e) {
      logger.severe('Connection failed: $e');
      connected = false;
    }
  }

  void _receiveHandler() {
    _connection?.listen(
      (message) {
        // message is binary data (List<int>)
        _receiveController.add(message as List<int>);
        receiveQueue.put(message as List<int>);

        if (loggerMessages.level <= Level.INFO) {
          String decodedMessage = utf8.decode(message, allowMalformed: true);
          loggerMessages.info('Receive >>$decodedMessage<<\n');
        }
    

      },
      onDone: () {
        logger.info('Connection closed by server.');
        connected = false;
      },
      onError: (error) {
        logger.severe('Error receiving message: $error');
        connected = false;
      },
    );
  }

  void _sendHandler() {
    _sendController.stream.listen((message) async {
      if (connected && _connection != null) {
        try {
          _connection?.add(message);
          loggerMessages.info('Sent >>$message<<');
        } catch (e) {
          logger.severe('Error sending message: $e');
        }
      } else {
        logger.warning('Cannot send message, WebSocket is not connected');
      }
    });
  }

  void send(Uint8List message) {
    _sendController.add(message);
  }

  Future<void> close() async {
    if (_connection != null) {
      await _connection?.close();
      _receiveController.close();
      _sendController.close();
      logger.info('Connection closed');
      connected = false;
    } else {
      logger.warning('WebSocket is not connected');
    }
  }

  Stream<List<int>> get messages => _receiveController.stream;
}
