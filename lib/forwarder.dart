// Copyright 2015 Google. All rights reserved. Use of this source code is
// governed by a BSD-style license that can be found in the LICENSE file.

library crmux.forwarder;

import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';

import 'webkit_inspection_protocol.dart';

/// Forwards a [Stream] to a [WipConnection] and events
/// from a [WipConnection] to a [StreamSink].
class ChromeForwarder {
  static final _log = new Logger('ChromeForwarder');

  final Stream _in;
  final StreamSink _out;
  final WipConnection _debugger;

  final _subscriptions = <StreamSubscription>[];

  final _closedController = new StreamController.broadcast();

  factory ChromeForwarder(WipConnection debugger, Stream stream,
      [StreamSink sink]) {
    if (sink == null) {
      sink = stream as StreamSink;
    }
    return new ChromeForwarder._(debugger, stream, sink);
  }

  ChromeForwarder._(this._debugger, this._in, this._out) {
    _subscriptions.add(_in.listen(_onClientDataHandler,
        onError: _onClientErrorHandler, onDone: _onClientDoneHandler));
    _subscriptions.add(_debugger.onNotification.listen(_onDebuggerDataHandler,
        onError: _onDebuggerErrorHandler, onDone: _onDebuggerDoneHandler));
  }

  Future _onClientDataHandler(String data) async {
    var json = JSON.decode(data);
    var response = {'id': json['id']};
    _log.info('Forwarding to debugger: $data');
    try {
      var resp = await _debugger.sendCommand(json['method'], json['params']);
      if (resp.result != null) {
        response['result'] = resp.result;
      }
    } on WipError catch (e) {
      response['error'] = e.error;
    }
    _out.add(JSON.encode(response));
  }

  void _onClientErrorHandler(Object error, StackTrace stackTrace) {
    _log.severe('error from forwarded client', error, stackTrace);
  }

  void _onClientDoneHandler() {
    _log.info('forwarded client closed.');
    stop();
  }

  void _onDebuggerDataHandler(WipEvent event) {
    _log.info('forwarding event: $event');
    var json = {'method': event.method};
    if (event.params != null) {
      json['params'] = event.params;
    }
    _out.add(JSON.encode(json));
  }

  void _onDebuggerErrorHandler(Object error, StackTrace stackTrace) {
    _log.severe('error from debugger', error, stackTrace);
  }

  void _onDebuggerDoneHandler() {
    _log.info('debugger closed');
    stop();
  }

  void pause() {
    assert(_subscriptions.isNotEmpty);
    _log.info('Pausing forwarding');
    _subscriptions.forEach((s) => s.pause());
    _subscriptions.clear();
  }

  void resume() {
    assert(_subscriptions.isNotEmpty);
    _log.info('Resuming forwarding');
    _subscriptions.forEach((s) => s.resume());
    _subscriptions.clear();
  }

  Future stop() {
    assert(_subscriptions.isNotEmpty);
    _log.info('Stopping forwarding');
    _subscriptions.forEach((s) => s.cancel());
    _subscriptions.clear();
    _closedController.add(null);
    return Future.wait([_closedController.close(), _out.close()]);
  }

  Stream get onClosed => _closedController.stream;
}
