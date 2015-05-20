// Copyright 2015 Google. All rights reserved. Use of this source code is
// governed by a BSD-style license that can be found in the LICENSE file.

part of wip;

/// Implementation of the
/// https://developer.chrome.com/devtools/docs/protocol/1.1/dom
class WipDom extends WipDomain {
  WipDom(WipConnection connection) : super(connection) {
    connection._registerDomain('DOM', this);

    _register('DOM.attributeModified', _attributeModified);
    _register('DOM.attributeRemoved', _attributeRemoved);
    _register('DOM.characterDataModified', _characterDataModified);
    _register('DOM.childNodeCountUpdated', _childNodeCountUpdated);
    _register('DOM.childNodeInserted', _childNodeInserted);
    _register('DOM.childNodeRemoved', _childNodeRemoved);
    _register('DOM.documentUpdated', _documentUpdated);
    _register('DOM.setChildNodes', _setChildNodes);
  }

  Future<Map<String, String>> getAttributes(int nodeId) async {
    WipResponse resp =
        await _sendCommand('DOM.getAttributes', {'nodeId': nodeId});
    var attributes = {};
    for (int i = 0; i < resp.result['attributes'].length; i += 2) {
      attributes[resp.result['attributes'][i]] =
          attributes[resp.result['attributes'][i + 1]];
    }
    return new UnmodifiableMapView<String, String>(attributes);
  }

  Future<Node> getDocument() async =>
      new Node((await _sendCommand('DOM.getDocument')).result['root']);

  Future<String> getOuterHtml(int nodeId) async => (await _sendCommand(
      'DOM.getOuterHTML', {'nodeId': nodeId})).result['root'];

  Future hideHighlight() => _sendCommand('DOM.hideHighlight');

  Future highlightNode(int nodeId, {Rgba borderColor, Rgba contentColor,
      Rgba marginColor, Rgba paddingColor, bool showInfo}) {
    var params = {'nodeId': nodeId, 'highlightConfig': {}};

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

    return _sendCommand('DOM.highlightNode', params);
  }

  Future highlightRect(int x, int y, int width, int height,
      {Rgba color, Rgba outlineColor}) {
    var params = {'x': x, 'y': y, 'width': width, 'height': height};

    if (color != null) {
      params['color'] = color;
    }

    if (outlineColor != null) {
      params['outlineColor'] = outlineColor;
    }

    return _sendCommand('DOM.highlightRect', params);
  }

  Future<int> moveTo(int nodeId, int targetNodeId,
      {int insertBeforeNodeId}) async {
    var params = {'nodeId': nodeId, 'targetNodeId': targetNodeId};

    if (insertBeforeNodeId != null) {
      params['insertBeforeNodeId'] = insertBeforeNodeId;
    }

    var resp = await _sendCommand('DOM.moveTo', params);
    return resp.result['nodeId'];
  }

  Future<int> querySelector(int nodeId, String selector) async {
    var resp = await _sendCommand(
        'DOM.querySelector', {'nodeId': nodeId, 'selector': selector});
    return resp.result['nodeId'];
  }

  Future<List<int>> querySelectorAll(int nodeId, String selector) async {
    var resp = await _sendCommand(
        'DOM.querySelectorAll', {'nodeId': nodeId, 'selector': selector});
    return resp.result['nodeIds'];
  }

  Future removeAttribute(int nodeId, String name) =>
      _sendCommand('DOM.removeAttribute', {'nodeId': nodeId, 'name': name});
  Future removeNode(int nodeId) =>
      _sendCommand('DOM.removeNode', {'nodeId': nodeId});
  Future requestChildNodes(int nodeId) =>
      _sendCommand('DOM.requestChildNodes', {'nodeId': nodeId});
  Future<int> requestNode(String objectId) async {
    var resp = await _sendCommand('DOM.requestNode', {'objectId': objectId});
    return resp.result['nodeId'];
  }

  Future<WipRemoteObject> resolveNode(int nodeId, {String objectGroup}) async {
    var params = {'nodeId': nodeId};
    if (objectGroup != null) {
      params['objectGroup'] = objectGroup;
    }

    var resp = await _sendCommand('DOM.resolveNode', params);
    return new WipRemoteObject(resp.result['object']);
  }

  Future setAttributeValue(int nodeId, String name, String value) =>
      _sendCommand('DOM.setAttributeValue', {
    'nodeId': nodeId,
    'name': name,
    'value': value
  });
  Future setAttributesAsText(int nodeId, String text, {String name}) {
    var params = {'nodeId': nodeId, 'text': text};
    if (name != null) {
      params['name'] = name;
    }
    _sendCommand('DOM.setAttributeValue', params);
  }

  Future<int> setNodeName(int nodeId, String name) async {
    var resp =
        await _sendCommand('DOM.setNodeName', {'nodeId': nodeId, 'name': name});
    return resp.result['nodeId'];
  }

  Future setNodeValue(int nodeId, String value) =>
      _sendCommand('DOM.setNodeValue', {'nodeId': nodeId, 'value': value});

  Future setOuterHtml(int nodeId, String outerHtml) => _sendCommand(
      'DOM.setOuterHTML', {'nodeId': nodeId, 'outerHtml': outerHtml});

