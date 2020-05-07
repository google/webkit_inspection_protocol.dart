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

  Future<WipResponse> enable() => sendCommand('Debugger.enable');

  Future<WipResponse> disable() => sendCommand('Debugger.disable');

  Future<String> getScriptSource(String scriptId) async =>
      (await sendCommand('Debugger.getScriptSource',
              params: {'scriptId': scriptId}))
          .result['scriptSource'] as String;

  Future<WipResponse> pause() => sendCommand('Debugger.pause');

  Future<WipResponse> resume() => sendCommand('Debugger.resume');

  Future<WipResponse> stepInto() => sendCommand('Debugger.stepInto');

  Future<WipResponse> stepOut() => sendCommand('Debugger.stepOut');

  Future<WipResponse> stepOver() => sendCommand('Debugger.stepOver');

  Future<WipResponse> setPauseOnExceptions(PauseState state) {
    return sendCommand('Debugger.setPauseOnExceptions',
        params: {'state': _pauseStateToString(state)});
  }

  /// Sets JavaScript breakpoint at a given location.
  ///
  /// - `location`: Location to set breakpoint in
  /// - `condition`: Expression to use as a breakpoint condition. When
  ///    specified, debugger will only stop on the breakpoint if this expression
  ///    evaluates to true.
  Future<SetBreakpointResponse> setBreakpoint(
    WipLocation location, {
    String condition,
  }) async {
    Map<String, dynamic> params = {
      'location': location.toJsonMap(),
    };
    if (condition != null) {
      params['condition'] = condition;
    }

    final WipResponse response =
        await sendCommand('Debugger.setBreakpoint', params: params);

    if (response.result.containsKey('exceptionDetails')) {
      throw new ExceptionDetails(
          response.result['exceptionDetails'] as Map<String, dynamic>);
    } else {
      return new SetBreakpointResponse(response.json);
    }
  }

  /// Removes JavaScript breakpoint.
  Future<WipResponse> removeBreakpoint(String breakpointId) {
    return sendCommand('Debugger.removeBreakpoint',
        params: {'breakpointId': breakpointId});
  }

  /// Evaluates expression on a given call frame.
  ///
  /// - `callFrameId`: Call frame identifier to evaluate on
  /// - `expression`: Expression to evaluate
  /// - `returnByValue`: Whether the result is expected to be a JSON object that
  ///   should be sent by value
  Future<RemoteObject> evaluateOnCallFrame(
    String callFrameId,
    String expression, {
    bool returnByValue,
  }) async {
    Map<String, dynamic> params = {
      'callFrameId': callFrameId,
      'expression': expression,
    };
    if (returnByValue != null) {
      params['returnByValue'] = returnByValue;
    }

    final WipResponse response =
        await sendCommand('Debugger.evaluateOnCallFrame', params: params);

    if (response.result.containsKey('exceptionDetails')) {
      throw new ExceptionDetails(
          response.result['exceptionDetails'] as Map<String, dynamic>);
    } else {
      return new RemoteObject(
          response.result['result'] as Map<String, dynamic>);
    }
  }

  /// Returns possible locations for breakpoint. scriptId in start and end range
  /// locations should be the same.
  ///
  /// - `start`: Start of range to search possible breakpoint locations in
  /// - `end`: End of range to search possible breakpoint locations in
  ///   (excluding). When not specified, end of scripts is used as end of range.
  /// - `restrictToFunction`: Only consider locations which are in the same
  ///   (non-nested) function as start.
  Future<List<WipBreakLocation>> getPossibleBreakpoints(
    WipLocation start, {
    WipLocation end,
    bool restrictToFunction,
  }) async {
    Map<String, dynamic> params = {
      'start': start.toJsonMap(),
    };
    if (end != null) {
      params['end'] = end.toJsonMap();
    }
    if (restrictToFunction != null) {
      params['restrictToFunction'] = restrictToFunction;
    }

    final WipResponse response =
        await sendCommand('Debugger.getPossibleBreakpoints', params: params);

    if (response.result.containsKey('exceptionDetails')) {
      throw new ExceptionDetails(
          response.result['exceptionDetails'] as Map<String, dynamic>);
    } else {
      List locations = response.result['locations'];
      return List.from(locations.map((map) => WipBreakLocation(map)));
    }
  }

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

  String toString() => script.toString();
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

  WipLocation.fromValues(String scriptId, int lineNumber, {int columnNumber})
      : _map = {} {
    _map['scriptId'] = scriptId;
    _map['lineNumber'] = lineNumber;
    if (columnNumber != null) {
      _map['columnNumber'] = columnNumber;
    }
  }

  String get scriptId => _map['scriptId'];

  int get lineNumber => _map['lineNumber'];

  int get columnNumber => _map['columnNumber'];

  Map<String, dynamic> toJsonMap() {
    return _map;
  }

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
  String get scope => _map['type'] as String;

  /// Name of the scope, null if unnamed closure or global scope
  String get name => _map['name'] as String;

  /// Object representing the scope. For global and with scopes it represents
  /// the actual object; for the rest of the scopes, it is artificial transient
  /// object enumerating scope variables as its properties.
  WipRemoteObject get object =>
      new WipRemoteObject(_map['object'] as Map<String, dynamic>);
}

class WipBreakLocation extends WipLocation {
  WipBreakLocation(Map<String, dynamic> map) : super(map);

  WipBreakLocation.fromValues(String scriptId, int lineNumber,
      {int columnNumber, String type})
      : super.fromValues(scriptId, lineNumber, columnNumber: columnNumber) {
    if (type != null) {
      _map['type'] = type;
    }
  }

  /// Allowed Values: `debuggerStatement`, `call`, `return`.
  String get type => _map['type'];
}

/// The response from [WipDebugger.setBreakpoint].
class SetBreakpointResponse extends WipResponse {
  SetBreakpointResponse(Map<String, dynamic> json) : super(json);

  String get breakpointId => result['breakpointId'];

  WipLocation get actualLocation => WipLocation(result['actualLocation']);
}
