library wip.test.setup;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';
import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart';

Future<WipConnection> _wipConnection;

/// Returns a (cached) debugger connection to the first regular tab of
/// the browser with remote debugger running at 'localhost:9222',
Future<WipConnection> get wipConnection {
  if (_wipConnection == null) {
    _wipConnection = () async {
      var chrome = new ChromeConnection('localhost');
      var tab = await chrome
          .getTab((tab) => !tab.isBackgroundPage && !tab.isChromeExtension);
      var connection = await tab.connect();
      connection.onClose.listen((_) => _wipConnection = null);
      return connection;
    }();
  }
  return _wipConnection;
}

var _testServerUri;

/// Ensures that an HTTP server serving files from 'test/data' has been
/// started and navigates to to [page] using [wipConnection].
/// Return [wipConnection].
Future<WipConnection> navigateToPage(String page) async {
  if (_testServerUri == null) {
    _testServerUri = () async {
      var receivePort = new ReceivePort();
      await Isolate.spawn(_startHttpServer, receivePort.sendPort);
      var port = await receivePort.first;
      return new Uri.http('localhost:$port', '');
    }();
  }
  await (await wipConnection)
      .page
      .navigate((await _testServerUri).resolve(page).toString());
  await new Future.delayed(new Duration(seconds: 1));
  return wipConnection;
}

Future _startHttpServer(SendPort sendPort) async {
  var handler = createStaticHandler('test/data');
  var server = await io.serve(handler, InternetAddress.anyIPv4, 0);
  sendPort.send(server.port);
}

Future closeConnection() async {
  if (_wipConnection != null) {
    await (await navigateToPage('chrome://about')).close();
    _wipConnection = null;
  }
}
