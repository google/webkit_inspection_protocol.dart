// Copyright 2015 Google. All rights reserved. Use of this source code is
// governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import '../webkit_inspection_protocol.dart';

/// Implementation of the
/// https://developer.chrome.com/devtools/docs/protocol/1.1/dom
class WipDom extends WipDomain {
  WipDom(WipConnection connection) : super(connection);

  Future<Map<String, String>> getAttributes(int nodeId) async {
    WipResponse resp =
        await sendCommand('DOM.getAttributes', params: {'nodeId': nodeId});
    return _attributeListToMap(resp.result['attributes']);
  }

  Future<Node> getDocument() async =>
      new Node((await sendCommand('DOM.getDocument')).result['root']);

  Future<String> getOuterHtml(int nodeId) async =>
      (await sendCommand('DOM.getOuterHTML', params: {'nodeId': nodeId}))
          .result['root'];

  Future hideHighlight() => sendCommand('DOM.hideHighlight');

  Future highlightNode(int nodeId,
      {Rgba borderColor,
      Rgba contentColor,
      Rgba marginColor,
      Rgba paddingColor,
      bool showInfo}) {
    var params = <String, dynamic>{'nodeId': nodeId, 'highlightConfig': {}};

    if (borderColor != null) {
      params['highlightConfig']['borderColor'] = borderColor;
    }

    if (contentColor != null) {
      params['highlightConfig']['contentColor'] = contentColor;
    }

    if (marginColor != null) {
      params['highlightConfig']['marginColor'] = marginColor;
    }

    if (paddingColor != null) {
      params['highlightConfig']['paddingColor'] = paddingColor;
    }

    if (showInfo != null) {
      params['highlightConfig']['showInfo'] = showInfo;
    }

    return sendCommand('DOM.highlightNode', params: params);
  }

  Future highlightRect(int x, int y, int width, int height,
      {Rgba color, Rgba outlineColor}) {
    var params = <String, dynamic>{
      'x': x,
      'y': y,
      'width': width,
      'height': height
    };

    if (color != null) {
      params['color'] = color;
    }

    if (outlineColor != null) {
      params['outlineColor'] = outlineColor;
    }

    return sendCommand('DOM.highlightRect', params: params);
  }

  Future<int> moveTo(int nodeId, int targetNodeId,
      {int insertBeforeNodeId}) async {
    var params = {'nodeId': nodeId, 'targetNodeId': targetNodeId};

    if (insertBeforeNodeId != null) {
      params['insertBeforeNodeId'] = insertBeforeNodeId;
    }

    var resp = await sendCommand('DOM.moveTo', params: params);
    return resp.result['nodeId'];
  }

  Future<int> querySelector(int nodeId, String selector) async {
    var resp = await sendCommand('DOM.querySelector',
        params: {'nodeId': nodeId, 'selector': selector});
    return resp.result['nodeId'];
  }

  Future<List<int>> querySelectorAll(int nodeId, String selector) async {
    var resp = await sendCommand('DOM.querySelectorAll',
        params: {'nodeId': nodeId, 'selector': selector});
    return resp.result['nodeIds'];
  }

  Future removeAttribute(int nodeId, String name) =>
      sendCommand('DOM.removeAttribute',
          params: {'nodeId': nodeId, 'name': name});

  Future removeNode(int nodeId) =>
      sendCommand('DOM.removeNode', params: {'nodeId': nodeId});

  Future requestChildNodes(int nodeId) =>
      sendCommand('DOM.requestChildNodes', params: {'nodeId': nodeId});

  Future<int> requestNode(String objectId) async {
    var resp =
        await sendCommand('DOM.requestNode', params: {'objectId': objectId});
    return resp.result['nodeId'];
  }

  Future<WipRemoteObject> resolveNode(int nodeId, {String objectGroup}) async {
    var params = <String, dynamic>{'nodeId': nodeId};
    if (objectGroup != null) {
      params['objectGroup'] = objectGroup;
    }

    var resp = await sendCommand('DOM.resolveNode', params: params);
    return new WipRemoteObject(resp.result['object']);
  }

  Future setAttributeValue(int nodeId, String name, String value) =>
      sendCommand('DOM.setAttributeValue',
          params: {'nodeId': nodeId, 'name': name, 'value': value});

  Future setAttributesAsText(int nodeId, String text, {String name}) {
    var params = {'nodeId': nodeId, 'text': text};
    if (name != null) {
      params['name'] = name;
    }
    return sendCommand('DOM.setAttributeValue', params: params);
  }

  Future<int> setNodeName(int nodeId, String name) async {
    var resp = await sendCommand('DOM.setNodeName',
        params: {'nodeId': nodeId, 'name': name});
    return resp.result['nodeId'];
  }

  Future setNodeValue(int nodeId, String value) =>
      sendCommand('DOM.setNodeValue',
          params: {'nodeId': nodeId, 'value': value});

  Future setOuterHtml(int nodeId, String outerHtml) =>
      sendCommand('DOM.setOuterHTML',
          params: {'nodeId': nodeId, 'outerHtml': outerHtml});

