part of wip;

class WipDebugger extends WipDomain {
  final _pausedController =
      new StreamController<DebuggerPausedEvent>.broadcast();
  final _resumedController = new StreamController.broadcast();

  Map<String, WipScript> _scripts = {};

  WipDebugger(WipConnection connection) : super(connection) {
    connection._registerDomain('Debugger', this);

    // TODO:
    //_register('Debugger.breakpointResolved', _breakpointResolved);
    _register('Debugger.globalObjectCleared', _globalObjectCleared);
    _register('Debugger.paused', _paused);
    _register('Debugger.resumed', _resumed);
    //_register('Debugger.scriptFailedToParse', _scriptFailedToParse);
    _register('Debugger.scriptParsed', _scriptParsed);
  }

  Future enable() => _sendCommand('Debugger.enable');
  Future disable() => _sendCommand('Debugger.disable');

  Future<String> getScriptSource(String scriptId) async {
    var resp =
        await _sendCommand('Debugger.getScriptSource', {'scriptId': scriptId});
    return resp.result['scriptSource'];
  }

  Future pause() => _sendCommand('Debugger.pause');
  Future resume() => _sendCommand('Debugger.resume');

  Future stepInto() => _sendCommand('Debugger.stepInto');
  Future stepOut() => _sendCommand('Debugger.stepOut');
  Future stepOver() => _sendCommand('Debugger.stepOver');

  /**
   * State should be one of "all", "none", or "uncaught".
   */
  Future setPauseOnExceptions(String state) =>
      _sendCommand('Debugger.setPauseOnExceptions', {'state': state});

  Stream get onPaused => _pausedController.stream;
  Stream get onResumed => _resumedController.stream;

  WipScript getScript(String scriptId) => _scripts[scriptId];

  void _globalObjectCleared(WipEvent event) {
    _scripts.clear();
  }

  void _paused(WipEvent event) {
    _pausedController.add(new DebuggerPausedEvent(event));
  }

  void _resumed(WipEvent event) {
    _resumedController.add(null);
  }

  void _scriptParsed(WipEvent event) {
    var script = new WipScript(event.params);
    _scripts[script.scriptId] = script;
    print(script);
  }

  @override
  void close() {
    _pausedController.close();
    _resumedController.close();
  }
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
