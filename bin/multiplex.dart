// Copyright 2015 Google. All rights reserved. Use of this source code is
// governed by a BSD-style license that can be found in the LICENSE file.

library wip.multiplex;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:io' show HttpClientResponse, HttpServer, InternetAddress, stderr;

import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart' as ws;
import 'package:webkit_inspection_protocol/forwarder.dart';
import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart';

main(List<String> argv) async {
  var args = (new ArgParser()
    ..addFlag('verbose', abbr: 'v', defaultsTo: false, negatable: false)
    ..addOption('chrome_host', defaultsTo: 'localhost')
    ..addOption('chrome_port', defaultsTo: '9222')
    ..addOption('listen_port', defaultsTo: '9223')).parse(argv);

  hierarchicalLoggingEnabled = true;

  if (args['verbose']) {
    Logger.root.level = Level.ALL;
  } else {
    Logger.root.level = Level.WARNING;
  }

  Logger.root.onRecord.listen((LogRecord rec) {
    stderr.writeln('${rec.level.name}: ${rec.time}: ${rec.message}');
  });

  var cr =
      new ChromeConnection(args['chrome_host'], int.parse(args['chrome_port']));
  new Server(int.parse(args['listen_port']), cr);
}

class Server {
  static final _log = new Logger('Server');

  Future<HttpServer> _server;
  final ChromeConnection chrome;
  final int port;

  final _connections = <String, Future<WipConnection>>{};

  Server(this.port, this.chrome) {
    _server = io.serve(_handler, InternetAddress.ANY_IP_V4, port);
  }

  shelf.Handler get _handler => const shelf.Pipeline()
      .addMiddleware(shelf.logRequests(logger: _shelfLogger))
      .addHandler(new shelf.Cascade()
          .add(_webSocket)
          .add(_mainPage)
          .add(_json)
          .add(_forward).handler);

  void _shelfLogger(String msg, bool isError) {
    if (isError) {
      _log.severe(msg);
    } else {
      _log.info(msg);
    }
  }

  Future<shelf.Response> _mainPage(shelf.Request request) async {
    var path = request.url.pathSegments;
    if (path.isEmpty) {
      var resp = await _mainPageHtml();
      _log.info('mainPage: $resp');
      return new shelf.Response.ok(resp,
          headers: {'Content-Type': 'text/html'});
    }
    return new shelf.Response.notFound(null);
  }

  Future<String> _mainPageHtml() async {
    var html = new StringBuffer(r'''<!DOCTYPE html>
<html>
<head>
<title>Chrome Windows</title>
</head>
<body>
<table>
<thead>
<tr><td>Title</td><td>Description</td></tr>
</thead>
<tbody>''');

    for (var tab in await chrome.getTabs()) {
      html
        ..write('<tr><td><a href="/devtools/devtools.html?ws=localhost:')
        ..write(port)
        ..write('/devtools/page/')
        ..write(tab.id)
        ..write('">');
      if (tab.title != null && tab.title.isNotEmpty) {
        html.write(tab.title);
      } else {
        html.write(tab.url);
      }
      html
        ..write('</a></td><td>')
        ..write(tab.description)
        ..write('</td></tr>');
    }
    html.write(r'''</tbody>
</table>
</body>
</html>''');
    return html.toString();
  }

  Future<shelf.Response> _json(shelf.Request request) async {
    var path = request.url.pathSegments;
    if (path.length == 1 && path[0] == 'json') {
      var resp = JSON.encode(await chrome.getTabs(), toEncodable: _jsonEncode);
      _log.info('json: $resp');
      return new shelf.Response.ok(resp,
          headers: {'Content-Type': 'application/json'});
    }
    return new shelf.Response.notFound(null);
  }

  Future<shelf.Response> _forward(shelf.Request request) async {
    _log.info('forwarding: ${request.url}');
    var dtResp = await chrome.getUrl(request.url.path);
    if (dtResp.statusCode == 200) {
      return new shelf.Response.ok(dtResp,
          headers: {'Content-Type': dtResp.headers.contentType.toString()});
    }
    _log.warning(
        'Forwarded ${request.url} returned statusCode: ${dtResp.statusCode}');
    return new shelf.Response.notFound(null);
  }

  Future<shelf.Response> _webSocket(shelf.Request request) async {
    var path = request.url.pathSegments;
    if (path.length != 3 || path[0] != 'devtools' || path[1] != 'page') {
      return new shelf.Response.notFound(null);
    }
    _log.info('connecting to websocket: ${request.url}');

    return ws.webSocketHandler((ws) async {
      var debugger = await _connections.putIfAbsent(path[2], () async {
        var tab = await chrome.getTab((tab) => tab.id == path[2]);
        return WipConnection.connect(tab.webSocketDebuggerUrl);
      });
      var forwarder = new ChromeForwarder(debugger, ws);
      debugger.onClose.listen((_) {
        _connections.remove(path[2]);
        forwarder.stop();
      });
    })(request);
  }

  Future close() async {
    if (_server != null) {
      await (await _server).close(force: true);
      _server = null;
    }
  }

  _jsonEncode(obj) {
    if (obj is ChromeTab) {
      var json = <String, dynamic>{
        'description': obj.description,
        'devtoolsFrontendUrl':
            '/devtools/devtools.html?ws=localhost:$port/devtools/page/${obj.id}',
        'id': obj.id,
        'title': obj.title,
        'type': obj.type,
        'url': obj.url,
        'webSocketDebuggerUrl': 'ws://localhost:$port/devtools/page/${obj.id}'
      };
      if (obj.faviconUrl != null) {
        json['faviconUrl'] = obj.faviconUrl;
      }
      return json;
    } else if (obj is Uri) {
      return obj.toString();
    } else {
      throw new ArgumentError('Cannot encode $obj');
    }
  }
}