  Stream<AttributeModifiedEvent> get onAttributeModified => eventStream(
      'DOM.attributeModified',
      (WipEvent event) => new AttributeModifiedEvent(event));
  Stream<AttributeRemovedEvent> get onAttributeRemoved => eventStream(
      'DOM.attributeRemoved',
      (WipEvent event) => new AttributeRemovedEvent(event));
  Stream<CharacterDataModifiedEvent> get onCharacterDataModified => eventStream(
      'DOM.characterDataModified',
      (WipEvent event) => new CharacterDataModifiedEvent(event));
  Stream<ChildNodeCountUpdatedEvent> get onChildNodeCountUpdated => eventStream(
      'DOM.childNodeCountUpdated',
      (WipEvent event) => new ChildNodeCountUpdatedEvent(event));
  Stream<ChildNodeInsertedEvent> get onChildNodeInserted => eventStream(
      'DOM.childNodeInserted',
      (WipEvent event) => new ChildNodeInsertedEvent(event));
  Stream<ChildNodeRemovedEvent> get onChildNodeRemoved => eventStream(
      'DOM.childNodeRemoved',
      (WipEvent event) => new ChildNodeRemovedEvent(event));
  Stream<DocumentUpdatedEvent> get onDocumentUpdated => eventStream(
      'DOM.documentUpdated',
      (WipEvent event) => new DocumentUpdatedEvent(event));
  Stream<SetChildNodesEvent> get onSetChildNodes => eventStream(
      'DOM.setChildNodes', (WipEvent event) => new SetChildNodesEvent(event));
}

class AttributeModifiedEvent extends WrappedWipEvent {
  AttributeModifiedEvent(WipEvent event) : super(event);

  int get nodeId => params['nodeId'];
  String get name => params['name'];
  String get value => params['value'];
}

class AttributeRemovedEvent extends WrappedWipEvent {
  AttributeRemovedEvent(WipEvent event) : super(event);

  int get nodeId => params['nodeId'];
  String get name => params['name'];
}

class CharacterDataModifiedEvent extends WrappedWipEvent {
  CharacterDataModifiedEvent(WipEvent event) : super(event);

  int get nodeId => params['nodeId'];
  String get characterData => params['characterData'];
}

class ChildNodeCountUpdatedEvent extends WrappedWipEvent {
  ChildNodeCountUpdatedEvent(WipEvent event) : super(event);

  int get nodeId => params['nodeId'];
  int get childNodeCount => params['childNodeCount'];
}

class ChildNodeInsertedEvent extends WrappedWipEvent {
  ChildNodeInsertedEvent(WipEvent event) : super(event);

  int get parentNodeId => params['parentNodeId'];
  int get previousNodeId => params['previousNodeId'];
  Node _node;
  Node get node {
    if (_node == null) {
      _node = new Node(params['node']);
    }
    return _node;
  }
}

class ChildNodeRemovedEvent extends WrappedWipEvent {
  ChildNodeRemovedEvent(WipEvent event) : super(event);

  int get parentNodeId => params['parentNodeId'];
  int get nodeId => params['nodeId'];
}

class DocumentUpdatedEvent extends WrappedWipEvent {
  DocumentUpdatedEvent(WipEvent event) : super(event);
}

class SetChildNodesEvent extends WrappedWipEvent {
  SetChildNodesEvent(WipEvent event) : super(event);

  int get nodeId => params['parentId'];
  Iterable<Node> get nodes sync* {
    for (Map node in params['nodes']) {
      yield new Node(node);
    }
  }

  String toString() => 'SetChildNodes $nodeId: $nodes';
}

/// The backend keeps track of which DOM nodes have been sent,
/// will only send each node once, and will only send events
/// for nodes that have been sent.
class Node {
  final Map<String, dynamic> _map;

  Node(this._map);

  var _attributes;
  Map<String, String> get attributes {
    if (_attributes == null && _map.containsKey('attributes')) {
      _attributes = _attributeListToMap(_map['attributes']);
    }
    return _attributes;
  }

  int get childNodeCount => _map['childNodeCount'];

  var _children;
  List<Node> get children {
    if (_children == null && _map.containsKey('children')) {
      _children =
          new UnmodifiableListView(_map['children'].map((c) => new Node(c)));
    }
    return _children;
  }

  Node get contentDocument {
    if (_map.containsKey('contentDocument')) {
      return new Node(_map['contentDocument']);
    }
    return null;
  }

  String get documentUrl => _map['documentURL'];

  String get internalSubset => _map['internalSubset'];

  String get localName => _map['localName'];

  String get name => _map['name'];

  int get nodeId => _map['nodeId'];

  String get nodeName => _map['nodeName'];

  int get nodeType => _map['nodeType'];

  String get nodeValue => _map['nodeValue'];

  String get publicId => _map['publicId'];

  String get systemId => _map['systemId'];

  String get value => _map['value'];

  String get xmlVersion => _map['xmlVersion'];

  String toString() => '$nodeName: $nodeId $attributes';
}

class Rgba {
  final int a;
  final int b;
  final int r;
  final int g;

  Rgba(this.r, this.g, this.b, [this.a]);

  Map toJson() {
    var json = {'r': r, 'g': g, 'b': b};
    if (a != null) {
      json['a'] = a;
    }
    return json;
  }
}

Map<String, String> _attributeListToMap(List<String> attrList) {
  var attributes = {};
  for (int i = 0; i < attrList.length; i += 2) {
    attributes[attrList[i]] = attrList[i + 1];
  }
  return new UnmodifiableMapView(attributes);
}
