// Copyright 2015 Google. All rights reserved. Use of this source code is
// governed by a BSD-style license that can be found in the LICENSE file.

/**
 * A library to connect to a Webkit Inspection Protocol server (like Chrome).
 */
library wip;

import 'dart:async'
    show
        Completer,
        EventSink,
        Future,
        Stream,
        StreamController,
        StreamTransformer;
import 'dart:collection' show UnmodifiableListView, UnmodifiableMapView;
import 'dart:convert' show JSON, UTF8;
import 'dart:io' show HttpClient, HttpClientResponse, WebSocket;

import 'package:logging/logging.dart' show Logger;

import 'package:logging/logging.dart';

part 'src/console.dart';
part 'src/debugger.dart';
part 'src/dom.dart';
part 'src/page.dart';

/**
 * A class to connect to a Chrome instance and reflect on its available tabs.
 *
 * This assumes the browser has been started with the `--remote-debugging-port`
 * flag. The data is read from the `http://{host}:{port}/json` url.
 */
class ChromeConnection {
  final HttpClient _client = new HttpClient();

  final Uri url;

  ChromeConnection(String host, [int port = 9222])
      : url = Uri.parse('http://${host}:${port}/');

  // TODO(DrMarcII): consider changing this to return Stream<ChromeTab>.
  Future<List<ChromeTab>> getTabs() async {
    var response = await getUrl('/json');
    var respBody = await UTF8.decodeStream(response);
    List<Map<String, String>> data = JSON.decode(respBody);
    return data.map((m) => new ChromeTab(m));
  }

  Future<ChromeTab> getTab(bool accept(ChromeTab tab),
      {Duration retryFor}) async {
    var start = new DateTime.now();
    var end = start;
    if (retryFor != null) {
      end = start.add(retryFor);
    }

    while (true) {
      try {
        for (var tab in await getTabs()) {
          if (accept(tab)) {
            return tab;
          }
        }
        if (end.isBefore(new DateTime.now())) {
          return null;
        }
      } catch (e) {
        if (end.isBefore(new DateTime.now())) {
          rethrow;
        }
      }
      await new Future.delayed(new Duration(milliseconds: 25));
    }
  }

  Future<HttpClientResponse> getUrl(String path) async {
    var request = await _client.getUrl(url.resolve(path));
    return await request.close();
  }

  void close() => _client.close(force: true);
}

class ChromeTab {
  final Map _map;

  ChromeTab(this._map);

  String get description => _map['description'];
  String get devtoolsFrontendUrl => _map['devtoolsFrontendUrl'];
  String get faviconUrl => _map['faviconUrl'];

  /// Ex. `E1999E8A-EE27-0450-9900-5BFF4C69CA83`.
  String get id => _map['id'];

  String get title => _map['title'];

  /// Ex. `background_page`, `page`.
  String get type => _map['type'];

  String get url => _map['url'];

  /// Ex. `ws://localhost:1234/devtools/page/4F98236D-4EB0-7C6C-5DD1-AF9B6BE4BC71`.
  String get webSocketDebuggerUrl => _map['webSocketDebuggerUrl'];

  bool get hasIcon => _map.containsKey('faviconUrl');
  bool get isChromeExtension => url.startsWith('chrome-extension://');
  bool get isBackgroundPage => type == 'background_page';

  Future<WipConnection> connect() =>
      WipConnection.connect(webSocketDebuggerUrl);

  String toString() => url;
}

/**
 * A Webkit Inspection Protocol (WIP) connection.
 */
class WipConnection {
  static final _log = new Logger('WipConnection');

  /**
   * The WebSocket URL.
   */
  final String url;

  final WebSocket _ws;

  int _nextId = 0;

  var _console;
  WipConsole get console => _console;
  var _debugger;
  WipDebugger get debugger => _debugger;
  var _dom;
  WipDom get dom => _dom;
  var _page;
  WipPage get page => _page;

