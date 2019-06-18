// Copyright 2015 Google. All rights reserved. Use of this source code is
// governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import '../webkit_inspection_protocol.dart';

@Deprecated('This domain is deprecated - use Runtime or Log instead')
class WipConsole extends WipDomain {
  WipConsole(WipConnection connection) : super(connection);

  Future enable() => sendCommand('Console.enable');
  Future disable() => sendCommand('Console.disable');
  Future clearMessages() => sendCommand('Console.clearMessages');

  Stream<ConsoleMessageEvent> get onMessage => eventStream(
      'Console.messageAdded',
      (WipEvent event) => new ConsoleMessageEvent(event));
  Stream<ConsoleClearedEvent> get onCleared => eventStream(
      'Console.messagesCleared',
      (WipEvent event) => new ConsoleClearedEvent(event));
}

class ConsoleMessageEvent extends WrappedWipEvent {
  ConsoleMessageEvent(WipEvent event) : super(event);

  Map get _message => params['message'] as Map;

  String get text => _message['text'] as String;
  String get level => _message['level'] as String;
  String get url => _message['url'] as String;

  Iterable<WipConsoleCallFrame> getStackTrace() {
    if (_message.containsKey('stackTrace')) {
      return (params['stackTrace'] as List).map((frame) =>
          new WipConsoleCallFrame.fromMap(frame as Map<String, dynamic>));
    } else {
      return [];
    }
  }

  String toString() => text;
}

class ConsoleClearedEvent extends WrappedWipEvent {
  ConsoleClearedEvent(WipEvent event) : super(event);
}

class WipConsoleCallFrame {
  final Map<String, dynamic> _map;

  WipConsoleCallFrame.fromMap(this._map);

  int get columnNumber => _map['columnNumber'] as int;
  String get functionName => _map['functionName'] as String;
  int get lineNumber => _map['lineNumber'] as int;
  String get scriptId => _map['scriptId'] as String;
  String get url => _map['url'] as String;
}
