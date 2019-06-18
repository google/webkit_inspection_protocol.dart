// Copyright 2015 Google. All rights reserved. Use of this source code is
// governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import '../webkit_inspection_protocol.dart';

class WipRuntime extends WipDomain {
  WipRuntime(WipConnection connection) : super(connection);

  Future enable() => sendCommand('Runtime.enable');

  Future disable() => sendCommand('Runtime.disable');

  /// Evaluates expression on global object.
  Future<RemoteObject> evaluate(String expression) async {
    final WipResponse response = await sendCommand('Runtime.evaluate', params: {
      'expression': expression,
    });

    if (response.result.containsKey('exceptionDetails')) {
      throw new ExceptionDetails(
          response.result['exceptionDetails'] as Map<String, dynamic>);
    } else {
      return new RemoteObject(
          response.result['result'] as Map<String, dynamic>);
    }
  }

  /// Calls function with given declaration on the given object. Object group of
  /// the result is inherited from the target object.
  Future<RemoteObject> callFunctionOn(
    String functionDeclaration, {
    String objectId,
    int executionContextId,
    List<dynamic> arguments,
  }) async {
    Map<String, dynamic> params = {
      'functionDeclaration': functionDeclaration,
    };

    if (objectId != null) {
      params['objectId'] = objectId;
    }

    if (executionContextId != null) {
      params['executionContextId'] = executionContextId;
    }

    if (objectId != null) {
      // Convert to a ist of CallArguments.
      params['arguments'] = arguments.map((dynamic value) {
        return {'value': value};
      }).toList();
    }

    final WipResponse response =
        await sendCommand('Runtime.callFunctionOn', params: params);

    if (response.result.containsKey('exceptionDetails')) {
      throw new ExceptionDetails(
          response.result['exceptionDetails'] as Map<String, dynamic>);
    } else {
      return new RemoteObject(
          response.result['result'] as Map<String, dynamic>);
    }
  }

  Stream<ConsoleAPIEvent> get onConsoleAPICalled => eventStream(
      'Runtime.consoleAPICalled',
      (WipEvent event) => new ConsoleAPIEvent(event));

  Stream<ExceptionThrownEvent> get onExceptionThrown => eventStream(
      'Runtime.exceptionThrown',
      (WipEvent event) => new ExceptionThrownEvent(event));
}

class ConsoleAPIEvent extends WrappedWipEvent {
  ConsoleAPIEvent(WipEvent event) : super(event);

  /// Type of the call. Allowed values: log, debug, info, error, warning, dir,
  /// dirxml, table, trace, clear, startGroup, startGroupCollapsed, endGroup,
  /// assert, profile, profileEnd.
  String get type => params['type'] as String;

  // Call timestamp.
  num get timestamp => params['timestamp'] as num;

  /// Call arguments.
  List<RemoteObject> get args => (params['args'] as List)
      .map((m) => new RemoteObject(m as Map<String, dynamic>))
      .toList();

// TODO: stackTrace, StackTrace, Stack trace captured when the call was made.
}

class ExceptionThrownEvent extends WrappedWipEvent {
  ExceptionThrownEvent(WipEvent event) : super(event);

  /// Timestamp of the exception.
  int get timestamp => params['timestamp'] as int;

  ExceptionDetails get exceptionDetails =>
      new ExceptionDetails(params['exceptionDetails'] as Map<String, dynamic>);
}

class ExceptionDetails {
  final Map<String, dynamic> _map;

  ExceptionDetails(this._map);

  /// Exception id.
  int get exceptionId => _map['exceptionId'] as int;

  /// Exception text, which should be used together with exception object when
  /// available.
  String get text => _map['text'] as String;

  /// Line number of the exception location (0-based).
  int get lineNumber => _map['lineNumber'] as int;

  /// Column number of the exception location (0-based).
  int get columnNumber => _map['columnNumber'] as int;

  /// URL of the exception location, to be used when the script was not
  /// reported.
  @optional
  String get url => _map['url'] as String;

  /// Script ID of the exception location.
  @optional
  String get scriptId => _map['scriptId'] as String;

  /// JavaScript stack trace if available.
  @optional
  StackTrace get stackTrace => _map['stackTrace'] == null
      ? null
      : new StackTrace(_map['stackTrace'] as Map<String, dynamic>);

  /// Exception object if available.
  @optional
  RemoteObject get exception => _map['exception'] == null
      ? null
      : new RemoteObject(_map['exception'] as Map<String, dynamic>);

  String toString() => '$text, $url, $scriptId, $lineNumber, $exception';
}

class StackTrace {
  final Map<String, dynamic> _map;

  StackTrace(this._map);

  /// String label of this stack trace. For async traces this may be a name of
  /// the function that initiated the async call.
  @optional
  String get description => _map['description'] as String;

  List<CallFrame> get callFrames => (_map['callFrames'] as List)
      .map((m) => new CallFrame(m as Map<String, dynamic>))
      .toList();

  // TODO: parent, StackTrace, Asynchronous JavaScript stack trace that preceded
  // this stack, if available.

  List<String> printFrames() {
    List<CallFrame> frames = callFrames;

    int width = frames.fold(0, (int val, CallFrame frame) {
      return max(val, frame.functionName.length);
    });

    return frames.map((CallFrame frame) {
      return '${frame.functionName}()'.padRight(width + 2) +
          ' ${frame.url} ${frame.lineNumber}:${frame.columnNumber}';
    }).toList();
  }

  String toString() => callFrames.map((f) => '  $f').join('\n');
}

class CallFrame {
  final Map<String, dynamic> _map;

  CallFrame(this._map);

  /// JavaScript function name.
  String get functionName => _map['functionName'] as String;

  /// JavaScript script id.
  String get scriptId => _map['scriptId'] as String;

  /// JavaScript script name or url.
  String get url => _map['url'] as String;

  /// JavaScript script line number (0-based).
  int get lineNumber => _map['lineNumber'] as int;

  /// JavaScript script column number (0-based).
  int get columnNumber => _map['columnNumber'] as int;

  String toString() => '$functionName() ($url $lineNumber:$columnNumber)';
}

/// Mirror object referencing original JavaScript object.
class RemoteObject {
  final Map<String, dynamic> _map;

  RemoteObject(this._map);

  /// Object type.object, function, undefined, string, number, boolean, symbol,
  /// bigint.
  String get type => _map['type'] as String;

  /// Remote object value in case of primitive values or JSON values (if it was
  /// requested). (optional)
  Object get value => _map['value'];

  /// String representation of the object. (optional)
  String get description => _map['description'] as String;

  /// Unique object identifier (for non-primitive values). (optional)
  String get objectId => _map['objectId'] as String;

  String toString() => '$type $value';
}
