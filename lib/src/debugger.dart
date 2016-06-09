// Copyright 2015 Google. All rights reserved. Use of this source code is
// governed by a BSD-style license that can be found in the LICENSE file.

part of wip;

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

  Future enable() => _sendCommand('Debugger.enable');
  Future disable() => _sendCommand('Debugger.disable');

  Future<String> getScriptSource(String scriptId) async =>
      (await _sendCommand('Debugger.getScriptSource', {'scriptId': scriptId}))
          .result['scriptSource'];

  Future pause() => _sendCommand('Debugger.pause');
  Future resume() => _sendCommand('Debugger.resume');

  Future stepInto() => _sendCommand('Debugger.stepInto');
  Future stepOut() => _sendCommand('Debugger.stepOut');
  Future stepOver() => _sendCommand('Debugger.stepOver');

  Future setPauseOnExceptions(PauseState state) => _sendCommand(
      'Debugger.setPauseOnExceptions', {'state': _pauseStateToString(state)});

  Stream<DebuggerPausedEvent> get onPaused => _eventStream(
      'Debugger.paused', (WipEvent event) => new DebuggerPausedEvent(event));
  Stream<GlobalObjectClearedEvent> get onGlobalObjectCleared => _eventStream(
      'Debugger.globalObjectCleared',
      (WipEvent event) => new GlobalObjectClearedEvent(event));
  Stream<DebuggerResumedEvent> get onResumed => _eventStream(
      'Debugger.resumed', (WipEvent event) => new DebuggerResumedEvent(event));
  Stream<ScriptParsedEvent> get onScriptParsed => _eventStream(
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

class ScriptParsedEvent extends _WrappedWipEvent {
  final WipScript script;

  ScriptParsedEvent(WipEvent event)
      : this.script = new WipScript(event.params),
        super(event);
}

class GlobalObjectClearedEvent extends _WrappedWipEvent {
  GlobalObjectClearedEvent(WipEvent event) : super(event);
}

class DebuggerResumedEvent extends _WrappedWipEvent {
  DebuggerResumedEvent(WipEvent event) : super(event);
}

class DebuggerPausedEvent extends _WrappedWipEvent {
  DebuggerPausedEvent(WipEvent event) : super(event);

  String get reason => params['reason'];
  Object get data => params['data'];

  Iterable<WipCallFrame> getCallFrames() =>
      params['callFrames'].map((frame) => new WipCallFrame(frame));

  String toString() => 'paused: ${reason}';
}

class WipCallFrame {
  final Map<String, dynamic> _map;

  WipCallFrame(this._map);

  String get callFrameId => _map['callFrameId'];
  String get functionName => _map['functionName'];
  WipLocation get location => new WipLocation(_map['location']);
  WipRemoteObject get thisObject => new WipRemoteObject(_map['this']);

  Iterable<WipScope> getScopeChain() =>
      _map['scopeChain'].map((scope) => new WipScope(scope));

  String toString() => '[${functionName}]';
}

class WipLocation {
  final Map<String, dynamic> _map;

  WipLocation(this._map);

  int get columnNumber => _map['columnNumber'];
  int get lineNumber => _map['lineNumber'];
  String get scriptId => _map['scriptId'];

  String toString() => '[${scriptId}:${lineNumber}:${columnNumber}]';
}

class WipRemoteObject {
  final Map<String, dynamic> _map;

  WipRemoteObject(this._map);

  String get className => _map['className'];
  String get description => _map['description'];
  String get objectId => _map['objectId'];
  String get subtype => _map['subtype'];
  String get type => _map['type'];
  Object get value => _map['value'];
}

class WipScript {
  final Map<String, dynamic> _map;

  WipScript(this._map);

  String get scriptId => _map['scriptId'];
  String get url => _map['url'];
  int get startLine => _map['startLine'];
  int get startColumn => _map['startColumn'];
  int get endLine => _map['endLine'];
  int get endColumn => _map['endColumn'];
  bool get isContentScript => _map['isContentScript'];
  String get sourceMapURL => _map['sourceMapURL'];

  String toString() => '[script ${scriptId}: ${url}]';
}

class WipScope {
  final Map<String, dynamic> _map;

  WipScope(this._map);

  // "catch", "closure", "global", "local", "with"
  String get scope => _map['scope'];

  /**
   * Object representing the scope. For global and with scopes it represents the
   * actual object; for the rest of the scopes, it is artificial transient
   * object enumerating scope variables as its properties.
   */
  WipRemoteObject get object => new WipRemoteObject(_map['object']);
}