  final _completers = <int, Completer<WipResponse>>{};

  final _closeController = new StreamController<WipConnection>.broadcast();
  final _notificationController = new StreamController<WipEvent>.broadcast();

  static Future<WipConnection> connect(String url) {
    return WebSocket.connect(url).then((socket) {
      return new WipConnection._(url, socket);
    });
  }

  WipConnection._(this.url, this._ws) {
    _console = new WipConsole(this);
    _debugger = new WipDebugger(this);
    _dom = new WipDom(this);
    _page = new WipPage(this);

    _ws.listen((data) {
      var json = JSON.decode(data);

      if (json.containsKey('id')) {
        _handleResponse(json);
      } else {
        _handleNotification(json);
      }
    }, onDone: _handleClose);
  }

  Stream<WipConnection> get onClose => _closeController.stream;
  Stream<WipEvent> get onNotification => _notificationController.stream;

  Future close() => _ws.close();

  String toString() => url;

  Future<WipResponse> sendCommand(String method,
      [Map<String, dynamic> params]) {
    _log.finest('Sending command: $method($params)');
    var completer = new Completer<WipResponse>();
    var json = {'id': _nextId++, 'method': method};
    if (params != null) {
      json['params'] = params;
    }
    _completers[json['id']] = completer;
    _ws.add(JSON.encode(json));
    return completer.future;
  }

  void _handleNotification(Map<String, dynamic> json) {
    _log.finest('Received notification: $json');
    _notificationController.add(new WipEvent(json));
  }

  void _handleResponse(Map<String, dynamic> event) {
    var completer = _completers.remove(event['id']);

    if (event.containsKey('error')) {
      _log.info('Received error: $event');
      completer.completeError(new WipError(event));
    } else {
      _log.finest('Received response: $event');
      completer.complete(new WipResponse(event));
    }
  }

  void _handleClose() {
    _closeController.add(this);
    _closeController.close();
    _notificationController.close();
  }
}

class WipEvent {
  final String method;
  final Map<String, dynamic> params;

  WipEvent(Map<String, dynamic> map)
      : method = map['method'],
        params = map['params'];

  String toString() => 'WipEvent: $method($params)';
}

class WipError {
  final int id;
  final dynamic error;

  WipError(Map<String, dynamic> json)
      : id = json['id'],
        error = json['error'];

  String toString() => 'WipError $id: $error';
}

class WipResponse {
  final int id;
  final Map<String, dynamic> result;

  WipResponse(Map<String, dynamic> json)
      : id = json['id'],
        result = json['result'];

  String toString() => 'WipResponse $id: $result';
}

typedef WipEvent WipEventTransformer(WipEvent event);

abstract class WipDomain {
  static final _log = new Logger('WipDomain');

  Map<String, Stream> _eventStreams = {};

  final WipConnection connection;
  var _onClosed;
  Stream<WipDomain> get onClosed => _onClosed;

  WipDomain(WipConnection connection) : this.connection = connection {
    this._onClosed = new StreamTransformer.fromHandlers(
        handleData: (event, EventSink sink) {
      sink.add(this);
    }).bind(connection.onClose);
  }

  Stream<WipEvent> _eventStream(
      String method, WipEventTransformer transformer) => _eventStreams
      .putIfAbsent(method, () => new StreamTransformer.fromHandlers(
          handleData: (WipEvent event, EventSink<WipEvent> sink) {
    if (event.method == method) {
      _log.finest('Transforming $event to $method');
      sink.add(transformer(event));
    }
  }).bind(connection.onNotification));

  Future<WipResponse> _sendCommand(String method,
      [Map<String, dynamic> params]) => connection.sendCommand(method, params);
}

class _WrappedWipEvent implements WipEvent {
  final WipEvent _wrapped;

  _WrappedWipEvent(this._wrapped);

  @override
  String get method => _wrapped.method;

  @override
  Map<String, dynamic> get params => _wrapped.params;
}
