// Copyright 2015 Google. All rights reserved. Use of this source code is
// governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import '../webkit_inspection_protocol.dart';

class WipDebugger extends WipDomain {
  final _scripts = <String, WipScript>{};

  WipDebugger(WipConnection connection) : super(connection) {
    onScriptParsed.listen((event) {
      _scripts[event.script.scriptId] = event.script;
    });
    onGlobalObjectCleared.listen((_) {
      _scripts.clear();
    });
  }

  Future enable() => sendCommand('Debugger.enable');
  Future disable() => sendCommand('Debugger.disable');

  Future<String> getScriptSource(String scriptId) async =>
      (await sendCommand('Debugger.getScriptSource',
              params: {'scriptId': scriptId}))
          .result['scriptSource'] as String;

  Future pause() => sendCommand('Debugger.pause');
  Future resume() => sendCommand('Debugger.resume');

  Future stepInto() => sendCommand('Debugger.stepInto');
  Future stepOut() => sendCommand('Debugger.stepOut');
  Future stepOver() => sendCommand('Debugger.stepOver');

  Future setPauseOnExceptions(PauseState state) =>
      sendCommand('Debugger.setPauseOnExceptions',
          params: {'state': _pauseStateToString(state)});

  Stream<DebuggerPausedEvent> get onPaused => eventStream(
      'Debugger.paused', (WipEvent event) => new DebuggerPausedEvent(event));
  Stream<GlobalObjectClearedEvent> get onGlobalObjectCleared => eventStream(
      'Debugger.globalObjectCleared',
      (WipEvent event) => new GlobalObjectClearedEvent(event));
  Stream<DebuggerResumedEvent> get onResumed => eventStream(
      'Debugger.resumed', (WipEvent event) => new DebuggerResumedEvent(event));
  Stream<ScriptParsedEvent> get onScriptParsed => eventStream(
      'Debugger.scriptParsed',
      (WipEvent event) => new ScriptParsedEvent(event));

  Map<String, WipScript> get scripts => new UnmodifiableMapView(_scripts);
}

String _pauseStateToString(PauseState state) {
  switch (state) {
    case PauseState.all:
      return 'all';
    case PauseState.none:
      return 'none';
    case PauseState.uncaught:
      return 'uncaught';
    default:
      throw new ArgumentError('unknown state: $state');
  }
}

enum PauseState { all, none, uncaught }

class ScriptParsedEvent extends WrappedWipEvent {
  final WipScript script;

  ScriptParsedEvent(WipEvent event)
      : this.script = new WipScript(event.params),
        super(event);
}

class GlobalObjectClearedEvent extends WrappedWipEvent {
  GlobalObjectClearedEvent(WipEvent event) : super(event);
}

class DebuggerResumedEvent extends WrappedWipEvent {
  DebuggerResumedEvent(WipEvent event) : super(event);
}

class DebuggerPausedEvent extends WrappedWipEvent {
  DebuggerPausedEvent(WipEvent event) : super(event);

  String get reason => params['reason'] as String;
  Object get data => params['data'];

  Iterable<WipCallFrame> getCallFrames() => (params['callFrames'] as List)
      .map((frame) => new WipCallFrame(frame as Map<String, dynamic>));

  String toString() => 'paused: ${reason}';
}

class WipCallFrame {
  final Map<String, dynamic> _map;

  WipCallFrame(this._map);

  String get callFrameId => _map['callFrameId'] as String;
  String get functionName => _map['functionName'] as String;
  WipLocation get location =>
      new WipLocation(_map['location'] as Map<String, dynamic>);
  WipRemoteObject get thisObject =>
      new WipRemoteObject(_map['this'] as Map<String, dynamic>);

  Iterable<WipScope> getScopeChain() => (_map['scopeChain'] as List)
      .map((scope) => new WipScope(scope as Map<String, dynamic>));

  String toString() => '[${functionName}]';
}

class WipLocation {
  final Map<String, dynamic> _map;

  WipLocation(this._map);

  int get columnNumber => _map['columnNumber'] as int;
  int get lineNumber => _map['lineNumber'] as int;
  String get scriptId => _map['scriptId'] as String;

  String toString() => '[${scriptId}:${lineNumber}:${columnNumber}]';
}

class WipRemoteObject {
  final Map<String, dynamic> _map;

  WipRemoteObject(this._map);

  String get className => _map['className'] as String;
  String get description => _map['description'] as String;
  String get objectId => _map['objectId'] as String;
  String get subtype => _map['subtype'] as String;
  String get type => _map['type'] as String;
  Object get value => _map['value'];
}

class WipScript {
  final Map<String, dynamic> _map;

  WipScript(this._map);

  String get scriptId => _map['scriptId'] as String;
  String get url => _map['url'] as String;
  int get startLine => _map['startLine'] as int;
  int get startColumn => _map['startColumn'] as int;
  int get endLine => _map['endLine'] as int;
  int get endColumn => _map['endColumn'] as int;
  bool get isContentScript => _map['isContentScript'] as bool;
  String get sourceMapURL => _map['sourceMapURL'] as String;

  String toString() => '[script ${scriptId}: ${url}]';
}

class WipScope {
  final Map<String, dynamic> _map;

  WipScope(this._map);

  // "catch", "closure", "global", "local", "with"
  String get scope => _map['scope'] as String;

  /**
   * Object representing the scope. For global and with scopes it represents the
   * actual object; for the rest of the scopes, it is artificial transient
   * object enumerating scope variables as its properties.
   */
  WipRemoteObject get object =>
      new WipRemoteObject(_map['object'] as Map<String, dynamic>);
}
