// Copyright 2015 Google. All rights reserved. Use of this source code is
// governed by a BSD-style license that can be found in the LICENSE file.

part of wip;

class WipConsole extends WipDomain {
  WipConsole(WipConnection connection) : super(connection);

  Future enable() => _sendCommand('Console.enable');
  Future disable() => _sendCommand('Console.disable');
  Future clearMessages() => _sendCommand('Console.clearMessages');

  Stream<ConsoleMessageEvent> get onMessage => _eventStream(
      'Console.messageAdded',
      (WipEvent event) => new ConsoleMessageEvent(event));
  Stream<ConsoleClearedEvent> get onCleared => _eventStream(
      'Console.messagesCleared',
      (WipEvent event) => new ConsoleClearedEvent(event));
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
  int get repeatCount => _message.putIfAbsent('repeatCount', () => 1);

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

class ConsoleClearedEvent extends _WrappedWipEvent {
  ConsoleClearedEvent(WipEvent event) : super(event);
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
