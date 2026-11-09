// Copyright 2026 Google. All rights reserved. Use of this source code is
// governed by a BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart';

void main() {
  late HttpServer server;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.transform(WebSocketTransformer()).listen((socket) {
      socket.listen((_) => socket.close());
    });
  });

  tearDown(() => server.close(force: true));

  Future<WipConnection> connect() =>
      WipConnection.connect('ws://localhost:${server.port}');

  test('sendCommand fails when the connection closes before the response',
      () async {
    var connection = await connect();

    await expectLater(
      connection.sendCommand('Browser.close'),
      throwsStateError,
    );
  });

  test('an unawaited sendCommand does not raise when the connection closes',
      () async {
    var connection = await connect();

    unawaited(connection.sendCommand('Browser.close'));
    await connection.onClose.first;
    await pumpEventQueue();
  });
}
