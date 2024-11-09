/// libpttea.websocket_client
/// ----------
///
/// This module provides the WebSocket client for connecting to PTT.
library;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import './utils.dart' as utils;

final Logger logger = Logger('websocket_client');
final Logger loggerMessages = Logger('websocket_client_messages');

class WebSocketClient {
  final String url;
  final String origin;

  WebSocket? _connection;
  bool connected = false;

  final utils.AsyncQueue<List<int>> receiveQueue =
      utils.AsyncQueue<List<int>>();

  WebSocketClient(
      {this.url = 'wss://ws.ptt.cc/bbs/', this.origin = 'https://term.ptt.cc'});

  /// Handler to receive messages from the WebSocket connection.
  void _receiveHandler() {
    _connection?.listen(
      (message) {
        // message is binary data (List<int>)
        receiveQueue.put(message as List<int>);

        if (loggerMessages.level <= Level.INFO) {
          String decodedMessage = utf8.decode(message, allowMalformed: true);
          loggerMessages.info('Receive >>$decodedMessage<<\n');
        }
      },
      onDone: () {
        logger.info('WebSocket ConnectionClosed');
        connected = false;
      },
      onError: (error) {
        // refactor!
        logger.severe('Error receiving message: $error');
        connected = false;
      },
    );
  }

  /// Create connection.
  Future<void> connect() async {
    try {
      _connection = await WebSocket.connect(
        url,
        headers: {'Origin': origin},
      );
      connected = true;
      logger.info('Connected');

      // Start listening to messages
      _receiveHandler();
    } catch (e) {
      // refactor!
      logger.severe('Connection failed: $e');
      connected = false;
    }
  }

  /// Send messages to the WebSocket connection.
  void send(Uint8List message) {
    if (connected && _connection != null) {
      try {
        _connection?.add(message);
        loggerMessages.info('Sent >>$message<<');
      } catch (e) {
        // refactor!
        logger.severe('Error sending message: $e');
      }
    } else {
      throw Exception("Cannot send message, WebSocket is not connected");
    }
  }

  /// Close the WebSocket connection.
  Future<void> close() async {
    if (_connection != null) {
      await _connection?.close();

      connected = false;
      logger.info('Connection closed manually');
    } else {
      logger.warning('WebSocket is not connected');
    }
  }
}
