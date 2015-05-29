// Copyright 2015 Google. All rights reserved. Use of this source code is
// governed by a BSD-style license that can be found in the LICENSE file.

part of wip;

class WipPage extends WipDomain {
  WipPage(WipConnection connection) : super(connection);

  Future enable() => _sendCommand('Page.enable');
  Future disable() => _sendCommand('Page.disable');

  Future navigate(String url) => _sendCommand('Page.navigate', {'url': url});

  Future reload({bool ignoreCache, String scriptToEvaluateOnLoad}) {
    var params = {};

    if (ignoreCache != null) {
      params['ignoreCache'] = ignoreCache;
    }

    if (scriptToEvaluateOnLoad != null) {
      params['scriptToEvaluateOnLoad'] = scriptToEvaluateOnLoad;
    }

    return _sendCommand('Page.navigate', params);
  }
}
