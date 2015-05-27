// Copyright 2015 Google. All rights reserved. Use of this source code is
// governed by a BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library wip.console_test;

import 'dart:async';

import 'package:test/test.dart';
import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart';

import 'test_setup.dart';

main() {

  group('WipConsole', () {
    WipConsole console;

    setUp(() async {
      console = (await wipConnection).console;
      await console.clearMessages();
    });

    tearDown(() async {
      await console.clearMessages();
      await console.disable();
      console = null;
    });

    test('receives new console messages', () async {
      var testStream = console.onMessage.take(3);

      await console.enable();
      await navigateToPage('console_test.html');

      checkMessages(await testStream.toList());
    });

    test('receives old console messages', () async {
      var testStream = console.onMessage.take(3);

      await navigateToPage('console_test.html');
      // give enough time that the messages are logged
      await new Future.delayed(const Duration(seconds: 1));

      await console.enable();
      checkMessages(await testStream.toList());
    }, skip: 'TODO(DrMarcII): not receiving previous messages as documented');

    // TODO(DrMarcII): this test is not testing what it should because devtools
    // is not sending previous messages as documented.
    test('does not receive messages if cleared', () async {
      await navigateToPage('console_test.html');
      // give enough time that the messages are logged
      await new Future.delayed(const Duration(seconds: 1));

      await console.clearMessages();
      await console.enable();

      var messagesReceived = 0;
      var sub = console.onMessage.listen((_) => messagesReceived++);

      // give enough time that the messages should have been received
      await new Future.delayed(const Duration(seconds: 1));
      sub.cancel();

      expect(messagesReceived, 0);
    });

    test('does not receive messages if not enabled', () async {
      var testStream = console.onMessage.take(3);

      var messagesReceived = 0;
      var sub = console.onMessage.listen((_) => messagesReceived++);

      await navigateToPage('console_test.html');

      // give enough time that the messages should have been received
      await new Future.delayed(const Duration(seconds: 1));
      sub.cancel();

      expect(messagesReceived, 0);

      await console.enable();
      checkMessages(await testStream.toList());
    }, skip: 'TODO(DrMarcII): not receiving previous messages as documented');
  });
}

void checkMessages(List<ConsoleMessageEvent> results) {
  expect(results, hasLength(3));
  expect(results[0].repeatCount, 1);
  expect(results[0].text, 'message 1');
  expect(results[1].repeatCount, 1);
  expect(results[1].text, 'message 2');
  expect(results[2].repeatCount, 1);
  expect(results[2].text, 'message 3');
}