  final _attributeModifiedController =
      new StreamController<AttributeModifiedEvent>.broadcast();
  Stream<AttributeModifiedEvent> get onAttributeModified =>
      _attributeModifiedController.stream;
  void _attributeModified(WipEvent event) =>
      _attributeModifiedController.add(new AttributeModifiedEvent(event));

  final _attributeRemovedController =
      new StreamController<AttributeRemovedEvent>.broadcast();
  Stream<AttributeRemovedEvent> get onAttributeRemoved =>
      _attributeRemovedController.stream;
  void _attributeRemoved(WipEvent event) =>
      _attributeRemovedController.add(new AttributeRemovedEvent(event));

  final _characterDataModifiedController =
      new StreamController<CharacterDataModifiedEvent>.broadcast();
  Stream<CharacterDataModifiedEvent> get onCharacterDataModified =>
      _characterDataModifiedController.stream;
  void _characterDataModified(WipEvent event) =>
      _characterDataModifiedController
          .add(new CharacterDataModifiedEvent(event));

  final _childNodeCountUpdatedController =
      new StreamController<ChildNodeCountUpdatedEvent>.broadcast();
  Stream<ChildNodeCountUpdatedEvent> get onChildNodeCountUpdated =>
      _childNodeCountUpdatedController.stream;
  void _childNodeCountUpdated(WipEvent event) =>
      _childNodeCountUpdatedController
          .add(new ChildNodeCountUpdatedEvent(event));

  final _childNodeInsertedController =
      new StreamController<ChildNodeInsertedEvent>.broadcast();
  Stream<ChildNodeInsertedEvent> get onChildNodeInserted =>
      _childNodeInsertedController.stream;
  void _childNodeInserted(WipEvent event) =>
      _childNodeInsertedController.add(new ChildNodeInsertedEvent(event));

  final _childNodeRemovedController =
      new StreamController<ChildNodeRemovedEvent>.broadcast();
  Stream<ChildNodeRemovedEvent> get onChildNodeRemoved =>
      _childNodeRemovedController.stream;
  void _childNodeRemoved(WipEvent event) =>
      _childNodeRemovedController.add(new ChildNodeRemovedEvent(event));

  final _documentUpdatedController =
      new StreamController<DocumentUpdatedEvent>.broadcast();
  Stream<DocumentUpdatedEvent> get onDocumentUpdated =>
      _documentUpdatedController.stream;
  void _documentUpdated(WipEvent event) =>
      _documentUpdatedController.add(new DocumentUpdatedEvent(event));

  final _setChildNodesController =
      new StreamController<SetChildNodesEvent>.broadcast();
  Stream<SetChildNodesEvent> get onSetChildNodes =>
      _setChildNodesController.stream;
  void _setChildNodes(WipEvent event) =>
      _setChildNodesController.add(new SetChildNodesEvent(event));

  @override
  void close() {
    _attributeModifiedController.close();
    _attributeRemovedController.close();
    _characterDataModifiedController.close();
    _childNodeCountUpdatedController.close();
    _childNodeInsertedController.close();
    _childNodeRemovedController.close();
    _documentUpdatedController.close();
    _setChildNodesController.close();
  }
}

class AttributeModifiedEvent extends _WrappedWipEvent {
  AttributeModifiedEvent(WipEvent event) : super(event);

  int get nodeId => params['nodeId'];
  String get name => params['name'];
  String get value => params['value'];
}

class AttributeRemovedEvent extends _WrappedWipEvent {
  AttributeRemovedEvent(WipEvent event) : super(event);

  int get nodeId => params['nodeId'];
  String get name => params['name'];
}

class CharacterDataModifiedEvent extends _WrappedWipEvent {
  CharacterDataModifiedEvent(WipEvent event) : super(event);

  int get nodeId => params['nodeId'];
  String get characterData => params['characterData'];
}

class ChildNodeCountUpdatedEvent extends _WrappedWipEvent {
  ChildNodeCountUpdatedEvent(WipEvent event) : super(event);

  int get nodeId => params['nodeId'];
  int get childNodeCount => params['childNodeCount'];
}

class ChildNodeInsertedEvent extends _WrappedWipEvent {
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

class ChildNodeRemovedEvent extends _WrappedWipEvent {
  ChildNodeRemovedEvent(WipEvent event) : super(event);

  int get parentNodeId => params['parentNodeId'];
  int get nodeId => params['nodeId'];
}

class DocumentUpdatedEvent extends _WrappedWipEvent {
  DocumentUpdatedEvent(WipEvent event) : super(event);
}

class SetChildNodesEvent extends _WrappedWipEvent {
  SetChildNodesEvent(WipEvent event) : super(event);

  int get nodeId => params['parentId'];
  Iterable<Node> get nodes sync* {
    for (Map node in params['nodes']) {
      yield new Node(node);
    }
  }
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
      var attributes = {};
      for (int i = 0; i < _map['attributes'].length; i += 2) {
        attributes[_map['attributes'][i]] =
            attributes[_map['attributes'][i + 1]];
      }
      _attributes = new UnmodifiableMapView<String, String>(attributes);
    }
    return _attributes;
  }

  int get childNodeCount => _map['childNodeCount'];

  Iterable<Node> get children sync* {
    if (_map.containsKey('children')) {
      for (var child in _map['children']) {
        yield new Node(child);
      }
    }
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
