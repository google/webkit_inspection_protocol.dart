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
    WipConsole console; // ignore: deprecated_member_use
    List<ConsoleMessageEvent> events = [];
    var subs = [];

    Future checkMessages(int expectedCount) async {
      // make sure all messages have been delivered
      await new Future.delayed(new Duration(seconds: 1));
      expect(events, hasLength(expectedCount));
      for (int i = 0; i < expectedCount; i++) {
        if (i == 0) {
          // clear adds an empty message
          expect(events[i].text, '');
        } else {
          expect(events[i].text, 'message $i');
        }
      }
    }

    setUp(() async {
      // ignore: deprecated_member_use
      console = (await wipConnection).console;
      await console.clearMessages();
      events.clear();
      subs.add(console.onMessage.listen(events.add));
      subs.add(console.onCleared.listen((_) => events.clear()));
    });

    tearDown(() async {
      await console.clearMessages();
      await console.disable();
      console = null;
      await closeConnection();
      subs.forEach((s) => s.cancel());
      subs.clear();
    });

    test('receives new console messages', () async {
      console.enable();
      await navigateToPage('console_test.html');
      await checkMessages(4);
    });

    test('receives old console messages', () async {
      await navigateToPage('console_test.html');
      await console.enable();
      await checkMessages(4);
    });

    test('does not receive messages if cleared', () async {
      await navigateToPage('console_test.html');
      await console.clearMessages();
      await console.enable();
      await checkMessages(0);
    });

    test('does not receive messages if not enabled', () async {
      await navigateToPage('console_test.html');
      await checkMessages(0);
    });
  });
}
