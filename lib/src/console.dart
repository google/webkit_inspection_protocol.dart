// Copyright 2015 Google. All rights reserved. Use of this source code is
// governed by a BSD-style license that can be found in the LICENSE file.

part of wip;

class WipConsole extends WipDomain {
  final _messageController =
      new StreamController<ConsoleMessageEvent>.broadcast();
  final _clearedController = new StreamController.broadcast();

  ConsoleMessageEvent _lastMessage;

  WipConsole(WipConnection connection) : super(connection) {
    connection._registerDomain('Console', this);

    _register('Console.messageAdded', _messageAdded);
    _register('Console.messageRepeatCountUpdated', _messageRepeatCountUpdated);
    _register('Console.messagesCleared', _messagesCleared);
  }

  Future enable() => _sendCommand('Console.enable');
  Future disable() => _sendCommand('Console.disable');
  Future clearMessages() => _sendCommand('Console.clearMessages');

  Stream<ConsoleMessageEvent> get onMessage => _messageController.stream;
  Stream get onCleared => _clearedController.stream;

  void _messageAdded(WipEvent event) {
    _lastMessage = new ConsoleMessageEvent(event);
    _messageController.add(_lastMessage);
  }

  void _messageRepeatCountUpdated(WipEvent event) {
    if (_lastMessage != null) {
      _lastMessage.params['repeatCount'] = event.params['count'];
      _messageController.add(_lastMessage);
    }
  }

  void _messagesCleared(WipEvent event) {
    _lastMessage = null;
    _clearedController.add(null);
  }

  @override
  void close() {
    _messageController.close();
    _clearedController.close();
  }
}

/**
 * See [WipConsole.onMessage].
 */
class ConsoleMessageEvent extends _WrappedWipEvent {
  ConsoleMessageEvent(WipEvent event) : super(event);

  Map get _message => params['message'];

  String get text => _message['text'];
  String get level => _message['level'];
  String get url => _message['url'];
  int get repeatCount => _message['repeatCount'];

  Iterable<WipConsoleCallFrame> getStackTrace() {
    if (_message.containsKey('stackTrace')) {
      return params['stackTrace']
          .map((frame) => new WipConsoleCallFrame.fromMap(frame));
    } else {
      return [];
    }
  }

  String toString() => text;
}

class WipConsoleCallFrame {
  final Map<String, dynamic> _map;

  WipConsoleCallFrame.fromMap(this._map);

  int get columnNumber => _map['columnNumber'];
  String get functionName => _map['functionName'];
  int get lineNumber => _map['lineNumber'];
  String get scriptId => _map['scriptId'];
  String get url => _map['url'];
}
