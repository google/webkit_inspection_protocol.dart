// Copyright 2026 Google. All rights reserved. Use of this source code is
// governed by a BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:webkit_inspection_protocol/dom_model.dart';
import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart';

void main() {
  group('WipDomModel over loopback WebSocket', () {
    late HttpServer server;
    late WebSocket serverSocket;
    late WipConnection connection;
    late WipDomModel dom;
    final receivedCommands = <Map<String, dynamic>>[];

    setUp(() async {
      receivedCommands.clear();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      final serverSocketReady = Completer<WebSocket>();
      server.transform(WebSocketTransformer()).listen((ws) {
        serverSocket = ws;
        serverSocketReady.complete(ws);
        ws.listen((raw) {
          final request = jsonDecode(raw as String) as Map<String, dynamic>;
          receivedCommands.add(request);
          ws.add(
            jsonEncode({
              'id': request['id'],
              'result': _fakeResultFor(request['method'] as String),
            }),
          );
        });
      });

      connection = await WipConnection.connect(
        'ws://${server.address.address}:${server.port}',
      );
      addTearDown(connection.close);
      await serverSocketReady.future;
      dom = WipDomModel(connection.dom);
    });

    test('forwards WipDom and WipDomain commands and parameters', () async {
      expect(dom.connection, same(connection));

      expect(await dom.getOuterHtml(1), '<div>hello</div>');
      await dom.hideHighlight();
      await dom.highlightNode(
        2,
        borderColor: Rgba(1, 2, 3, 4),
        showInfo: true,
      );
      await dom.highlightRect(10, 20, 30, 40, color: Rgba(5, 6, 7));
      expect(await dom.moveTo(2, 3, insertBeforeNodeId: 4), 42);
      expect(await dom.querySelector(1, '.item'), 7);
      expect(await dom.querySelectorAll(1, '.item'), [7, 8]);
      await dom.removeAttribute(2, 'hidden');
      await dom.removeNode(2);
      await dom.requestChildNodes(1);
      expect(await dom.requestNode('obj-9'), 9);
      expect(
        (await dom.resolveNode(2, objectGroup: 'grp')).objectId,
        'obj-2',
      );
      await dom.setAttributeValue(2, 'role', 'button');
      await dom.setAttributesAsText(2, 'id="x"', name: 'id');
      expect(await dom.setNodeName(2, 'SPAN'), 10);
      await dom.setNodeValue(2, 'updated');
      await dom.setOuterHtml(2, '<span>updated</span>');

      final customResp = await dom.sendCommand(
        'Custom.ping',
        params: {'echo': 123},
      );
      expect(customResp.result, {'pong': true});

      final methods = receivedCommands.map((c) => c['method']).toList();
      expect(methods, [
        'DOM.getOuterHTML',
        'DOM.hideHighlight',
        'DOM.highlightNode',
        'DOM.highlightRect',
        'DOM.moveTo',
        'DOM.querySelector',
        'DOM.querySelectorAll',
        'DOM.removeAttribute',
        'DOM.removeNode',
        'DOM.requestChildNodes',
        'DOM.requestNode',
        'DOM.resolveNode',
        'DOM.setAttributeValue',
        'DOM.setAttributeValue',
        'DOM.setNodeName',
        'DOM.setNodeValue',
        'DOM.setOuterHTML',
        'Custom.ping',
      ]);
      expect(receivedCommands[2]['params'], {
        'nodeId': 2,
        'highlightConfig': {
          'borderColor': {'r': 1, 'g': 2, 'b': 3, 'a': 4},
          'showInfo': true,
        },
      });
      expect(receivedCommands[4]['params'], {
        'nodeId': 2,
        'targetNodeId': 3,
        'insertBeforeNodeId': 4,
      });
    });

    test('forwards eventStream, caches getDocument, and resets on update',
        () async {
      final doc1 = await dom.getDocument();
      final doc2 = await dom.getDocument();
      expect(doc2.nodeId, doc1.nodeId);
      expect(
        receivedCommands.where((c) => c['method'] == 'DOM.getDocument'),
        hasLength(1),
      );

      final customEvents = dom.eventStream<int>(
        'Custom.tick',
        (event) => event.params!['n'] as int,
      );
      final nextTick = expectLater(customEvents, emits(99));
      serverSocket.add(
        jsonEncode({
          'method': 'Custom.tick',
          'params': {'n': 99},
        }),
      );
      await nextTick;

      final updated = expectLater(dom.onDocumentUpdated, emits(anything));
      serverSocket.add(jsonEncode({'method': 'DOM.documentUpdated'}));
      await updated;

      await dom.getDocument();
      expect(
        receivedCommands.where((c) => c['method'] == 'DOM.getDocument'),
        hasLength(2),
      );

      final closed = expectLater(dom.onClosed, emits(connection.dom));
      await serverSocket.close();
      await closed;
    });
  });
}

Map<String, dynamic> _fakeResultFor(String method) => switch (method) {
      'DOM.getDocument' => {
          'root': {
            'nodeId': 1,
            'nodeName': '#document',
            'localName': '',
            'nodeType': 9,
            'nodeValue': '',
          },
        },
      'DOM.getOuterHTML' => {'root': '<div>hello</div>'},
      'DOM.moveTo' => {'nodeId': 42},
      'DOM.querySelector' => {'nodeId': 7},
      'DOM.querySelectorAll' => {
          'nodeIds': [7, 8],
        },
      'DOM.requestNode' => {'nodeId': 9},
      'DOM.resolveNode' => {
          'object': {'type': 'object', 'objectId': 'obj-2'},
        },
      'DOM.setNodeName' => {'nodeId': 10},
      'Custom.ping' => {'pong': true},
      _ => <String, dynamic>{},
    };
