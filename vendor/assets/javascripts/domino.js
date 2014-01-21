var document;

(function e(t,n,r){function s(o,u){if(!n[o]){if(!t[o]){var a=typeof require=="function"&&require;if(!u&&a)return a(o,!0);if(i)return i(o,!0);throw new Error("Cannot find module '"+o+"'")}var f=n[o]={exports:{}};t[o][0].call(f.exports,function(e){var n=t[o][1][e];return s(n?n:e)},f,f.exports,e,t,n,r)}return n[o].exports}var i=typeof require=="function"&&require;for(var o=0;o<r.length;o++)s(r[o]);return s})({1:[function(require,module,exports){
document = require('domino').createWindow().document;

},{"domino":36}],2:[function(require,module,exports){
var parserlib = require('./cssparser');

module.exports = CSSStyleDeclaration;

function CSSStyleDeclaration(elt) {
  this._element = elt;
}

// Utility function for parsing style declarations
// Pass in a string like "margin-left: 5px; border-style: solid"
// and this function returns an object like
// {"margin-left":"5px", "border-style":"solid"}
function parseStyles(s) {
  var parser = new parserlib.css.Parser();
  var result = {};
  parser.addListener("property", function(e) {
    if (e.invalid) return; // Skip errors
    result[e.property.text] = e.value.text;
    if (e.important) result.important[name] = e.important;
  });
  s = (''+s).replace(/^;/, '');
  parser.parseStyleAttribute(s);
  return result;
}

CSSStyleDeclaration.prototype = Object.create(Object.prototype, {

  // Return the parsed form of the element's style attribute.
  // If the element's style attribute has never been parsed
  // or if it has changed since the last parse, then reparse it
  // Note that the styles don't get parsed until they're actually needed
  _parsed: { get: function() {
    if (!this._parsedStyles || this.cssText !== this._lastParsedText) {
      var text = this.cssText;
      this._parsedStyles = parseStyles(text);
      this._lastParsedText = text;
      delete this._names;
    }
    return this._parsedStyles;
  }},

  // Call this method any time the parsed representation of the
  // style changes.  It converts the style properties to a string and
  // sets cssText and the element's style attribute
  _serialize: { value: function() {
    var styles = this._parsed;
    var s = "";

    for(var name in styles) {
      if (s) s += "; ";
      s += name + ":" + styles[name]
    }

    this.cssText = s;      // also sets the style attribute
    this._lastParsedText = s;  // so we don't reparse
    delete this._names;
  }},

  cssText: {
    get: function() {
      // XXX: this is a CSSStyleDeclaration for an element.
      // A different impl might be necessary for a set of styles
      // associated returned by getComputedStyle(), e.g.
      return this._element.getAttribute("style");
    },
    set: function(value) {
      // XXX: I should parse and serialize the value to
      // normalize it and remove errors. FF and chrome do that.
      this._element.setAttribute("style", value);
    }
  },

  length: { get: function() {
    if (!this._names)
      this._names = Object.getOwnPropertyNames(this._parsed);
    return this._names.length;
  }},

  item: { value: function(n) {
    if (!this._names)
      this._names = Object.getOwnPropertyNames(this._parsed);
    return this._names[n];
  }},

  getPropertyValue: { value: function(property) {
    return this._parsed[property.toLowerCase()];
  }},

  // XXX: for now we ignore !important declarations
  getPropertyPriority: { value: function(property) {
    return "";
  }},

  // XXX the priority argument is ignored for now
  setProperty: { value: function(property, value, priority) {
    property = property.toLowerCase();
    if (value === null || value === undefined) {
      value = "";
    }

    // String coercion
    value = "" + value;

    // XXX are there other legal priority values?
    if (priority !== undefined && priority !== "important")
      return;

    // We don't just accept the property value.  Instead
    // we parse it to ensure that it is something valid.
    // If it contains a semicolon it is invalid
    if (value.indexOf(";") !== -1) return;

    var newvalue = value;
    if (value.length) {
      var props = parseStyles(property + ":" + value);
      newvalue = props[property];
      // If there is no value now, it wasn't valid
      if (!newvalue) return;
    }

    var styles = this._parsed;

    // If the value didn't change, return without doing anything.
    var oldvalue = styles[property];
    if (newvalue === oldvalue) return;

    styles[property] = value;

    // Serialize and update cssText and element.style!
    this._serialize();
  }},

  removeProperty: { value: function(property) {
    property = property.toLowerCase();
    var styles = this._parsed;
    if (property in styles) {
      delete styles[property];

      // Serialize and update cssText and element.style!
      this._serialize();
    }
  }},
});

var cssProperties = {
  background: "background",
  backgroundAttachment: "background-attachment",
  backgroundColor: "background-color",
  backgroundImage: "background-image",
  backgroundPosition: "background-position",
  backgroundRepeat: "background-repeat",
  border: "border",
  borderCollapse: "border-collapse",
  borderColor: "border-color",
  borderSpacing: "border-spacing",
  borderStyle: "border-style",
  borderTop: "border-top",
  borderRight: "border-right",
  borderBottom: "border-bottom",
  borderLeft: "border-left",
  borderTopColor: "border-top-color",
  borderRightColor: "border-right-color",
  borderBottomColor: "border-bottom-color",
  borderLeftColor: "border-left-color",
  borderTopStyle:	"border-top-style",
  borderRightStyle: "border-right-style",
  borderBottomStyle: "border-bottom-style",
  borderLeftStyle: "border-left-style",
  borderTopWidth: "border-top-width",
  borderRightWidth: "border-right-width",
  borderBottomWidth: "border-bottom-width",
  borderLeftWidth: "border-left-width",
  borderWidth: "border-width",
  bottom: "bottom",
  captionSide: "caption-side",
  clear: "clear",
  clip: "clip",
  color: "color",
  content: "content",
  counterIncrement: "counter-increment",
  counterReset: "counter-reset",
  cursor: "cursor",
  direction: "direction",
  display: "display",
  emptyCells: "empty-cells",
  cssFloat: "float",
  font: "font",
  fontFamily: "font-family",
  fontSize: "font-size",
  fontSizeAdjust: "font-size-adjust",
  fontStretch: "font-stretch",
  fontStyle: "font-style",
  fontVariant: "font-variant",
  fontWeight: "font-weight",
  height: "height",
  left: "left",
  letterSpacing: "letter-spacing",
  lineHeight: "line-height",
  listStyle: "list-style",
  listStyleImage: "list-style-image",
  listStylePosition: "list-style-position",
  listStyleType: "list-style-type",
  margin: "margin",
  marginTop: "margin-top",
  marginRight: "margin-right",
  marginBottom: "margin-bottom",
  marginLeft: "margin-left",
  markerOffset: "marker-offset",
  marks: "marks",
  maxHeight: "max-height",
  maxWidth: "max-width",
  minHeight: "min-height",
  minWidth: "min-width",
  opacity: "opacity",
  orphans: "orphans",
  outline: "outline",
  outlineColor: "outline-color",
  outlineStyle: "outline-style",
  outlineWidth: "outline-width",
  overflow: "overflow",
  padding: "padding",
  paddingTop: "padding-top",
  paddingRight: "padding-right",
  paddingBottom: "padding-bottom",
  paddingLeft: "padding-left",
  page: "page",
  pageBreakAfter: "page-break-after",
  pageBreakBefore: "page-break-before",
  pageBreakInside: "page-break-inside",
  position: "position",
  quotes: "quotes",
  right: "right",
  size: "size",
  tableLayout: "table-layout",
  textAlign: "text-align",
  textDecoration: "text-decoration",
  textIndent: "text-indent",
  textShadow: "text-shadow",
  textTransform: "text-transform",
  top: "top",
  unicodeBidi: "unicode-bidi",
  verticalAlign: "vertical-align",
  visibility: "visibility",
  whiteSpace: "white-space",
  widows: "widows",
  width: "width",
  wordSpacing: "word-spacing",
  zIndex: "z-index",
};

for(var prop in cssProperties) defineStyleProperty(prop);

function defineStyleProperty(jsname) {
  var cssname = cssProperties[jsname];
  Object.defineProperty(CSSStyleDeclaration.prototype, jsname, {
    get: function() {
      return this.getPropertyValue(cssname);
    },
    set: function(value) {
      // XXX Handle important declarations here!
      this.setProperty(cssname, value);
    }
  });
}

},{"./cssparser":32}],3:[function(require,module,exports){
module.exports = CharacterData;

var Leaf = require('./Leaf');
var utils = require('./utils');

function CharacterData() {
}

CharacterData.prototype = Object.create(Leaf.prototype, {
  // DOMString substringData(unsigned long offset,
  //               unsigned long count);
  // The substringData(offset, count) method must run these steps:
  //
  //     If offset is greater than the context object's
  //     length, throw an INDEX_SIZE_ERR exception and
  //     terminate these steps.
  //
  //     If offset+count is greater than the context
  //     object's length, return a DOMString whose value is
  //     the UTF-16 code units from the offsetth UTF-16 code
  //     unit to the end of data.
  //
  //     Return a DOMString whose value is the UTF-16 code
  //     units from the offsetth UTF-16 code unit to the
  //     offset+countth UTF-16 code unit in data.
  substringData: { value: function substringData(offset, count) {
    if (offset > this.data.length || offset < 0 || count < 0) 
      utils.IndexSizeError();
    return this.data.substring(offset, offset+count);
  }},

  // void appendData(DOMString data);
  // The appendData(data) method must append data to the context
  // object's data.
  appendData: { value: function appendData(data) {
    this.data = this.data + data;
  }},

  // void insertData(unsigned long offset, DOMString data);
  // The insertData(offset, data) method must run these steps:
  //
  //     If offset is greater than the context object's
  //     length, throw an INDEX_SIZE_ERR exception and
  //     terminate these steps.
  //
  //     Insert data into the context object's data after
  //     offset UTF-16 code units.
  //
  insertData: { value: function insertData(offset, data) {
    var curtext = this.data;
    if (offset > curtext.length || offset < 0) utils.IndexSizeError();
    var prefix = curtext.substring(0, offset),
    suffix = curtext.substring(offset);
    this.data = prefix + data + suffix;
  }},


  // void deleteData(unsigned long offset, unsigned long count);
  // The deleteData(offset, count) method must run these steps:
  //
  //     If offset is greater than the context object's
  //     length, throw an INDEX_SIZE_ERR exception and
  //     terminate these steps.
  //
  //     If offset+count is greater than the context
  //     object's length var count be length-offset.
  //
  //     Starting from offset UTF-16 code units remove count
  //     UTF-16 code units from the context object's data.
  deleteData: { value: function deleteData(offset, count) {
    var curtext = this.data, len = curtext.length;

    if (offset > len || offset < 0) utils.IndexSizeError();

    if (offset+count > len)
      count = len - offset;

    var prefix = curtext.substring(0, offset),
    suffix = curtext.substring(offset+count);

    this.data = prefix + suffix;
  }},


  // void replaceData(unsigned long offset, unsigned long count,
  //          DOMString data);
  //
  // The replaceData(offset, count, data) method must act as
  // if the deleteData() method is invoked with offset and
  // count as arguments followed by the insertData() method
  // with offset and data as arguments and re-throw any
  // exceptions these methods might have thrown.
  replaceData: { value: function replaceData(offset, count, data) {
    var curtext = this.data, len = curtext.length;

    if (offset > len || offset < 0) utils.IndexSizeError();

    if (offset+count > len)
      count = len - offset;

    var prefix = curtext.substring(0, offset),
    suffix = curtext.substring(offset+count);

    this.data = prefix + data + suffix;
  }},

  // Utility method that Node.isEqualNode() calls to test Text and
  // Comment nodes for equality.  It is okay to put it here, since
  // Node will have already verified that nodeType is equal
  isEqual: { value: function isEqual(n) {
    return this._data === n._data;
  }},

  length: { get: function() { return this.data.length; }}

});

},{"./Leaf":17,"./utils":38}],4:[function(require,module,exports){
module.exports = Comment;

var Node = require('./Node');
var CharacterData = require('./CharacterData');

function Comment(doc, data) {
  this.nodeType = Node.COMMENT_NODE;
  this.ownerDocument = doc;
  this._data = data;
  this._index = undefined;
}

var nodeValue = {
  get: function() { return this._data; },
  set: function(v) {
    this._data = v;
    if (this.rooted)
      this.ownerDocument.mutateValue(this);
  }
};

Comment.prototype = Object.create(CharacterData.prototype, {
  nodeName: { value: '#comment' },
  nodeValue: nodeValue,
  textContent: nodeValue,
  data: nodeValue,

  // Utility methods
  clone: { value: function clone() {
    return new Comment(this.ownerDocument, this._data);
  }},
});

},{"./CharacterData":3,"./Node":21}],5:[function(require,module,exports){
module.exports = CustomEvent;

var Event = require('./Event');

function CustomEvent(type, dictionary) {
  // Just use the superclass constructor to initialize
  Event.call(this, type, dictionary);
}
CustomEvent.prototype = Object.create(Event.prototype, {
	constructor: { value: CustomEvent }
});

},{"./Event":13}],6:[function(require,module,exports){
module.exports = DOMException;

var INDEX_SIZE_ERR = 1;
var HIERARCHY_REQUEST_ERR = 3;
var WRONG_DOCUMENT_ERR = 4;
var INVALID_CHARACTER_ERR = 5;
var NO_MODIFICATION_ALLOWED_ERR = 7;
var NOT_FOUND_ERR = 8;
var NOT_SUPPORTED_ERR = 9;
var INVALID_STATE_ERR = 11;
var SYNTAX_ERR = 12;
var INVALID_MODIFICATION_ERR = 13;
var NAMESPACE_ERR = 14;
var INVALID_ACCESS_ERR = 15;
var TYPE_MISMATCH_ERR = 17;
var SECURITY_ERR = 18;
var NETWORK_ERR = 19;
var ABORT_ERR = 20;
var URL_MISMATCH_ERR = 21;
var QUOTA_EXCEEDED_ERR = 22;
var TIMEOUT_ERR = 23;
var INVALID_NODE_TYPE_ERR = 24;
var DATA_CLONE_ERR = 25;

// Code to name
var names = [
  null,  // No error with code 0
  'INDEX_SIZE_ERR',
  null, // historical
  'HIERARCHY_REQUEST_ERR',
  'WRONG_DOCUMENT_ERR',
  'INVALID_CHARACTER_ERR',
  null, // historical
  'NO_MODIFICATION_ALLOWED_ERR',
  'NOT_FOUND_ERR',
  'NOT_SUPPORTED_ERR',
  null, // historical
  'INVALID_STATE_ERR',
  'SYNTAX_ERR',
  'INVALID_MODIFICATION_ERR',
  'NAMESPACE_ERR',
  'INVALID_ACCESS_ERR',
  null, // historical
  'TYPE_MISMATCH_ERR',
  'SECURITY_ERR',
  'NETWORK_ERR',
  'ABORT_ERR',
  'URL_MISMATCH_ERR',
  'QUOTA_EXCEEDED_ERR',
  'TIMEOUT_ERR',
  'INVALID_NODE_TYPE_ERR',
  'DATA_CLONE_ERR',
];

// Code to message
// These strings are from the 13 May 2011 Editor's Draft of DOM Core.
// http://dvcs.w3.org/hg/domcore/raw-file/tip/Overview.html
// Copyright © 2011 W3C® (MIT, ERCIM, Keio), All Rights Reserved.
// Used under the terms of the W3C Document License:
// http://www.w3.org/Consortium/Legal/2002/copyright-documents-20021231
var messages = [
  null,  // No error with code 0
  'INDEX_SIZE_ERR (1): the index is not in the allowed range',
  null,
  'HIERARCHY_REQUEST_ERR (3): the operation would yield an incorrect nodes model',
  'WRONG_DOCUMENT_ERR (4): the object is in the wrong Document, a call to importNode is required',
  'INVALID_CHARACTER_ERR (5): the string contains invalid characters',
  null,
  'NO_MODIFICATION_ALLOWED_ERR (7): the object can not be modified',
  'NOT_FOUND_ERR (8): the object can not be found here',
  'NOT_SUPPORTED_ERR (9): this operation is not supported',
  null,
  'INVALID_STATE_ERR (11): the object is in an invalid state',
  'SYNTAX_ERR (12): the string did not match the expected pattern',
  'INVALID_MODIFICATION_ERR (13): the object can not be modified in this way',
  'NAMESPACE_ERR (14): the operation is not allowed by Namespaces in XML',
  'INVALID_ACCESS_ERR (15): the object does not support the operation or argument',
  null,
  'TYPE_MISMATCH_ERR (17): the type of the object does not match the expected type',
  'SECURITY_ERR (18): the operation is insecure',
  'NETWORK_ERR (19): a network error occurred',
  'ABORT_ERR (20): the user aborted an operation',
  'URL_MISMATCH_ERR (21): the given URL does not match another URL',
  'QUOTA_EXCEEDED_ERR (22): the quota has been exceeded',
  'TIMEOUT_ERR (23): a timeout occurred',
  'INVALID_NODE_TYPE_ERR (24): the supplied node is invalid or has an invalid ancestor for this operation',
  'DATA_CLONE_ERR (25): the object can not be cloned.'
];

// Name to code
var constants = {
  INDEX_SIZE_ERR: INDEX_SIZE_ERR,
  DOMSTRING_SIZE_ERR: 2, // historical
  HIERARCHY_REQUEST_ERR: HIERARCHY_REQUEST_ERR,
  WRONG_DOCUMENT_ERR: WRONG_DOCUMENT_ERR,
  INVALID_CHARACTER_ERR: INVALID_CHARACTER_ERR,
  NO_DATA_ALLOWED_ERR: 6, // historical
  NO_MODIFICATION_ALLOWED_ERR: NO_MODIFICATION_ALLOWED_ERR,
  NOT_FOUND_ERR: NOT_FOUND_ERR,
  NOT_SUPPORTED_ERR: NOT_SUPPORTED_ERR,
  INUSE_ATTRIBUTE_ERR: 10, // historical
  INVALID_STATE_ERR: INVALID_STATE_ERR,
  SYNTAX_ERR: SYNTAX_ERR,
  INVALID_MODIFICATION_ERR: INVALID_MODIFICATION_ERR,
  NAMESPACE_ERR: NAMESPACE_ERR,
  INVALID_ACCESS_ERR: INVALID_ACCESS_ERR,
  VALIDATION_ERR: 16, // historical
  TYPE_MISMATCH_ERR: TYPE_MISMATCH_ERR,
  SECURITY_ERR: SECURITY_ERR,
  NETWORK_ERR: NETWORK_ERR,
  ABORT_ERR: ABORT_ERR,
  URL_MISMATCH_ERR: URL_MISMATCH_ERR,
  QUOTA_EXCEEDED_ERR: QUOTA_EXCEEDED_ERR,
  TIMEOUT_ERR: TIMEOUT_ERR,
  INVALID_NODE_TYPE_ERR: INVALID_NODE_TYPE_ERR,
  DATA_CLONE_ERR: DATA_CLONE_ERR
};

function DOMException(code) {
  Error.call(this);
  Error.captureStackTrace(this, arguments.callee);
  this.code = code;
  this.message = messages[code];
  this.name = names[code];
}
DOMException.prototype.__proto__ = Error.prototype;

// Initialize the constants on DOMException and DOMException.prototype
for(var c in constants) {
  var v = { value: constants[c] };
  Object.defineProperty(DOMException, c, v);
  Object.defineProperty(DOMException.prototype, c, v);
}

},{}],7:[function(require,module,exports){
module.exports = DOMImplementation;

var Document = require('./Document');
var DocumentType = require('./DocumentType');
var HTMLParser = require('./HTMLParser');
var utils = require('./utils');
var xml = require('./xmlnames');

// Each document must have its own instance of the domimplementation object
// Even though these objects have no state
function DOMImplementation() {}


// Feature/version pairs that DOMImplementation.hasFeature() returns
// true for.  It returns false for anything else.
var supportedFeatures = {
  'xml': { '': true, '1.0': true, '2.0': true },   // DOM Core
  'core': { '': true, '2.0': true },               // DOM Core
  'html': { '': true, '1.0': true, '2.0': true} ,  // HTML
  'xhtml': { '': true, '1.0': true, '2.0': true} , // HTML
};

DOMImplementation.prototype = {
  hasFeature: function hasFeature(feature, version) {
    var f = supportedFeatures[(feature || '').toLowerCase()];
    return (f && f[version || '']) || false;
  },

  createDocumentType: function createDocumentType(qualifiedName, publicId, systemId) {
    if (!xml.isValidName(qualifiedName)) utils.InvalidCharacterError();
    if (!xml.isValidQName(qualifiedName)) utils.NamespaceError();

    return new DocumentType(qualifiedName, publicId, systemId);
  },

  createDocument: function createDocument(namespace, qualifiedName, doctype) {
    //
    // Note that the current DOMCore spec makes it impossible to
    // create an HTML document with this function, even if the
    // namespace and doctype are propertly set.  See this thread:
    // http://lists.w3.org/Archives/Public/www-dom/2011AprJun/0132.html
    //
    var d = new Document(false, null);
    var e;

    if (qualifiedName)
      e = d.createElementNS(namespace, qualifiedName);
    else
      e = null;

    if (doctype) {
      if (doctype.ownerDocument) utils.WrongDocumentError();
      d.appendChild(doctype);
    }

    if (e) d.appendChild(e);

    return d;
  },

  createHTMLDocument: function createHTMLDocument(titleText) {
    var d = new Document(true, null);
    d.appendChild(new DocumentType('html'));
    var html = d.createElement('html');
    d.appendChild(html);
    var head = d.createElement('head');
    html.appendChild(head);
    var title = d.createElement('title');
    head.appendChild(title);
    title.appendChild(d.createTextNode(titleText));
    html.appendChild(d.createElement('body'));
    d.modclock = 1; // Start tracking modifications
    return d;
  },

  mozSetOutputMutationHandler: function(doc, handler) {
    doc.mutationHandler = handler;
  },

  mozGetInputMutationHandler: function(doc) {
    utils.nyi();
  },

  mozHTMLParser: HTMLParser,
};

},{"./Document":9,"./DocumentType":11,"./HTMLParser":16,"./utils":38,"./xmlnames":39}],8:[function(require,module,exports){
// DOMTokenList implementation based on https://github.com/Raynos/DOM-shim
var utils = require('./utils');

module.exports = DOMTokenList;

function DOMTokenList(getter, setter) {
  this._getString = getter;
  this._setString = setter;
  fixIndex(this, getList(this));
}

DOMTokenList.prototype = {
  item: function(index) {
    if (index >= this.length) {
      return null;
    }
    return this._getString().split(" ")[index];
  },

  contains: function(token) {
    handleErrors(token);
    var list = getList(this);
    return list.indexOf(token) > -1;
  },

  add: function(token) {
    handleErrors(token);
    var list = getList(this);
    if (list.indexOf(token) > -1) {
      return;
    }
    list.push(token);
    this._setString(list.join(" ").trim());
    fixIndex(this, list);
  },

  remove: function(token) {
    handleErrors(token);
    var list = getList(this);
    var index = list.indexOf(token);
    if (index > -1) {
      list.splice(index, 1);
      this._setString(list.join(" ").trim());
    }
    fixIndex(this, list);
  },

  toggle: function toggle(token) {
    if (this.contains(token)) {
      this.remove(token);
      return false;
    }
    else {
      this.add(token);
      return true;
    }
  },

  toString: function() {
    return this._getString();
  }
};

function fixIndex(clist, list) {
  clist.length = list.length;
  for (var i = 0; i < list.length; i++) {
    clist[i] = list[i];
  }
}

function handleErrors(token) {
  if (token === "" || token === undefined) {
    utils.SyntaxError();
  }
  if (token.indexOf(" ") > -1) {
    utils.InvalidCharacterError();
  }
}

function getList(clist) {
  var str = clist._getString();
  if (str === "") {
    return [];
  }
  else {
    return str.split(" ");
  }
}

},{"./utils":38}],9:[function(require,module,exports){
module.exports = Document;

var Node = require('./Node');
var NodeList = require('./NodeList');
var Element = require('./Element');
var Text = require('./Text');
var Comment = require('./Comment');
var Event = require('./Event');
var DocumentFragment = require('./DocumentFragment');
var ProcessingInstruction = require('./ProcessingInstruction');
var DOMImplementation = require('./DOMImplementation');
var FilteredElementList = require('./FilteredElementList');
var TreeWalker = require('./TreeWalker');
var NodeFilter = require('./NodeFilter');
var URL = require('./URL');
var select = require('./select')
var events = require('./events');
var xml = require('./xmlnames');
var html = require('./htmlelts');
var impl = html.elements;
var utils = require('./utils');
var MUTATE = require('./MutationConstants');
var NAMESPACE = utils.NAMESPACE;

function Document(isHTML, address) {
  this.nodeType = Node.DOCUMENT_NODE;
  this.isHTML = isHTML;
  this._address = address || 'about:blank';
  this.readyState = 'loading';
  this.implementation = new DOMImplementation();

  // DOMCore says that documents are always associated with themselves
  this.ownerDocument = null; // ... but W3C tests expect null

  // These will be initialized by our custom versions of
  // appendChild and insertBefore that override the inherited
  // Node methods.
  // XXX: override those methods!
  this.doctype = null;
  this.documentElement = null;
  this.childNodes = new NodeList();

  // Documents are always rooted, by definition
  this._nid = 1;
  this._nextnid = 2; // For numbering children of the document
  this._nodes = [null, this];  // nid to node map

  // This maintains the mapping from element ids to element nodes.
  // We may need to update this mapping every time a node is rooted
  // or uprooted, and any time an attribute is added, removed or changed
  // on a rooted element.
  this.byId = {};

  // This property holds a monotonically increasing value akin to
  // a timestamp used to record the last modification time of nodes
  // and their subtrees. See the lastModTime attribute and modify()
  // method of the Node class. And see FilteredElementList for an example
  // of the use of lastModTime
  this.modclock = 0;
}

// Map from lowercase event category names (used as arguments to
// createEvent()) to the property name in the impl object of the
// event constructor.
var supportedEvents = {
  event: 'Event',
  customevent: 'CustomEvent',
  uievent: 'UIEvent',
  mouseevent: 'MouseEvent'
};

// Certain arguments to document.createEvent() must be treated specially
var replacementEvent = {
  events: 'event',
  htmlevents: 'event',
  mouseevents: 'mouseevent',
  mutationevents: 'mutationevent',
  uievents: 'uievent'
};

Document.prototype = Object.create(Node.prototype, {
  // This method allows dom.js to communicate with a renderer
  // that displays the document in some way
  // XXX: I should probably move this to the window object
  _setMutationHandler: { value: function(handler) {
    this.mutationHandler = handler;
  }},

  // This method allows dom.js to receive event notifications
  // from the renderer.
  // XXX: I should probably move this to the window object
  _dispatchRendererEvent: { value: function(targetNid, type, details) {
    var target = this._nodes[targetNid];
    if (!target) return;
    target._dispatchEvent(new Event(type, details), true);
  }},

  nodeName: { value: '#document'},
  nodeValue: {
    get: function() {
      return null;
    },
    set: function() {}
  },

  // XXX: DOMCore may remove documentURI, so it is NYI for now
  documentURI: { get: utils.nyi, set: utils.nyi },
  compatMode: { get: function() {
    // The _quirks property is set by the HTML parser
    return this._quirks ? 'BackCompat' : 'CSS1Compat';
  }},
  parentNode: { value: null },

  createTextNode: { value: function(data) {
    return new Text(this, '' + data);
  }},
  createComment: { value: function(data) {
    return new Comment(this, data);
  }},
  createDocumentFragment: { value: function() {
    return new DocumentFragment(this);
  }},
  createProcessingInstruction: { value: function(target, data) {
    if (this.isHTML) utils.NotSupportedError();
    if (!xml.isValidName(target) || data.indexOf('?>') !== -1)
      utils.InvalidCharacterError();
    return new ProcessingInstruction(this, target, data);
  }},

  createElement: { value: function(localName) {
    if (!xml.isValidName(localName)) utils.InvalidCharacterError();
    if (this.isHTML) localName = localName.toLowerCase();
    return html.createElement(this, localName, null);
  }},

  createElementNS: { value: function(namespace, qualifiedName) {
    if (!xml.isValidName(qualifiedName)) utils.InvalidCharacterError();
    if (!xml.isValidQName(qualifiedName)) utils.NamespaceError();

    var pos, prefix, localName;
    if ((pos = qualifiedName.indexOf(':')) !== -1) {
      prefix = qualifiedName.substring(0, pos);
      localName = qualifiedName.substring(pos+1);

      if (namespace === '' ||
        (prefix === 'xml' && namespace !== NAMESPACE.XML))
        utils.NamespaceError();
    }
    else {
      prefix = null;
      localName = qualifiedName;
    }

    if (((qualifiedName === 'xmlns' || prefix === 'xmlns') &&
       namespace !== NAMESPACE.XMLNS) ||
      (namespace === NAMESPACE.XMLNS &&
       qualifiedName !== 'xmlns' &&
       prefix !== 'xmlns'))
      utils.NamespaceError();

    if (namespace === NAMESPACE.HTML) {
      return html.createElement(this, localName, prefix);
    }

    return new Element(this, localName, namespace, prefix);
  }},

  createEvent: { value: function createEvent(interfaceName) {
    interfaceName = interfaceName.toLowerCase();
    var name = replacementEvent[interfaceName] || interfaceName;
    var constructor = events[supportedEvents[name]];

    if (constructor) {
      var e = new constructor();
      e._initialized = false;
      return e;
    }
    else {
      utils.NotSupportedError();
    }
  }},

  // See: http://www.w3.org/TR/dom/#dom-document-createtreewalker
  createTreeWalker: {value: function (root, whatToShow, filter) {
    whatToShow = whatToShow === undefined ? NodeFilter.SHOW_ALL : whatToShow;

    if (filter && typeof filter.acceptNode == 'function') {
      filter = filter.acceptNode;
      // Support filter being a function
      // https://developer.mozilla.org/en-US/docs/DOM/document.createTreeWalker
    }
    else if (typeof filter != 'function') {
      filter = null;
    }
    return new TreeWalker(root, whatToShow, filter);
  }},

  // Add some (surprisingly complex) document hierarchy validity
  // checks when adding, removing and replacing nodes into a
  // document object, and also maintain the documentElement and
  // doctype properties of the document.  Each of the following
  // 4 methods chains to the Node implementation of the method
  // to do the actual inserting, removal or replacement.

  appendChild: { value: function(child) {
    if (child.nodeType === Node.TEXT_NODE) utils.HierarchyRequestError();
    if (child.nodeType === Node.ELEMENT_NODE) {
      if (this.documentElement) // We already have a root element
        utils.HierarchyRequestError();

      this.documentElement = child;
    }
    if (child.nodeType === Node.DOCUMENT_TYPE_NODE) {
      if (this.doctype ||      // Already have one
        this.documentElement) // Or out-of-order
        utils.HierarchyRequestError();

      this.doctype = child;
    }

    // Now chain to our superclass
    return Node.prototype.appendChild.call(this, child);
  }},

  insertBefore: { value: function insertBefore(child, refChild) {
    if (refChild === null) return Document.prototype.appendChild.call(this, child);
    if (refChild.parentNode !== this) utils.NotFoundError();
    if (child.nodeType === Node.TEXT_NODE) utils.HierarchyRequestError();
    if (child.nodeType === Node.ELEMENT_NODE) {
      // If we already have a root element or if we're trying to
      // insert it before the doctype
      if (this.documentElement ||
        (this.doctype && this.doctype.index >= refChild.index))
        utils.HierarchyRequestError();

      this.documentElement = child;
    }
    if (child.nodeType === Node.DOCUMENT_TYPE_NODE) {
      if (this.doctype ||
        (this.documentElement &&
         refChild.index > this.documentElement.index))
        utils.HierarchyRequestError();

      this.doctype = child;
    }
    return Node.prototype.insertBefore.call(this, child, refChild);
  }},

  replaceChild: { value: function replaceChild(child, oldChild) {
    if (oldChild.parentNode !== this) utils.NotFoundError();

    if (child.nodeType === Node.TEXT_NODE) utils.HierarchyRequestError();
    if (child.nodeType === Node.ELEMENT_NODE) {
      // If we already have a root element and we're not replacing it
      if (this.documentElement && this.documentElement !== oldChild)
        utils.HierarchyRequestError();
      // Or if we're trying to put the element before the doctype
      // (replacing the doctype is okay)
      if (this.doctype && oldChild.index < this.doctype.index)
        utils.HierarchyRequestError();

      if (oldChild === this.doctype) this.doctype = null;
    }
    else if (child.nodeType === Node.DOCUMENT_TYPE_NODE) {
      // If we already have a doctype and we're not replacing it
      if (this.doctype && oldChild !== this.doctype)
        utils.HierarchyRequestError();
      // If we have a document element and the old child
      // comes after it
      if (this.documentElement &&
        oldChild.index > this.documentElement.index)
        utils.HierarchyRequestError();

      if (oldChild === this.documentElement)
        this.documentElement = null;
    }
    else {
      if (oldChild === this.documentElement)
        this.documentElement = null;
      else if (oldChild === this.doctype)
        this.doctype = null;
    }
    return Node.prototype.replaceChild.call(this,child,oldChild);
  }},

  removeChild: { value: function removeChild(child) {
    if (child.nodeType === Node.DOCUMENT_TYPE_NODE)
      this.doctype = null;
    else if (child.nodeType === Node.ELEMENT_NODE)
      this.documentElement = null;

    // Now chain to our superclass
    return Node.prototype.removeChild.call(this, child);
  }},

  getElementById: { value: function(id) {
    var n = this.byId[id];
    if (!n) return null;
    if (Array.isArray(n)) { // there was more than one element with this id
      return n[0];  // array is sorted in document order
    }
    return n;
  }},

  // Just copy this method from the Element prototype
  getElementsByTagName: { value: Element.prototype.getElementsByTagName },
  getElementsByTagNameNS: { value: Element.prototype.getElementsByTagNameNS },
  getElementsByClassName: { value: Element.prototype.getElementsByClassName },

  adoptNode: { value: function adoptNode(node) {
    if (node.nodeType === Node.DOCUMENT_NODE ||
      node.nodeType === Node.DOCUMENT_TYPE_NODE) utils.NotSupportedError();

    if (node.parentNode) node.parentNode.removeChild(node);

    if (node.ownerDocument !== this)
      recursivelySetOwner(node, this);

    return node;
  }},

  importNode: { value: function importNode(node, deep) {
    return this.adoptNode(node.cloneNode());
  }},

  // The following attributes and methods are from the HTML spec
  URL: { get: utils.nyi },
  domain: { get: utils.nyi, set: utils.nyi },
  referrer: { get: utils.nyi },
  cookie: { get: utils.nyi, set: utils.nyi },
  lastModified: { get: utils.nyi },
  title: {
    get: function() {
      // Return the text of the first <title> child of the <head> element.
      var elt = namedHTMLChild(this.head, 'title');
      return elt && elt.textContent || '';
    },
    set: function(value) {
      var head = this.head;
      if (!head) { return; /* according to spec */ }
      var elt = namedHTMLChild(head, 'title');
      if (!elt) {
        elt = this.createElement('title');
        head.appendChild(elt);
      }
      elt.textContent = value;
    }
  },
  dir:  { get: utils.nyi, set: utils.nyi },
  // Return the first <body> child of the document element.
  // XXX For now, setting this attribute is not implemented.
  body: {
    get: function() {
      return namedHTMLChild(this.documentElement, 'body');
    },
    set: utils.nyi
  },
  // Return the first <head> child of the document element.
  head: { get: function() {
    return namedHTMLChild(this.documentElement, 'head');
  }},
  images: { get: utils.nyi },
  embeds: { get: utils.nyi },
  plugins: { get: utils.nyi },
  links: { get: utils.nyi },
  forms: { get: utils.nyi },
  scripts: { get: utils.nyi },
  innerHTML: {
    get: function() { return this.serialize(); },
    set: utils.nyi
  },
  outerHTML: {
    get: function() { return this.serialize(); },
    set: utils.nyi
  },

  write: { value: function(args) {
    if (!this.isHTML) utils.InvalidStateError();

    // XXX: still have to implement the ignore part
    if (!this._parser /* && this._ignore_destructive_writes > 0 */ )
      return;

    if (!this._parser) {
      // XXX call document.open, etc.
    }

    var s = arguments.join('');

    // If the Document object's reload override flag is set, then
    // append the string consisting of the concatenation of all the
    // arguments to the method to the Document's reload override
    // buffer.
    // XXX: don't know what this is about.  Still have to do it

    // If there is no pending parsing-blocking script, have the
    // tokenizer process the characters that were inserted, one at a
    // time, processing resulting tokens as they are emitted, and
    // stopping when the tokenizer reaches the insertion point or when
    // the processing of the tokenizer is aborted by the tree
    // construction stage (this can happen if a script end tag token is
    // emitted by the tokenizer).

    // XXX: still have to do the above. Sounds as if we don't
    // always call parse() here.  If we're blocked, then we just
    // insert the text into the stream but don't parse it reentrantly...

    // Invoke the parser reentrantly
    this._parser.parse(s);
  }},

  writeln: { value: function writeln(args) {
    this.write(Array.prototype.join.call(arguments, '') + '\n');
  }},

  open: { value: function() {
    this.documentElement = null;
  }},

  close: { value: function() {
    this.readyState = 'complete';
    var ev = new Event('DOMContentLoaded');
    this._dispatchEvent(ev, true);
    if (this.defaultView) {
      ev = new Event('load');
      this.defaultView._dispatchEvent(ev, true);
    }
  }},

  // Utility methods
  clone: { value: function clone() {
    // Can't clone an entire document
    utils.DataCloneError();
  }},

  isEqual: { value: function isEqual(n) {
    // Any two documents are shallowly equal.
    // Node.isEqualNode will also test the children
    return true;
  }},

  // Implementation-specific function.  Called when a text, comment,
  // or pi value changes.
  mutateValue: { value: function(node) {
    if (this.mutationHandler) {
      this.mutationHandler({
        type: MUTATE.VALUE,
        target: node,
        data: node.data
      });
    }
  }},

  // Invoked when an attribute's value changes. Attr holds the new
  // value.  oldval is the old value.  Attribute mutations can also
  // involve changes to the prefix (and therefore the qualified name)
  mutateAttr: { value: function(attr, oldval) {
    // Manage id->element mapping for getElementsById()
    // XXX: this special case id handling should not go here,
    // but in the attribute declaration for the id attribute
    /*
    if (attr.localName === 'id' && attr.namespaceURI === null) {
      if (oldval) delId(oldval, attr.ownerElement);
      addId(attr.value, attr.ownerElement);
    }
    */
    if (this.mutationHandler) {
      this.mutationHandler({
        type: MUTATE.ATTR,
        target: attr.ownerElement,
        attr: attr
      });
    }
  }},

  // Used by removeAttribute and removeAttributeNS for attributes.
  mutateRemoveAttr: { value: function(attr) {
/*
* This is now handled in Attributes.js
    // Manage id to element mapping
    if (attr.localName === 'id' && attr.namespaceURI === null) {
      this.delId(attr.value, attr.ownerElement);
    }
*/
    if (this.mutationHandler) {
      this.mutationHandler({
        type: MUTATE.REMOVE_ATTR,
        target: attr.ownerElement,
        attr: attr
      });
    }
  }},

  // Called by Node.removeChild, etc. to remove a rooted element from
  // the tree. Only needs to generate a single mutation event when a
  // node is removed, but must recursively mark all descendants as not
  // rooted.
  mutateRemove: { value: function(node) {
    // Send a single mutation event
    if (this.mutationHandler) {
      this.mutationHandler({
        type: MUTATE.REMOVE,
        target: node.parentNode,
        node: node
      });
    }

    // Mark this and all descendants as not rooted
    recursivelyUproot(node);
  }},

  // Called when a new element becomes rooted.  It must recursively
  // generate mutation events for each of the children, and mark them all
  // as rooted.
  mutateInsert: { value: function(node) {
    // Mark node and its descendants as rooted
    recursivelyRoot(node);

    // Send a single mutation event
    if (this.mutationHandler) {
      this.mutationHandler({
        type: MUTATE.INSERT,
        target: node.parentNode,
        node: node
      });
    }
  }},

  // Called when a rooted element is moved within the document
  mutateMove: { value: function(node) {
    if (this.mutationHandler) {
      this.mutationHandler({
        type: MUTATE.MOVE,
        target: node
      });
    }
  }},


  // Add a mapping from  id to n for n.ownerDocument
  addId: { value: function addId(id, n) {
    var val = this.byId[id];
    if (!val) {
      this.byId[id] = n;
    }
    else {
      // TODO: Add a way to opt-out console warnings
      //console.warn('Duplicate element id ' + id);
      if (!Array.isArray(val)) {
        val = [val];
        this.byId[id] = val;
      }
      val.push(n);
      val.sort(utils.documentOrder);
    }
  }},

  // Delete the mapping from id to n for n.ownerDocument
  delId: { value: function delId(id, n) {
    var val = this.byId[id];
    utils.assert(val);

    if (Array.isArray(val)) {
      var idx = val.indexOf(n);
      val.splice(idx, 1);

      if (val.length == 1) { // convert back to a single node
        this.byId[id] = val[0];
      }
    }
    else {
      this.byId[id] = undefined;
    }
  }},

  _resolve: { value: function(href) {
    //XXX: Cache the URL
    return new URL(this._documentBaseURL).resolve(href);
  }},

  _documentBaseURL: { get: function() {
    // XXX: This is not implemented correctly yet
    var url = this._address;
    if (url == 'about:blank') url = '/';
    return url;

    // The document base URL of a Document object is the
    // absolute URL obtained by running these substeps:

    //     Let fallback base url be the document's address.

    //     If fallback base url is about:blank, and the
    //     Document's browsing context has a creator browsing
    //     context, then let fallback base url be the document
    //     base URL of the creator Document instead.

    //     If the Document is an iframe srcdoc document, then
    //     let fallback base url be the document base URL of
    //     the Document's browsing context's browsing context
    //     container's Document instead.

    //     If there is no base element that has an href
    //     attribute, then the document base URL is fallback
    //     base url; abort these steps. Otherwise, let url be
    //     the value of the href attribute of the first such
    //     element.

    //     Resolve url relative to fallback base url (thus,
    //     the base href attribute isn't affected by xml:base
    //     attributes).

    //     The document base URL is the result of the previous
    //     step if it was successful; otherwise it is fallback
    //     base url.
  }},

  querySelector: { value: function(selector) {
    return select(selector, this)[0];
  }},

  querySelectorAll: { value: function(selector) {
    var nodes = select(selector, this);
    return nodes.item ? nodes : new NodeList(nodes);
  }}

});


var eventHandlerTypes = [
  'abort', 'canplay', 'canplaythrough', 'change', 'click', 'contextmenu',
  'cuechange', 'dblclick', 'drag', 'dragend', 'dragenter', 'dragleave',
  'dragover', 'dragstart', 'drop', 'durationchange', 'emptied', 'ended',
  'input', 'invalid', 'keydown', 'keypress', 'keyup', 'loadeddata',
  'loadedmetadata', 'loadstart', 'mousedown', 'mousemove', 'mouseout',
  'mouseover', 'mouseup', 'mousewheel', 'pause', 'play', 'playing',
  'progress', 'ratechange', 'readystatechange', 'reset', 'seeked',
  'seeking', 'select', 'show', 'stalled', 'submit', 'suspend',
  'timeupdate', 'volumechange', 'waiting',

  'blur', 'error', 'focus', 'load', 'scroll'
];

// Add event handler idl attribute getters and setters to Document
eventHandlerTypes.forEach(function(type) {
  // Define the event handler registration IDL attribute for this type
  Object.defineProperty(Document.prototype, 'on' + type, {
    get: function() {
      return this._getEventHandler(type);
    },
    set: function(v) {
      this._setEventHandler(type, v);
    }
  });
});

function namedHTMLChild(parent, name) {
  if (parent && parent.isHTML) {
    var kids = parent.childNodes;
    for(var i = 0, n = kids.length; i < n; i++) {
      if (kids[i].nodeType === Node.ELEMENT_NODE &&
        kids[i].localName === name &&
        kids[i].namespaceURI === NAMESPACE.HTML) {
        return kids[i];
      }
    }
  }
  return null;
}

function root(n) {
  n._nid = n.ownerDocument._nextnid++;
  n.ownerDocument._nodes[n._nid] = n;
  // Manage id to element mapping
  if (n.nodeType === Node.ELEMENT_NODE) {
    var id = n.getAttribute('id');
    if (id) n.ownerDocument.addId(id, n);

    // Script elements need to know when they're inserted
    // into the document
    if (n._roothook) n._roothook();
  }
}

function uproot(n) {
  // Manage id to element mapping
  if (n.nodeType === Node.ELEMENT_NODE) {
    var id = n.getAttribute('id');
    if (id) n.ownerDocument.delId(id, n);
  }
  n.ownerDocument._nodes[n._nid] = undefined;
  n._nid = undefined;
}

function recursivelyRoot(node) {
  root(node);
  // XXX:
  // accessing childNodes on a leaf node creates a new array the
  // first time, so be careful to write this loop so that it
  // doesn't do that. node is polymorphic, so maybe this is hard to
  // optimize?  Try switching on nodeType?
/*
  if (node.hasChildNodes()) {
    var kids = node.childNodes;
    for(var i = 0, n = kids.length;  i < n; i++)
      recursivelyRoot(kids[i]);
  }
*/
  if (node.nodeType === Node.ELEMENT_NODE) {
    var kids = node.childNodes;
    for(var i = 0, n = kids.length; i < n; i++)
      recursivelyRoot(kids[i]);
  }
}

function recursivelyUproot(node) {
  uproot(node);
  for(var i = 0, n = node.childNodes.length; i < n; i++)
    recursivelyUproot(node.childNodes[i]);
}

function recursivelySetOwner(node, owner) {
  node.ownerDocument = owner;
  node._lastModTime = undefined; // mod times are document-based
  var kids = node.childNodes;
  for(var i = 0, n = kids.length; i < n; i++)
    recursivelySetOwner(kids[i], owner);
}

},{"./Comment":4,"./DOMImplementation":7,"./DocumentFragment":10,"./Element":12,"./Event":13,"./FilteredElementList":15,"./MutationConstants":20,"./Node":21,"./NodeFilter":22,"./NodeList":23,"./ProcessingInstruction":24,"./Text":25,"./TreeWalker":26,"./URL":28,"./events":33,"./htmlelts":34,"./select":37,"./utils":38,"./xmlnames":39}],10:[function(require,module,exports){
module.exports =  DocumentFragment;

var Node = require('./Node');
var NodeList = require('./NodeList');
var Element = require('./Element');
var select = require('./select');

function DocumentFragment(doc) {
  this.nodeType = Node.DOCUMENT_FRAGMENT_NODE;
  this.ownerDocument = doc;
  this.childNodes = [];
}

DocumentFragment.prototype = Object.create(Node.prototype, {
  nodeName: { value: '#document-fragment' },
  nodeValue: { 
    get: function() { 
      return null;
    },
    set: function() {}
  },
  // Copy the text content getter/setter from Element
  textContent: Object.getOwnPropertyDescriptor(Element.prototype, 'textContent'),

  querySelector: { value: function(selector) {
    // implement in terms of querySelectorAll
    var nodes = this.querySelectorAll(selector);
    return nodes.length ? nodes[0] : null;
  }},
  querySelectorAll: { value: function(selector) {
    // create a context
    var context = Object.create(this);
    // add some methods to the context for zest implementation, without
    // adding them to the public DocumentFragment API
    context.isHTML = true; // in HTML namespace (case-insensitive match)
    context.getElementsByTagName = Element.prototype.getElementsByTagName;
    context.nextElement =
      Object.getOwnPropertyDescriptor(Element.prototype, 'firstElementChild').
      get;
    // invoke zest
    var nodes = select(selector, context);
    return nodes.item ? nodes : new NodeList(nodes);
  }},

  // Utility methods
  clone: { value: function clone() {
      return new DocumentFragment(this.ownerDocument);
  }},
  isEqual: { value: function isEqual(n) {
      // Any two document fragments are shallowly equal.
      // Node.isEqualNode() will test their children for equality
      return true;
  }},

});

},{"./Element":12,"./Node":21,"./NodeList":23,"./select":37}],11:[function(require,module,exports){
module.exports = DocumentType;

var Node = require('./Node');
var Leaf = require('./Leaf');
var utils = require('./utils');

function DocumentType(name, publicId, systemId) {
  // Unlike other nodes, doctype nodes always start off unowned
  // until inserted
  this.nodeType = Node.DOCUMENT_TYPE_NODE;
  this.ownerDocument = null;
  this.name = name;
  this.publicId = publicId || "";
  this.systemId = systemId || "";
}

DocumentType.prototype = Object.create(Leaf.prototype, {
  nodeName: { get: function() { return this.name; }},
  nodeValue: {
    get: function() { return null; },
    set: function() {}
  },

  // Utility methods
  clone: { value: function clone() {
    utils.DataCloneError();
  }},

  isEqual: { value: function isEqual(n) {
    return this.name === n.name &&
      this.publicId === n.publicId &&
      this.systemId === n.systemId;
  }}
});

},{"./Leaf":17,"./Node":21,"./utils":38}],12:[function(require,module,exports){
module.exports = Element;

var xml = require('./xmlnames');
var utils = require('./utils');
var NAMESPACE = utils.NAMESPACE;
var attributes = require('./attributes');
var Node = require('./Node');
var NodeList = require('./NodeList');
var FilteredElementList = require('./FilteredElementList');
var DOMTokenList = require('./DOMTokenList');
var select = require('./select');

function Element(doc, localName, namespaceURI, prefix) {
  this.nodeType = Node.ELEMENT_NODE;
  this.ownerDocument = doc;
  this.localName = localName;
  this.namespaceURI = namespaceURI;
  this.prefix = prefix;

  this.tagName = (prefix !== null) ? prefix + ':' + localName : localName;

  if (namespaceURI !== NAMESPACE.HTML || (!namespaceURI && !doc.isHTML)) this.isHTML = false;

  if (this.isHTML) this.tagName = this.tagName.toUpperCase();

  this.childNodes = new NodeList();

  // These properties maintain the set of attributes
  this._attrsByQName = {}; // The qname->Attr map
  this._attrsByLName = {}; // The ns|lname->Attr map
  this._attrKeys = [];     // attr index -> ns|lname

  this._index = undefined;
}

function recursiveGetText(node, a) {
  if (node.nodeType === Node.TEXT_NODE) {
    a.push(node._data);
  }
  else {
    for(var i = 0, n = node.childNodes.length;  i < n; i++)
      recursiveGetText(node.childNodes[i], a);
  }
}

Element.prototype = Object.create(Node.prototype, {
  nodeName: { get: function() { return this.tagName; }},
  nodeValue: {
    get: function() {
      return null;
    },
    set: function() {}
  },
  textContent: {
    get: function() {
      var strings = [];
      recursiveGetText(this, strings);
      return strings.join('');
    },
    set: function(newtext) {
      this.removeChildren();
      if (newtext !== null && newtext !== '') {
        this._appendChild(this.ownerDocument.createTextNode(newtext));
      }
    }
  },
  innerHTML: {
    get: function() {
      return this.serialize();
    },
    set: utils.nyi
  },
  outerHTML: {
    get: function() {
      // "the attribute must return the result of running the HTML fragment
      // serialization algorithm on a fictional node whose only child is
      // the context object"
      var fictional = {
        childNodes: [ this ],
        nodeType: 0
      };
      return this.serialize.call(fictional);
    },
    set: utils.nyi
  },

  children: { get: function() {
    if (!this._children) {
      this._children = new ChildrenCollection(this);
    }
    return this._children;
  }},

  attributes: { get: function() {
    if (!this._attributes) {
      this._attributes = new AttributesArray(this);
    }
    return this._attributes;
  }},


  firstElementChild: { get: function() {
    var kids = this.childNodes;
    for(var i = 0, n = kids.length; i < n; i++) {
      if (kids[i].nodeType === Node.ELEMENT_NODE) return kids[i];
    }
    return null;
  }},

  lastElementChild: { get: function() {
    var kids = this.childNodes;
    for(var i = kids.length-1; i >= 0; i--) {
      if (kids[i].nodeType === Node.ELEMENT_NODE) return kids[i];
    }
    return null;
  }},

  nextElementSibling: { get: function() {
    if (this.parentNode) {
      var sibs = this.parentNode.childNodes;
      for(var i = this.index+1, n = sibs.length; i < n; i++) {
        if (sibs[i].nodeType === Node.ELEMENT_NODE) return sibs[i];
      }
    }
    return null;
  }},

  previousElementSibling: { get: function() {
    if (this.parentNode) {
      var sibs = this.parentNode.childNodes;
      for(var i = this.index-1; i >= 0; i--) {
        if (sibs[i].nodeType === Node.ELEMENT_NODE) return sibs[i];
      }
    }
    return null;
  }},

  childElementCount: { get: function() {
    return this.children.length;
  }},


  // Return the next element, in source order, after this one or
  // null if there are no more.  If root element is specified,
  // then don't traverse beyond its subtree.
  //
  // This is not a DOM method, but is convenient for
  // lazy traversals of the tree.
  nextElement: { value: function(root) {
    if (!root) root = this.ownerDocument.documentElement;
    var next = this.firstElementChild;
    if (!next) {
      // don't use sibling if we're at root
      if (this===root) return null;
      next = this.nextElementSibling;
    }
    if (next) return next;

    // If we can't go down or across, then we have to go up
    // and across to the parent sibling or another ancestor's
    // sibling.  Be careful, though: if we reach the root
    // element, or if we reach the documentElement, then
    // the traversal ends.
    for(var parent = this.parentElement;
      parent && parent !== root;
      parent = parent.parentElement) {

      next = parent.nextElementSibling;
      if (next) return next;
    }

    return null;
  }},

  // XXX:
  // Tests are currently failing for this function.
  // Awaiting resolution of:
  // http://lists.w3.org/Archives/Public/www-dom/2011JulSep/0016.html
  getElementsByTagName: { value: function getElementsByTagName(lname) {
    var filter;
    if (!lname) return new NodeList();
    if (lname === '*')
      filter = function() { return true };
    else if (this.isHTML)
      filter = htmlLocalNameElementFilter(lname);
    else
      filter = localNameElementFilter(lname);

    return new FilteredElementList(this, filter);
  }},

  getElementsByTagNameNS: { value: function getElementsByTagNameNS(ns, lname){
    var filter;
    if (ns === '*' && lname === '*')
      filter = ftrue;
    else if (ns === '*')
      filter = localNameElementFilter(lname);
    else if (lname === '*')
      filter = namespaceElementFilter(ns);
    else
      filter = namespaceLocalNameElementFilter(ns, lname);

    return new FilteredElementList(this, filter);
  }},

  getElementsByClassName: { value: function getElementsByClassName(names){
    names = names.trim();
    if (names === '') {
      var result = new NodeList(); // Empty node list
      return result;
    }
    names = names.split(/\s+/);  // Split on spaces
    return new FilteredElementList(this, classNamesElementFilter(names));
  }},

  getElementsByName: { value: function getElementsByName(name) {
    return new FilteredElementList(this, elementNameFilter(name));
  }},

  // Overwritten in the constructor if not in the HTML namespace
  isHTML: { value: true },

  // Utility methods used by the public API methods above
  clone: { value: function clone() {
    var e;

    // XXX:
    // Modify this to use the constructor directly or
    // avoid error checking in some other way. In case we try
    // to clone an invalid node that the parser inserted.
    //
    if (this.namespaceURI !== NAMESPACE.HTML || this.prefix)
      e = this.ownerDocument.createElementNS(this.namespaceURI,
                           this.tagName);
    else
      e = this.ownerDocument.createElement(this.localName);

    for(var i = 0, n = this._attrKeys.length; i < n; i++) {
      var lname = this._attrKeys[i];
      var a = this._attrsByLName[lname];
      var b = new Attr(e, a.localName, a.prefix, a.namespaceURI);
      b.data = a.data;
      e._attrsByLName[lname] = b;
      e._addQName(b);
    }
    e._attrKeys = this._attrKeys.concat();

    return e;
  }},

  isEqual: { value: function isEqual(that) {
    if (this.localName !== that.localName ||
      this.namespaceURI !== that.namespaceURI ||
      this.prefix !== that.prefix ||
      this._numattrs !== that._numattrs)
      return false;

    // Compare the sets of attributes, ignoring order
    // and ignoring attribute prefixes.
    for(var i = 0, n = this._numattrs; i < n; i++) {
      var a = this._attr(i);
      if (!that.hasAttributeNS(a.namespaceURI, a.localName))
        return false;
      if (that.getAttributeNS(a.namespaceURI,a.localName) !== a.value)
        return false;
    }

    return true;
  }},

  // This is the 'locate a namespace prefix' algorithm from the
  // DOMCore specification.  It is used by Node.lookupPrefix()
  locateNamespacePrefix: { value: function locateNamespacePrefix(ns) {
    if (this.namespaceURI === ns && this.prefix !== null)
      return this.prefix;

    for(var i = 0, n = this._numattrs; i < n; i++) {
      var a = this._attr(i);
      if (a.prefix === 'xmlns' && a.value === ns)
        return a.localName;
    }

    var parent = this.parentElement;
    return parent ? parent.locateNamespacePrefix(ns) : null;
  }},

  // This is the 'locate a namespace' algorithm for Element nodes
  // from the DOM Core spec.  It is used by Node.lookupNamespaceURI
  locateNamespace: { value: function locateNamespace(prefix) {
    if (this.prefix === prefix && this.namespaceURI !== null)
      return this.namespaceURI;

    for(var i = 0, n = this._numattrs; i < n; i++) {
      var a = this._attr(i);
      if ((a.prefix === 'xmlns' && a.localName === prefix) ||
        (a.prefix === null && a.localName === 'xmlns')) {
        return a.value || null;
      }
    }

    var parent = this.parentElement;
    return parent ? parent.locateNamespace(prefix) : null;
  }},

  //
  // Attribute handling methods and utilities
  //

  /*
   * Attributes in the DOM are tricky:
   *
   * - there are the 8 basic get/set/has/removeAttribute{NS} methods
   *
   * - but many HTML attributes are also 'reflected' through IDL
   *   attributes which means that they can be queried and set through
   *   regular properties of the element.  There is just one attribute
   *   value, but two ways to get and set it.
   *
   * - Different HTML element types have different sets of reflected
     attributes.
   *
   * - attributes can also be queried and set through the .attributes
   *   property of an element.  This property behaves like an array of
   *   Attr objects.  The value property of each Attr is writeable, so
   *   this is a third way to read and write attributes.
   *
   * - for efficiency, we really want to store attributes in some kind
   *   of name->attr map.  But the attributes[] array is an array, not a
   *   map, which is kind of unnatural.
   *
   * - When using namespaces and prefixes, and mixing the NS methods
   *   with the non-NS methods, it is apparently actually possible for
   *   an attributes[] array to have more than one attribute with the
   *   same qualified name.  And certain methods must operate on only
   *   the first attribute with such a name.  So for these methods, an
   *   inefficient array-like data structure would be easier to
   *   implement.
   *
   * - The attributes[] array is live, not a snapshot, so changes to the
   *   attributes must be immediately visible through existing arrays.
   *
   * - When attributes are queried and set through IDL properties
   *   (instead of the get/setAttributes() method or the attributes[]
   *   array) they may be subject to type conversions, URL
   *   normalization, etc., so some extra processing is required in that
   *   case.
   *
   * - But access through IDL properties is probably the most common
   *   case, so we'd like that to be as fast as possible.
   *
   * - We can't just store attribute values in their parsed idl form,
   *   because setAttribute() has to return whatever string is passed to
   *   getAttribute even if it is not a legal, parseable value. So
   *   attribute values must be stored in unparsed string form.
   *
   * - We need to be able to send change notifications or mutation
   *   events of some sort to the renderer whenever an attribute value
   *   changes, regardless of the way in which it changes.
   *
   * - Some attributes, such as id and class affect other parts of the
   *   DOM API, like getElementById and getElementsByClassName and so
   *   for efficiency, we need to specially track changes to these
   *   special attributes.
   *
   * - Some attributes like class have different names (className) when
   *   reflected.
   *
   * - Attributes whose names begin with the string 'data-' are treated
     specially.
   *
   * - Reflected attributes that have a boolean type in IDL have special
   *   behavior: setting them to false (in IDL) is the same as removing
   *   them with removeAttribute()
   *
   * - numeric attributes (like HTMLElement.tabIndex) can have default
   *   values that must be returned by the idl getter even if the
   *   content attribute does not exist. (The default tabIndex value
   *   actually varies based on the type of the element, so that is a
   *   tricky one).
   *
   * See
   * http://www.whatwg.org/specs/web-apps/current-work/multipage/urls.html#reflect
   * for rules on how attributes are reflected.
   *
   */

  getAttribute: { value: function getAttribute(qname) {
    if (this.isHTML) qname = qname.toLowerCase();
    var attr = this._attrsByQName[qname];
    if (!attr) return null;

    if (Array.isArray(attr))  // If there is more than one
      attr = attr[0];         // use the first

    return attr.value;
  }},

  getAttributeNS: { value: function getAttributeNS(ns, lname) {
    var attr = this._attrsByLName[ns + '|' + lname];
    return attr ? attr.value : null;
  }},

  hasAttribute: { value: function hasAttribute(qname) {
    if (this.isHTML) qname = qname.toLowerCase();
    return qname in this._attrsByQName;
  }},

  hasAttributeNS: { value: function hasAttributeNS(ns, lname) {
    var key = ns + '|' + lname;
    return key in this._attrsByLName;
  }},

  // Set the attribute without error checking. The parser uses this.
  _setAttribute: { value: function _setAttribute(qname, value) {
    // XXX: the spec says that this next search should be done
    // on the local name, but I think that is an error.
    // email pending on www-dom about it.
    var attr = this._attrsByQName[qname];
    var isnew;
    if (!attr) {
      attr = this._newattr(qname);
      isnew = true;
    }
    else {
      if (Array.isArray(attr)) attr = attr[0];
    }

    // Now set the attribute value on the new or existing Attr object.
    // The Attr.value setter method handles mutation events, etc.
    attr.value = value;
    if (this._attributes) this._attributes[qname] = attr;
    if (isnew && this._newattrhook) this._newattrhook(qname, value);
  }},

  // Check for errors, and then set the attribute
  setAttribute: {value: function setAttribute(qname, value) {
    if (!xml.isValidName(qname)) utils.InvalidCharacterError();
    if (this.isHTML) qname = qname.toLowerCase();
    if (qname.substring(0, 5) === 'xmlns') utils.NamespaceError();
    this._setAttribute(qname, value);
  }},


  // The version with no error checking used by the parser
  _setAttributeNS: { value: function _setAttributeNS(ns, qname, value) {
    var pos = qname.indexOf(':'), prefix, lname;
    if (pos === -1) {
      prefix = null;
      lname = qname;
    }
    else {
      prefix = qname.substring(0, pos);
      lname = qname.substring(pos+1);
    }

    var key = ns + '|' + lname;
    if (ns === '') ns = null;

    var attr = this._attrsByLName[key];
    var isnew;
    if (!attr) {
      attr = new Attr(this, lname, prefix, ns);
      isnew = true;
      this._attrsByLName[key] = attr;
      this._attrKeys.push(key);

      // We also have to make the attr searchable by qname.
      // But we have to be careful because there may already
      // be an attr with this qname.
      this._addQName(attr);
    }
    else {
      // Calling setAttributeNS() can change the prefix of an
      // existing attribute!
      if (attr.prefix !== prefix) {
        // Unbind the old qname
        this._removeQName(attr);
        // Update the prefix
        attr.prefix = prefix;
        // Bind the new qname
        this._addQName(attr);

      }

    }
    attr.value = value; // Automatically sends mutation event
    if (isnew && this._newattrhook) this._newattrhook(qname, value);
  }},

  // Do error checking then call _setAttributeNS
  setAttributeNS: { value: function setAttributeNS(ns, qname, value) {
    if (!xml.isValidName(qname)) utils.InvalidCharacterError();
    if (!xml.isValidQName(qname)) utils.NamespaceError();

    var pos = qname.indexOf(':');
    var prefix = (pos === -1) ? null : qname.substring(0, pos);
    if (ns === '') ns = null;

    if ((prefix !== null && ns === null) ||
      (prefix === 'xml' && ns !== NAMESPACE.XML) ||
      ((qname === 'xmlns' || prefix === 'xmlns') &&
       (ns !== NAMESPACE.XMLNS)) ||
      (ns === NAMESPACE.XMLNS &&
       !(qname === 'xmlns' || prefix === 'xmlns')))
      utils.NamespaceError();

    this._setAttributeNS(ns, qname, value);
  }},

  removeAttribute: { value: function removeAttribute(qname) {
    if (this.isHTML) qname = qname.toLowerCase();

    var attr = this._attrsByQName[qname];
    if (!attr) return;

    // If there is more than one match for this qname
    // so don't delete the qname mapping, just remove the first
    // element from it.
    if (Array.isArray(attr)) {
      if (attr.length > 2) {
        attr = attr.shift();  // remove it from the array
      }
      else {
        this._attrsByQName[qname] = attr[1];
        attr = attr[0];
      }
    }
    else {
      // only a single match, so remove the qname mapping
      this._attrsByQName[qname] = undefined;
    }

    // Now attr is the removed attribute.  Figure out its
    // ns+lname key and remove it from the other mapping as well.
    var key = (attr.namespaceURI || '') + '|' + attr.localName;
    this._attrsByLName[key] = undefined;

    var i = this._attrKeys.indexOf(key);
    this._attrKeys.splice(i, 1);

    if (this._attributes)
      this._attributes[qname] = undefined

    // Onchange handler for the attribute
    if (attr.onchange)
      attr.onchange(this, attr.localName, attr.value, null);

    // Mutation event
    if (this.rooted) this.ownerDocument.mutateRemoveAttr(attr);
  }},

  removeAttributeNS: { value: function removeAttributeNS(ns, lname) {
    var key = (ns || '') + '|' + lname;
    var attr = this._attrsByLName[key];
    if (!attr) return;

    this._attrsByLName[key] = undefined;

    var i = this._attrKeys.indexOf(key);
    this._attrKeys.splice(i, 1);

    // Now find the same Attr object in the qname mapping and remove it
    // But be careful because there may be more than one match.
    this._removeQName(attr);

    // Onchange handler for the attribute
    if (attr.onchange)
      attr.onchange(this, attr.localName, attr.value, null);
    // Mutation event
    if (this.rooted) this.ownerDocument.mutateRemoveAttr(attr);
  }},

  // This 'raw' version of getAttribute is used by the getter functions
  // of reflected attributes. It skips some error checking and
  // namespace steps
  _getattr: { value: function _getattr(qname) {
    // Assume that qname is already lowercased, so don't do it here.
    // Also don't check whether attr is an array: a qname with no
    // prefix will never have two matching Attr objects (because
    // setAttributeNS doesn't allow a non-null namespace with a
    // null prefix.
    var attr = this._attrsByQName[qname];
    return attr ? attr.value : null;
  }},

  // The raw version of setAttribute for reflected idl attributes.
  _setattr: { value: function _setattr(qname, value) {
    var attr = this._attrsByQName[qname];
    var isnew;
    if (!attr) {
      attr = this._newattr(qname);
      isnew = true;
    }
    attr.value = value;
    if (this._attributes) this._attributes[qname] = attr;
    if (isnew && this._newattrhook) this._newattrhook(qname, value);
  }},

  // Create a new Attr object, insert it, and return it.
  // Used by setAttribute() and by set()
  _newattr: { value: function _newattr(qname) {
    var attr = new Attr(this, qname);
    var key = '|' + qname;
    this._attrsByQName[qname] = attr;
    this._attrsByLName[key] = attr;
    this._attrKeys.push(key);
    return attr;
  }},

  // Add a qname->Attr mapping to the _attrsByQName object, taking into
  // account that there may be more than one attr object with the
  // same qname
  _addQName: { value: function(attr) {
    var qname = attr.name;
    var existing = this._attrsByQName[qname];
    if (!existing) {
      this._attrsByQName[qname] = attr;
    }
    else if (Array.isArray(existing)) {
      push(existing, attr);
    }
    else {
      this._attrsByQName[qname] = [existing, attr];
    }
    if (this._attributes) this._attributes[qname] = attr;
  }},

  // Remove a qname->Attr mapping to the _attrsByQName object, taking into
  // account that there may be more than one attr object with the
  // same qname
  _removeQName: { value: function(attr) {
    var qname = attr.name;
    var target = this._attrsByQName[qname];

    if (Array.isArray(target)) {
      var idx = target.indexOf(attr);
      assert(idx !== -1); // It must be here somewhere
      if (target.length === 2) {
        this._attrsByQName[qname] = target[1-idx];
      }
      else {
        target.splice(idx, 1);
      }
    }
    else {
      assert(target === attr);  // If only one, it must match
      this._attrsByQName[qname] = undefined;
    }
  }},

  // Return the number of attributes
  _numattrs: { get: function() { return this._attrKeys.length; }},
  // Return the nth Attr object
  _attr: { value: function(n) {
    return this._attrsByLName[this._attrKeys[n]];
  }},

  // Define getters and setters for an 'id' property that reflects
  // the content attribute 'id'.
  id: attributes.property({name: 'id'}),

  // Define getters and setters for a 'className' property that reflects
  // the content attribute 'class'.
  className: attributes.property({name: 'class'}),

  classList: { get: function() {
    var self = this;
    if (this._classList) {
      return this._classList;
    }
    var dtlist = new DOMTokenList(
      function() {
        return self.className || "";
      },
      function(v) {
        self.className = v;
      }
    );
    this._classList = dtlist;
    return dtlist;
  }},

  querySelector: { value: function(selector) {
    return select(selector, this)[0];
  }},

  querySelectorAll: { value: function(selector) {
    var nodes = select(selector, this);
    return nodes.item ? nodes : new NodeList(nodes);
  }}

});

// Register special handling for the id attribute
attributes.registerChangeHandler(Element, 'id',
 function(element, lname, oldval, newval) {
   if (element.rooted) {
     if (oldval) {
       element.ownerDocument.delId(oldval, element);
     }
     if (newval) {
       element.ownerDocument.addId(newval, element);
     }
   }
 }
);


// The Attr class represents a single attribute.  The values in
// _attrsByQName and _attrsByLName are instances of this class.
function Attr(elt, lname, prefix, namespace) {
  // Always remember what element we're associated with.
  // We need this to property handle mutations
  this.ownerElement = elt;

  if (!namespace && !prefix && elt._attributeChangeHandlers[lname])
    this.onchange = elt._attributeChangeHandlers[lname];

  // localName and namespace are constant for any attr object.
  // But value may change.  And so can prefix, and so, therefore can name.
  this.localName = lname;
  this.prefix = prefix || null;
  this.namespaceURI = namespace || null;
}

Attr.prototype = {
  get name() {
    return this.prefix ? this.prefix + ':' + this.localName : this.localName;
  },

  get value() {
    return this.data;
  },

  get specified() {
    // Deprecated
    return true;
  },

  set value(value) {
    var oldval = this.data;
    value = (value === undefined) ? '' : value + '';
    if (value === oldval) return;

    this.data = value;

    // Run the onchange hook for the attribute
    // if there is one.
    if (this.onchange)
      this.onchange(this.ownerElement,this.localName, oldval, value);

    // Generate a mutation event if the element is rooted
    if (this.ownerElement.rooted)
      this.ownerElement.ownerDocument.mutateAttr(this, oldval);
  }
};


// The attributes property of an Element will be an instance of this class.
// This class is really just a dummy, though. It only defines a length
// property and an item() method. The AttrArrayProxy that
// defines the public API just uses the Element object itself.
function AttributesArray(elt) {
  this.element = elt;
  for (var name in elt._attrsByQName) {
    this[name] = elt._attrsByQName[name]
  }
}
AttributesArray.prototype = {
  get length() {
    return this.element._attrKeys.length;
  },
  item: function(n) {
    return this.element._attrsByLName[this.element._attrKeys[n]];
  }
};


// The children property of an Element will be an instance of this class.
// It defines length, item() and namedItem() and will be wrapped by an
// HTMLCollection when exposed through the DOM.
function ChildrenCollection(e) {
  this.element = e;
  this.updateCache();
}

ChildrenCollection.prototype = {
  get length() {
    this.updateCache();
    return this.childrenByNumber.length;
  },
  item: function item(n) {
    this.updateCache();
    return this.childrenByNumber[n] || null;
  },

  namedItem: function namedItem(name) {
    this.updateCache();
    return this.childrenByName[name] || null;
  },

  // This attribute returns the entire name->element map.
  // It is not part of the HTMLCollection API, but we need it in
  // src/HTMLCollectionProxy
  get namedItems() {
    this.updateCache();
    return this.childrenByName;
  },

  updateCache: function updateCache() {
    var namedElts = /^(a|applet|area|embed|form|frame|frameset|iframe|img|object)$/;
    if (this.lastModTime !== this.element.lastModTime) {
      this.lastModTime = this.element.lastModTime;

      var n = this.childrenByNumber && this.childrenByNumber.length || 0;
      for(var i = 0; i < n; i++) {
        this[i] = undefined;
      }

      this.childrenByNumber = [];
      this.childrenByName = {};

      for(i = 0, n = this.element.childNodes.length; i < n; i++) {
        var c = this.element.childNodes[i];
        if (c.nodeType == Node.ELEMENT_NODE) {

          this[this.childrenByNumber.length] = c;
          this.childrenByNumber.push(c);

          // XXX Are there any requirements about the namespace
          // of the id property?
          var id = c.getAttribute('id');

          // If there is an id that is not already in use...
          if (id && !this.childrenByName[id])
            this.childrenByName[id] = c;

          // For certain HTML elements we check the name attribute
          var name = c.getAttribute('name');
          if (name &&
            this.element.namespaceURI === NAMESPACE.HTML &&
            namedElts.test(this.element.localName) &&
            !this.childrenByName[name])
            this.childrenByName[id] = c;
        }
      }
    }
  }
};

// These functions return predicates for filtering elements.
// They're used by the Document and Element classes for methods like
// getElementsByTagName and getElementsByClassName

function localNameElementFilter(lname) {
  return function(e) { return e.localName === lname; };
}

function htmlLocalNameElementFilter(lname) {
  var lclname = lname.toLowerCase();
  if (lclname === lname)
    return localNameElementFilter(lname);

  return function(e) {
    return e.isHTML ? e.localName === lclname : e.localName === lname;
  };
}

function namespaceElementFilter(ns) {
  return function(e) { return e.namespaceURI === ns; };
}

function namespaceLocalNameElementFilter(ns, lname) {
  return function(e) {
    return e.namespaceURI === ns && e.localName === lname;
  };
}

// XXX
// Optimize this when I implement classList.
function classNamesElementFilter(names) {
  return function(e) {
    var classAttr = e.getAttribute('class');
    if (!classAttr) return false;
    var classes = classAttr.trim().split(/\s+/);
    return names.every(function(n) {
      return classes.indexOf(n) !== -1;
    });
  };
}

function elementNameFilter(name) {
  return function(e) {
    return e.getAttribute('name') === name;
  };
}

},{"./DOMTokenList":8,"./FilteredElementList":15,"./Node":21,"./NodeList":23,"./attributes":31,"./select":37,"./utils":38,"./xmlnames":39}],13:[function(require,module,exports){
module.exports = Event;

Event.CAPTURING_PHASE = 1;
Event.AT_TARGET = 2;
Event.BUBBLING_PHASE = 3;

function Event(type, dictionary) {
  // Initialize basic event properties
  this.type = '';
  this.target = null;
  this.currentTarget = null;
  this.eventPhase = Event.AT_TARGET;
  this.bubbles = false;
  this.cancelable = false;
  this.isTrusted = false;
  this.defaultPrevented = false;
  this.timeStamp = Date.now();

  // Initialize internal flags
  // XXX: Would it be better to inherit these defaults from the prototype?
  this._propagationStopped = false;
  this._immediatePropagationStopped = false;
  this._initialized = true;
  this._dispatching = false;

  // Now initialize based on the constructor arguments (if any)
  if (type) this.type = type;
  if (dictionary) {
    for(var p in dictionary) {
      this[p] = dictionary[p];
    }
  }
}

Event.prototype = Object.create(Object.prototype, {
  constructor: { value: Event },
  stopPropagation: { value: function stopPropagation() {
    this._propagationStopped = true;
  }},

  stopImmediatePropagation: { value: function stopImmediatePropagation() {
    this._propagationStopped = true;
    this._immediatePropagationStopped = true;
  }},

  preventDefault: { value: function preventDefault() {
    if (this.cancelable) this.defaultPrevented = true;
  }},

  initEvent: { value: function initEvent(type, bubbles, cancelable) {
    this._initialized = true;
    if (this._dispatching) return;

    this._propagationStopped = false;
    this._immediatePropagationStopped = false;
    this.defaultPrevented = false;
    this.isTrusted = false;

    this.target = null;
    this.type = type;
    this.bubbles = bubbles;
    this.cancelable = cancelable;
  }},

});

},{}],14:[function(require,module,exports){
var Event = require('./Event');
var MouseEvent = require('./MouseEvent');
var utils = require('./utils');

module.exports = EventTarget;

function EventTarget() {}

EventTarget.prototype = {
  // XXX
  // See WebIDL §4.8 for details on object event handlers
  // and how they should behave.  We actually have to accept
  // any object to addEventListener... Can't type check it.
  // on registration.

  // XXX:
  // Capturing event listeners are sort of rare.  I think I can optimize
  // them so that dispatchEvent can skip the capturing phase (or much of
  // it).  Each time a capturing listener is added, increment a flag on
  // the target node and each of its ancestors.  Decrement when removed.
  // And update the counter when nodes are added and removed from the
  // tree as well.  Then, in dispatch event, the capturing phase can
  // abort if it sees any node with a zero count.
  addEventListener: function addEventListener(type, listener, capture) {
    if (!listener) return;
    if (capture === undefined) capture = false;
    if (!this._listeners) this._listeners = {};
    if (!this._listeners[type]) this._listeners[type] = [];
    var list = this._listeners[type];

    // If this listener has already been registered, just return
    for(var i = 0, n = list.length; i < n; i++) {
      var l = list[i];
      if (l.listener === listener && l.capture === capture)
        return;
    }

    // Add an object to the list of listeners
    var obj = { listener: listener, capture: capture };
    if (typeof listener === 'function') obj.f = listener;
    list.push(obj);
  },

  removeEventListener: function removeEventListener(type,
                            listener,
                            capture) {
    if (capture === undefined) capture = false;
    if (this._listeners) {
      var list = this._listeners[type];
      if (list) {
        // Find the listener in the list and remove it
        for(var i = 0, n = list.length; i < n; i++) {
          var l = list[i];
          if (l.listener === listener && l.capture === capture) {
            if (list.length === 1) {
              this._listeners[type] = undefined;
            }
            else {
              list.splice(i, 1);
            }
            return;
          }
        }
      }
    }
  },

  // This is the public API for dispatching untrusted public events.
  // See _dispatchEvent for the implementation
  dispatchEvent: function dispatchEvent(event) {
    // Dispatch an untrusted event
    return this._dispatchEvent(event, false);
  },

  //
  // See DOMCore §4.4
  // XXX: I'll probably need another version of this method for
  // internal use, one that does not set isTrusted to false.
  // XXX: see Document._dispatchEvent: perhaps that and this could
  // call a common internal function with different settings of
  // a trusted boolean argument
  //
  // XXX:
  // The spec has changed in how to deal with handlers registered
  // on idl or content attributes rather than with addEventListener.
  // Used to say that they always ran first.  That's how webkit does it
  // Spec now says that they run in a position determined by
  // when they were first set.  FF does it that way.  See:
  // http://www.whatwg.org/specs/web-apps/current-work/multipage/webappapis.html#event-handlers
  //
  _dispatchEvent: function _dispatchEvent(event, trusted) {
    if (typeof trusted !== 'boolean') trusted = false;
    function invoke(target, event) {
      var type = event.type, phase = event.eventPhase;
      event.currentTarget = target;

      // If there was an individual handler defined, invoke it first
      // XXX: see comment above: this shouldn't always be first.
      if (phase !== Event.CAPTURING_PHASE &&
        target._handlers && target._handlers[type])
      {
        var handler = target._handlers[type];
        var rv;
        if (typeof handler === 'function') {
          rv=handler.call(event.currentTarget, event);
        }
        else {
          var f = handler.handleEvent;
          if (typeof f !== 'function')
            throw TypeError('handleEvent property of ' +
                    'event handler object is' +
                    'not a function.');
          rv=f.call(handler, event);
        }

        switch(event.type) {
        case 'mouseover':
          if (rv === true)  // Historical baggage
            event.preventDefault();
          break;
        case 'beforeunload':
          // XXX: eventually we need a special case here
        default:
          if (rv === false)
            event.preventDefault();
          break;
        }
      }

      // Now invoke list list of listeners for this target and type
      var list = target._listeners && target._listeners[type];
      if (!list) return;
      list = list.slice();
      for(var i = 0, n = list.length; i < n; i++) {
        if (event._stopImmediatePropagation) return;
        var l = list[i];
        if ((phase === Event.CAPTURING_PHASE && !l.capture) ||
          (phase === Event.BUBBLING_PHASE && l.capture))
          continue;
        if (l.f) {
          l.f.call(event.currentTarget, event);
        }
        else {
          var fn = l.listener.handleEvent;
          if (typeof fn !== 'function')
            throw TypeError('handleEvent property of event listener object is not a function.');
          fn.call(l.listener, event);
        }
      }
    }

    if (!event._initialized || event._dispatching) utils.InvalidStateError();
    event.isTrusted = trusted;

    // Begin dispatching the event now
    event._dispatching = true;
    event.target = this;

    // Build the list of targets for the capturing and bubbling phases
    // XXX: we'll eventually have to add Window to this list.
    var ancestors = [];
    for(var n = this.parentNode; n; n = n.parentNode)
      ancestors.push(n);

    // Capturing phase
    event.eventPhase = Event.CAPTURING_PHASE;
    for(var i = ancestors.length-1; i >= 0; i--) {
      invoke(ancestors[i], event);
      if (event._propagationStopped) break;
    }

    // At target phase
    if (!event._propagationStopped) {
      event.eventPhase = Event.AT_TARGET;
      invoke(this, event);
    }

    // Bubbling phase
    if (event.bubbles && !event._propagationStopped) {
      event.eventPhase = Event.BUBBLING_PHASE;
      for(var i = 0, n = ancestors.length; i < n; i++) {
        invoke(ancestors[i], event);
        if (event._propagationStopped) break;
      }
    }

    event._dispatching = false;
    event.eventPhase = Event.AT_TARGET;
    event.currentTarget = null;

    // Deal with mouse events and figure out when
    // a click has happened
    if (trusted && !event.defaultPrevented && event instanceof MouseEvent) {
      switch(event.type) {
      case 'mousedown':
        this._armed = {
          x: event.clientX,
          y: event.clientY,
          t: event.timeStamp
        };
        break;
      case 'mouseout':
      case 'mouseover':
        this._armed = null;
        break;
      case 'mouseup':
        if (this._isClick(event)) this._doClick(event);
        this._armed = null;
        break;
      }
    }



    return !event.defaultPrevented;
  },

  // Determine whether a click occurred
  // XXX We don't support double clicks for now
  _isClick: function(event) {
    return (this._armed !== null &&
        event.type === 'mouseup' &&
        event.isTrusted &&
        event.button === 0 &&
        event.timeStamp - this._armed.t < 1000 &&
        Math.abs(event.clientX - this._armed.x) < 10 &&
        Math.abs(event.clientY - this._armed.Y) < 10);
  },

  // Clicks are handled like this:
  // http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#interactive-content-0
  //
  // Note that this method is similar to the HTMLElement.click() method
  // The event argument must be the trusted mouseup event
  _doClick: function(event) {
    if (this._click_in_progress) return;
    this._click_in_progress = true;

    // Find the nearest enclosing element that is activatable
    // An element is activatable if it has a
    // _post_click_activation_steps hook
    var activated = this;
    while(activated && !activated._post_click_activation_steps)
      activated = activated.parentNode;

    if (activated && activated._pre_click_activation_steps) {
      activated._pre_click_activation_steps();
    }

    var click = this.ownerDocument.createEvent('MouseEvent');
    click.initMouseEvent('click', true, true,
      this.ownerDocument.defaultView, 1,
      event.screenX, event.screenY,
      event.clientX, event.clientY,
      event.ctrlKey, event.altKey,
      event.shiftKey, event.metaKey,
      event.button, null);

    var result = this._dispatchEvent(click, true);

    if (activated) {
      if (result) {
        // This is where hyperlinks get followed, for example.
        if (activated._post_click_activation_steps)
          activated._post_click_activation_steps(click);
      }
      else {
        if (activated._cancelled_activation_steps)
          activated._cancelled_activation_steps();
      }
    }
  },

  //
  // An event handler is like an event listener, but it registered
  // by setting an IDL or content attribute like onload or onclick.
  // There can only be one of these at a time for any event type.
  // This is an internal method for the attribute accessors and
  // content attribute handlers that need to register events handlers.
  // The type argument is the same as in addEventListener().
  // The handler argument is the same as listeners in addEventListener:
  // it can be a function or an object. Pass null to remove any existing
  // handler.  Handlers are always invoked before any listeners of
  // the same type.  They are not invoked during the capturing phase
  // of event dispatch.
  //
  _setEventHandler: function _setEventHandler(type, handler) {
    if (!this._handlers) this._handlers = {};
    this._handlers[type] = handler;
  },

  _getEventHandler: function _getEventHandler(type) {
    return (this._handlers && this._handlers[type]) || null;
  }

};

},{"./Event":13,"./MouseEvent":19,"./utils":38}],15:[function(require,module,exports){
module.exports = FilteredElementList;

var Node = require('./Node');

//
// This file defines node list implementation that lazily traverses
// the document tree (or a subtree rooted at any element) and includes
// only those elements for which a specified filter function returns true.
// It is used to implement the
// {Document,Element}.getElementsBy{TagName,ClassName}{,NS} methods.
//

function FilteredElementList(root, filter) {
  this.root = root;
  this.filter = filter;
  this.lastModTime = root.lastModTime;
  this.done = false;
  this.cache = [];
  this.traverse();
}

FilteredElementList.prototype = {
  get length() {
    this.checkcache();
    if (!this.done) this.traverse();
    return this.cache.length;
  },

  item: function(n) {
    this.checkcache();
    if (!this.done && n >= this.cache.length) this.traverse(n);
    return this.cache[n];
  },

  checkcache: function() {
    if (this.lastModTime !== this.root.lastModTime) {
      // subtree has changed, so invalidate cache
      for (var i = this.cache.length-1; i>=0; i--) {
        this[i] = undefined;
      }
      this.cache.length = 0;
      this.done = false;
      this.lastModTime = this.root.lastModTime;
    }
  },

  // If n is specified, then traverse the tree until we've found the nth
  // item (or until we've found all items).  If n is not specified,
  // traverse until we've found all items.
  traverse: function(n) {
    // increment n so we can compare to length, and so it is never falsy
    if (n !== undefined) n++;

    var elt;
    while(elt = this.next()) {
      this[this.cache.length] = elt; //XXX Use proxy instead
      this.cache.push(elt);
      if (n && this.cache.length === n) return;
    }

    // no next element, so we've found everything
    this.done = true;
  },

  // Return the next element under root that matches filter
  next: function() {
    var start = (this.cache.length === 0) ? this.root // Start at the root or at
      : this.cache[this.cache.length-1]; // the last element we found

    var elt;
    if (start.nodeType === Node.DOCUMENT_NODE)
      elt = start.documentElement;
    else
      elt = start.nextElement(this.root);

    while(elt) {
      if (this.filter(elt)) {
        return elt;
      }

      elt = elt.nextElement(this.root);
    }
    return null;
  }
};

},{"./Node":21}],16:[function(require,module,exports){
module.exports = HTMLParser;

var Document = require('./Document');
var DocumentType = require('./DocumentType');
var Node = require('./Node');
var NAMESPACE = require('./utils').NAMESPACE;
var html = require('./htmlelts');
var impl = html.elements;

var pushAll = Function.prototype.apply.bind(Array.prototype.push);

/*
 * This file contains an implementation of the HTML parsing algorithm.
 * The algorithm and the implementation are complex because HTML
 * explicitly defines how the parser should behave for all possible
 * valid and invalid inputs.
 *
 * Usage:
 *
 * The file defines a single HTMLParser() function, which dom.js exposes
 * publicly as document.implementation.mozHTMLParser(). This is a
 * factory function, not a constructor.
 *
 * When you call document.implementation.mozHTMLParser(), it returns
 * an object that has parse() and document() methods. To parse HTML text,
 * pass the text (in one or more chunks) to the parse() method.  When
 * you've passed all the text (on the last chunk, or afterward) pass
 * true as the second argument to parse() to tell the parser that there
 * is no more coming. Call document() to get the document object that
 * the parser is parsing into.  You can call this at any time, before
 * or after calling parse().
 *
 * The first argument to mozHTMLParser is the absolute URL of the document.
 *
 * The second argument is optional and is for internal use only.  Pass an
 * element as the fragmentContext to do innerHTML parsing for the
 * element.  To do innerHTML parsing on a document, pass null. Otherwise,
 * omit the 2nd argument. See HTMLElement.innerHTML for an example.  Note
 * that if you pass a context element, the end() method will return an
 * unwrapped document instead of a wrapped one.
 *
 * Implementation details:
 *
 * This is a long file of almost 7000 lines. It is structured as one
 * big function nested within another big function.  The outer
 * function defines a bunch of constant data, utility functions
 * that use that data, and a couple of classes used by the parser.
 * The outer function also defines and returns the
 * inner function. This inner function is the HTMLParser factory
 * function that implements the parser and holds all the parser state
 * as local variables.  The HTMLParser function is quite big because
 * it defines many nested functions that use those local variables.
 *
 * There are three tightly coupled parser stages: a scanner, a
 * tokenizer and a tree builder. In a (possibly misguided) attempt at
 * efficiency, the stages are not implemented as separate classes:
 * everything shares state and is (mostly) implemented in imperative
 * (rather than OO) style.
 *
 * The stages of the parser work like this: When the client code calls
 * the parser's parse() method, the specified string is passed to
 * scanChars(). The scanner loops through that string and passes characters
 * (sometimes one at a time, sometimes in chunks) to the tokenizer stage.
 * The tokenizer groups the characters into tokens: tags, endtags, runs
 * of text, comments, doctype declarations, and the end-of-file (EOF)
 * token.  These tokens are then passed to the tree building stage via
 * the insertToken() function.  The tree building stage builds up the
 * document tree.
 *
 * The tokenizer stage is a finite state machine.  Each state is
 * implemented as a function with a name that ends in "_state".  The
 * initial state is data_state(). The current tokenizer state is stored
 * in the variable 'tokenizer'.  Most state functions expect a single
 * integer argument which represents a single UTF-16 codepoint.  Some
 * states want more characters and set a lookahead property on
 * themselves.  The scanChars() function in the scanner checks for this
 * lookahead property.  If it doesn't exist, then scanChars() just passes
 * the next input character to the current tokenizer state function.
 * Otherwise, scanChars() looks ahead (a given # of characters, or for a
 * matching string, or for a matching regexp) and passes a string of
 * characters to the current tokenizer state function.
 *
 * As a shortcut, certain states of the tokenizer use regular expressions
 * to look ahead in the scanner's input buffer for runs of text, simple
 * tags and attributes.  For well-formed input, these shortcuts skip a
 * lot of state transitions and speed things up a bit.
 *
 * When a tokenizer state function has consumed a complete token, it
 * emits that token, by calling insertToken(), or by calling a utility
 * function that itself calls insertToken().  These tokens are passed to
 * the tree building stage, which is also a state machine.  Like the
 * tokenizer, the tree building states are implemented as functions, and
 * these functions have names that end with _mode (because the HTML spec
 * refers to them as insertion modes). The current insertion mode is held
 * by the 'parser' variable.  Each insertion mode function takes up to 4
 * arguments.  The first is a token type, represented by the constants
 * TAG, ENDTAG, TEXT, COMMENT, DOCTYPE and EOF.  The second argument is
 * the value of the token: the text or comment data, or tagname or
 * doctype.  For tags, the 3rd argument is an array of attributes.  For
 * DOCTYPES it is the optional public id.  For tags, the 4th argument is
 * true if the tag is self-closing. For doctypes, the 4th argument is the
 * optional system id.
 *
 * Search for "***" to find the major sub-divisions in the code.
 */


/***
 * Data prolog.  Lots of constants declared here, including some
 * very large objects.  They're used throughout the code that follows
 */
// Token types for the tree builder.
var EOF = -1;
var TEXT = 1;
var TAG = 2;
var ENDTAG = 3;
var COMMENT = 4;
var DOCTYPE = 5;

// A re-usable empty array
var NOATTRS = [];

// These DTD public ids put the browser in quirks mode
var quirkyPublicIds = /^HTML$|^-\/\/W3O\/\/DTD W3 HTML Strict 3\.0\/\/EN\/\/$|^-\/W3C\/DTD HTML 4\.0 Transitional\/EN$|^\+\/\/Silmaril\/\/dtd html Pro v0r11 19970101\/\/|^-\/\/AdvaSoft Ltd\/\/DTD HTML 3\.0 asWedit \+ extensions\/\/|^-\/\/AS\/\/DTD HTML 3\.0 asWedit \+ extensions\/\/|^-\/\/IETF\/\/DTD HTML 2\.0 Level 1\/\/|^-\/\/IETF\/\/DTD HTML 2\.0 Level 2\/\/|^-\/\/IETF\/\/DTD HTML 2\.0 Strict Level 1\/\/|^-\/\/IETF\/\/DTD HTML 2\.0 Strict Level 2\/\/|^-\/\/IETF\/\/DTD HTML 2\.0 Strict\/\/|^-\/\/IETF\/\/DTD HTML 2\.0\/\/|^-\/\/IETF\/\/DTD HTML 2\.1E\/\/|^-\/\/IETF\/\/DTD HTML 3\.0\/\/|^-\/\/IETF\/\/DTD HTML 3\.2 Final\/\/|^-\/\/IETF\/\/DTD HTML 3\.2\/\/|^-\/\/IETF\/\/DTD HTML 3\/\/|^-\/\/IETF\/\/DTD HTML Level 0\/\/|^-\/\/IETF\/\/DTD HTML Level 1\/\/|^-\/\/IETF\/\/DTD HTML Level 2\/\/|^-\/\/IETF\/\/DTD HTML Level 3\/\/|^-\/\/IETF\/\/DTD HTML Strict Level 0\/\/|^-\/\/IETF\/\/DTD HTML Strict Level 1\/\/|^-\/\/IETF\/\/DTD HTML Strict Level 2\/\/|^-\/\/IETF\/\/DTD HTML Strict Level 3\/\/|^-\/\/IETF\/\/DTD HTML Strict\/\/|^-\/\/IETF\/\/DTD HTML\/\/|^-\/\/Metrius\/\/DTD Metrius Presentational\/\/|^-\/\/Microsoft\/\/DTD Internet Explorer 2\.0 HTML Strict\/\/|^-\/\/Microsoft\/\/DTD Internet Explorer 2\.0 HTML\/\/|^-\/\/Microsoft\/\/DTD Internet Explorer 2\.0 Tables\/\/|^-\/\/Microsoft\/\/DTD Internet Explorer 3\.0 HTML Strict\/\/|^-\/\/Microsoft\/\/DTD Internet Explorer 3\.0 HTML\/\/|^-\/\/Microsoft\/\/DTD Internet Explorer 3\.0 Tables\/\/|^-\/\/Netscape Comm\. Corp\.\/\/DTD HTML\/\/|^-\/\/Netscape Comm\. Corp\.\/\/DTD Strict HTML\/\/|^-\/\/O'Reilly and Associates\/\/DTD HTML 2\.0\/\/|^-\/\/O'Reilly and Associates\/\/DTD HTML Extended 1\.0\/\/|^-\/\/O'Reilly and Associates\/\/DTD HTML Extended Relaxed 1\.0\/\/|^-\/\/SoftQuad Software\/\/DTD HoTMetaL PRO 6\.0::19990601::extensions to HTML 4\.0\/\/|^-\/\/SoftQuad\/\/DTD HoTMetaL PRO 4\.0::19971010::extensions to HTML 4\.0\/\/|^-\/\/Spyglass\/\/DTD HTML 2\.0 Extended\/\/|^-\/\/SQ\/\/DTD HTML 2\.0 HoTMetaL \+ extensions\/\/|^-\/\/Sun Microsystems Corp\.\/\/DTD HotJava HTML\/\/|^-\/\/Sun Microsystems Corp\.\/\/DTD HotJava Strict HTML\/\/|^-\/\/W3C\/\/DTD HTML 3 1995-03-24\/\/|^-\/\/W3C\/\/DTD HTML 3\.2 Draft\/\/|^-\/\/W3C\/\/DTD HTML 3\.2 Final\/\/|^-\/\/W3C\/\/DTD HTML 3\.2\/\/|^-\/\/W3C\/\/DTD HTML 3\.2S Draft\/\/|^-\/\/W3C\/\/DTD HTML 4\.0 Frameset\/\/|^-\/\/W3C\/\/DTD HTML 4\.0 Transitional\/\/|^-\/\/W3C\/\/DTD HTML Experimental 19960712\/\/|^-\/\/W3C\/\/DTD HTML Experimental 970421\/\/|^-\/\/W3C\/\/DTD W3 HTML\/\/|^-\/\/W3O\/\/DTD W3 HTML 3\.0\/\/|^-\/\/WebTechs\/\/DTD Mozilla HTML 2\.0\/\/|^-\/\/WebTechs\/\/DTD Mozilla HTML\/\//i;

var quirkySystemId = "http://www.ibm.com/data/dtd/v11/ibmxhtml1-transitional.dtd";

var conditionallyQuirkyPublicIds = /^-\/\/W3C\/\/DTD HTML 4\.01 Frameset\/\/|^-\/\/W3C\/\/DTD HTML 4\.01 Transitional\/\//i;

// These DTD public ids put the browser in limited quirks mode
var limitedQuirkyPublicIds = /^-\/\/W3C\/\/DTD XHTML 1\.0 Frameset\/\/|^-\/\/W3C\/\/DTD XHTML 1\.0 Transitional\/\//i;


// Element sets below. See the isA() function for a way to test
// whether an element is a member of a set
var specialSet = {};
specialSet[NAMESPACE.HTML] = {
  "address":true, "applet":true, "area":true, "article":true,
  "aside":true, "base":true, "basefont":true, "bgsound":true,
  "blockquote":true, "body":true, "br":true, "button":true,
  "caption":true, "center":true, "col":true, "colgroup":true,
  "command":true, "dd":true, "details":true, "dir":true,
  "div":true, "dl":true, "dt":true, "embed":true,
  "fieldset":true, "figcaption":true, "figure":true, "footer":true,
  "form":true, "frame":true, "frameset":true, "h1":true,
  "h2":true, "h3":true, "h4":true, "h5":true,
  "h6":true, "head":true, "header":true, "hgroup":true,
  "hr":true, "html":true, "iframe":true, "img":true,
  "input":true, "isindex":true, "li":true, "link":true,
  "listing":true, "marquee":true, "menu":true, "meta":true,
  "nav":true, "noembed":true, "noframes":true, "noscript":true,
  "object":true, "ol":true, "p":true, "param":true,
  "plaintext":true, "pre":true, "script":true, "section":true,
  "select":true, "style":true, "summary":true, "table":true,
  "tbody":true, "td":true, "textarea":true, "tfoot":true,
  "th":true, "thead":true, "title":true, "tr":true,
  "ul":true, "wbr":true, "xmp":true
};
specialSet[NAMESPACE.SVG] = {
  "foreignObject": true, "desc": true, "title": true
};
specialSet[NAMESPACE.MATHML] = {
  "mi":true, "mo":true, "mn":true, "ms":true,
  "mtext":true, "annotation-xml":true
};

// The set of address, div, and p HTML tags
var addressdivpSet = {};
addressdivpSet[NAMESPACE.HTML] = {
  "address":true, "div":true, "p":true
};

var dddtSet = {};
dddtSet[NAMESPACE.HTML] = {
  "dd":true, "dt":true
};

var tablesectionrowSet = {};
tablesectionrowSet[NAMESPACE.HTML] = {
  "table":true, "thead":true, "tbody":true, "tfoot":true, "tr":true
};

var impliedEndTagsSet = {};
impliedEndTagsSet[NAMESPACE.HTML] = {
  "dd": true, "dt": true, "li": true, "option": true,
  "optgroup": true, "p": true, "rp": true, "rt": true
};

// See http://www.w3.org/TR/html5/forms.html#form-associated-element
var formassociatedSet = {};
formassociatedSet[NAMESPACE.HTML] = {
  "button": true, "fieldset": true, "input": true, "keygen": true,
  "label": true, "meter": true, "object": true, "output": true,
  "progress": true, "select": true, "textarea": true
};

var inScopeSet = {};
inScopeSet[NAMESPACE.HTML]= {
  "applet":true, "caption":true, "html":true, "table":true,
  "td":true, "th":true, "marquee":true, "object":true
};
inScopeSet[NAMESPACE.MATHML] = {
  "mi":true, "mo":true, "mn":true, "ms":true,
  "mtext":true, "annotation-xml":true
};
inScopeSet[NAMESPACE.SVG] = {
  "foreignObject":true, "desc":true, "title":true
};

var inListItemScopeSet = Object.create(inScopeSet);
inListItemScopeSet[NAMESPACE.HTML] =
  Object.create(inScopeSet[NAMESPACE.HTML]);
inListItemScopeSet[NAMESPACE.HTML].ol = true;
inListItemScopeSet[NAMESPACE.HTML].ul = true;

var inButtonScopeSet = Object.create(inScopeSet);
inButtonScopeSet[NAMESPACE.HTML] =
  Object.create(inScopeSet[NAMESPACE.HTML]);
inButtonScopeSet[NAMESPACE.HTML].button = true;

var inTableScopeSet = {};
inTableScopeSet[NAMESPACE.HTML] = {
  "html":true, "table":true
};

// The set of elements for select scope is the everything *except* these
var invertedSelectScopeSet = {};
invertedSelectScopeSet[NAMESPACE.HTML] = {
  "optgroup":true, "option":true
};

var mathmlTextIntegrationPointSet = {};
mathmlTextIntegrationPointSet[NAMESPACE.MATHML] = {
  mi: true,
  mo: true,
  mn: true,
  ms: true,
  mtext: true
};

var htmlIntegrationPointSet = {};
htmlIntegrationPointSet[NAMESPACE.SVG] = {
  foreignObject: true,
  desc: true,
  title: true
};

var foreignAttributes = {
  "xlink:actuate": NAMESPACE.XLINK, "xlink:arcrole": NAMESPACE.XLINK,
  "xlink:href":   NAMESPACE.XLINK,  "xlink:role":    NAMESPACE.XLINK,
  "xlink:show":   NAMESPACE.XLINK,  "xlink:title":   NAMESPACE.XLINK,
  "xlink:type":   NAMESPACE.XLINK,  "xml:base":      NAMESPACE.XML,
  "xml:lang":     NAMESPACE.XML,    "xml:space":     NAMESPACE.XML,
  "xmlns":        NAMESPACE.XMLNS,  "xmlns:xlink":   NAMESPACE.XMLNS
};


// Lowercase to mixed case mapping for SVG attributes and tagnames
var svgAttrAdjustments = {
  attributename: "attributeName", attributetype: "attributeType",
  basefrequency: "baseFrequency", baseprofile: "baseProfile",
  calcmode: "calcMode", clippathunits: "clipPathUnits",
  contentscripttype: "contentScriptType",
  contentstyletype: "contentStyleType",
  diffuseconstant: "diffuseConstant",
  edgemode: "edgeMode",
  externalresourcesrequired: "externalResourcesRequired",
  filterres: "filterRes", filterunits: "filterUnits",
  glyphref: "glyphRef", gradienttransform: "gradientTransform",
  gradientunits: "gradientUnits", kernelmatrix: "kernelMatrix",
  kernelunitlength: "kernelUnitLength", keypoints: "keyPoints",
  keysplines: "keySplines", keytimes: "keyTimes",
  lengthadjust: "lengthAdjust", limitingconeangle: "limitingConeAngle",
  markerheight: "markerHeight", markerunits: "markerUnits",
  markerwidth: "markerWidth", maskcontentunits: "maskContentUnits",
  maskunits: "maskUnits", numoctaves: "numOctaves",
  pathlength: "pathLength", patterncontentunits: "patternContentUnits",
  patterntransform: "patternTransform", patternunits: "patternUnits",
  pointsatx: "pointsAtX", pointsaty: "pointsAtY",
  pointsatz: "pointsAtZ", preservealpha: "preserveAlpha",
  preserveaspectratio: "preserveAspectRatio",
  primitiveunits: "primitiveUnits", refx: "refX",
  refy: "refY", repeatcount: "repeatCount",
  repeatdur: "repeatDur", requiredextensions: "requiredExtensions",
  requiredfeatures: "requiredFeatures",
  specularconstant: "specularConstant",
  specularexponent: "specularExponent", spreadmethod: "spreadMethod",
  startoffset: "startOffset", stddeviation: "stdDeviation",
  stitchtiles: "stitchTiles", surfacescale: "surfaceScale",
  systemlanguage: "systemLanguage", tablevalues: "tableValues",
  targetx: "targetX", targety: "targetY",
  textlength: "textLength", viewbox: "viewBox",
  viewtarget: "viewTarget", xchannelselector: "xChannelSelector",
  ychannelselector: "yChannelSelector", zoomandpan: "zoomAndPan"
};

var svgTagNameAdjustments = {
  altglyph: "altGlyph", altglyphdef: "altGlyphDef",
  altglyphitem: "altGlyphItem", animatecolor: "animateColor",
  animatemotion: "animateMotion", animatetransform: "animateTransform",
  clippath: "clipPath", feblend: "feBlend",
  fecolormatrix: "feColorMatrix",
  fecomponenttransfer: "feComponentTransfer", fecomposite: "feComposite",
  feconvolvematrix: "feConvolveMatrix",
  fediffuselighting: "feDiffuseLighting",
  fedisplacementmap: "feDisplacementMap",
  fedistantlight: "feDistantLight", feflood: "feFlood",
  fefunca: "feFuncA", fefuncb: "feFuncB",
  fefuncg: "feFuncG", fefuncr: "feFuncR",
  fegaussianblur: "feGaussianBlur", feimage: "feImage",
  femerge: "feMerge", femergenode: "feMergeNode",
  femorphology: "feMorphology", feoffset: "feOffset",
  fepointlight: "fePointLight", fespecularlighting: "feSpecularLighting",
  fespotlight: "feSpotLight", fetile: "feTile",
  feturbulence: "feTurbulence", foreignobject: "foreignObject",
  glyphref: "glyphRef", lineargradient: "linearGradient",
  radialgradient: "radialGradient", textpath: "textPath"
};


// Data for parsing numeric and named character references
// These next 3 objects are direct translations of tables
// in the HTML spec into JavaScript object format
var numericCharRefReplacements = {
  0x00:0xFFFD, 0x80:0x20AC, 0x82:0x201A, 0x83:0x0192, 0x84:0x201E,
  0x85:0x2026, 0x86:0x2020, 0x87:0x2021, 0x88:0x02C6, 0x89:0x2030,
  0x8A:0x0160, 0x8B:0x2039, 0x8C:0x0152, 0x8E:0x017D, 0x91:0x2018,
  0x92:0x2019, 0x93:0x201C, 0x94:0x201D, 0x95:0x2022, 0x96:0x2013,
  0x97:0x2014, 0x98:0x02DC, 0x99:0x2122, 0x9A:0x0161, 0x9B:0x203A,
  0x9C:0x0153, 0x9E:0x017E, 0x9F:0x0178
};

// These named character references work even without the semicolon
var namedCharRefsNoSemi = {
  "AElig":0xC6, "AMP":0x26, "Aacute":0xC1, "Acirc":0xC2,
  "Agrave":0xC0, "Aring":0xC5, "Atilde":0xC3, "Auml":0xC4,
  "COPY":0xA9, "Ccedil":0xC7, "ETH":0xD0, "Eacute":0xC9,
  "Ecirc":0xCA, "Egrave":0xC8, "Euml":0xCB, "GT":0x3E,
  "Iacute":0xCD, "Icirc":0xCE, "Igrave":0xCC, "Iuml":0xCF,
  "LT":0x3C, "Ntilde":0xD1, "Oacute":0xD3, "Ocirc":0xD4,
  "Ograve":0xD2, "Oslash":0xD8, "Otilde":0xD5, "Ouml":0xD6,
  "QUOT":0x22, "REG":0xAE, "THORN":0xDE, "Uacute":0xDA,
  "Ucirc":0xDB, "Ugrave":0xD9, "Uuml":0xDC, "Yacute":0xDD,
  "aacute":0xE1, "acirc":0xE2, "acute":0xB4, "aelig":0xE6,
  "agrave":0xE0, "amp":0x26, "aring":0xE5, "atilde":0xE3,
  "auml":0xE4, "brvbar":0xA6, "ccedil":0xE7, "cedil":0xB8,
  "cent":0xA2, "copy":0xA9, "curren":0xA4, "deg":0xB0,
  "divide":0xF7, "eacute":0xE9, "ecirc":0xEA, "egrave":0xE8,
  "eth":0xF0, "euml":0xEB, "frac12":0xBD, "frac14":0xBC,
  "frac34":0xBE, "gt":0x3E, "iacute":0xED, "icirc":0xEE,
  "iexcl":0xA1, "igrave":0xEC, "iquest":0xBF, "iuml":0xEF,
  "laquo":0xAB, "lt":0x3C, "macr":0xAF, "micro":0xB5,
  "middot":0xB7, "nbsp":0xA0, "not":0xAC, "ntilde":0xF1,
  "oacute":0xF3, "ocirc":0xF4, "ograve":0xF2, "ordf":0xAA,
  "ordm":0xBA, "oslash":0xF8, "otilde":0xF5, "ouml":0xF6,
  "para":0xB6, "plusmn":0xB1, "pound":0xA3, "quot":0x22,
  "raquo":0xBB, "reg":0xAE, "sect":0xA7, "shy":0xAD,
  "sup1":0xB9, "sup2":0xB2, "sup3":0xB3, "szlig":0xDF,
  "thorn":0xFE, "times":0xD7, "uacute":0xFA, "ucirc":0xFB,
  "ugrave":0xF9, "uml":0xA8, "uuml":0xFC, "yacute":0xFD,
  "yen":0xA5, "yuml":0xFF
};

var namedCharRefs = {
  "AElig;":0xc6, "AMP;":0x26,
  "Aacute;":0xc1, "Abreve;":0x102,
  "Acirc;":0xc2, "Acy;":0x410,
  "Afr;":[0xd835,0xdd04], "Agrave;":0xc0,
  "Alpha;":0x391, "Amacr;":0x100,
  "And;":0x2a53, "Aogon;":0x104,
  "Aopf;":[0xd835,0xdd38], "ApplyFunction;":0x2061,
  "Aring;":0xc5, "Ascr;":[0xd835,0xdc9c],
  "Assign;":0x2254, "Atilde;":0xc3,
  "Auml;":0xc4, "Backslash;":0x2216,
  "Barv;":0x2ae7, "Barwed;":0x2306,
  "Bcy;":0x411, "Because;":0x2235,
  "Bernoullis;":0x212c, "Beta;":0x392,
  "Bfr;":[0xd835,0xdd05], "Bopf;":[0xd835,0xdd39],
  "Breve;":0x2d8, "Bscr;":0x212c,
  "Bumpeq;":0x224e, "CHcy;":0x427,
  "COPY;":0xa9, "Cacute;":0x106,
  "Cap;":0x22d2, "CapitalDifferentialD;":0x2145,
  "Cayleys;":0x212d, "Ccaron;":0x10c,
  "Ccedil;":0xc7, "Ccirc;":0x108,
  "Cconint;":0x2230, "Cdot;":0x10a,
  "Cedilla;":0xb8, "CenterDot;":0xb7,
  "Cfr;":0x212d, "Chi;":0x3a7,
  "CircleDot;":0x2299, "CircleMinus;":0x2296,
  "CirclePlus;":0x2295, "CircleTimes;":0x2297,
  "ClockwiseContourIntegral;":0x2232, "CloseCurlyDoubleQuote;":0x201d,
  "CloseCurlyQuote;":0x2019, "Colon;":0x2237,
  "Colone;":0x2a74, "Congruent;":0x2261,
  "Conint;":0x222f, "ContourIntegral;":0x222e,
  "Copf;":0x2102, "Coproduct;":0x2210,
  "CounterClockwiseContourIntegral;":0x2233, "Cross;":0x2a2f,
  "Cscr;":[0xd835,0xdc9e], "Cup;":0x22d3,
  "CupCap;":0x224d, "DD;":0x2145,
  "DDotrahd;":0x2911, "DJcy;":0x402,
  "DScy;":0x405, "DZcy;":0x40f,
  "Dagger;":0x2021, "Darr;":0x21a1,
  "Dashv;":0x2ae4, "Dcaron;":0x10e,
  "Dcy;":0x414, "Del;":0x2207,
  "Delta;":0x394, "Dfr;":[0xd835,0xdd07],
  "DiacriticalAcute;":0xb4, "DiacriticalDot;":0x2d9,
  "DiacriticalDoubleAcute;":0x2dd, "DiacriticalGrave;":0x60,
  "DiacriticalTilde;":0x2dc, "Diamond;":0x22c4,
  "DifferentialD;":0x2146, "Dopf;":[0xd835,0xdd3b],
  "Dot;":0xa8, "DotDot;":0x20dc,
  "DotEqual;":0x2250, "DoubleContourIntegral;":0x222f,
  "DoubleDot;":0xa8, "DoubleDownArrow;":0x21d3,
  "DoubleLeftArrow;":0x21d0, "DoubleLeftRightArrow;":0x21d4,
  "DoubleLeftTee;":0x2ae4, "DoubleLongLeftArrow;":0x27f8,
  "DoubleLongLeftRightArrow;":0x27fa, "DoubleLongRightArrow;":0x27f9,
  "DoubleRightArrow;":0x21d2, "DoubleRightTee;":0x22a8,
  "DoubleUpArrow;":0x21d1, "DoubleUpDownArrow;":0x21d5,
  "DoubleVerticalBar;":0x2225, "DownArrow;":0x2193,
  "DownArrowBar;":0x2913, "DownArrowUpArrow;":0x21f5,
  "DownBreve;":0x311, "DownLeftRightVector;":0x2950,
  "DownLeftTeeVector;":0x295e, "DownLeftVector;":0x21bd,
  "DownLeftVectorBar;":0x2956, "DownRightTeeVector;":0x295f,
  "DownRightVector;":0x21c1, "DownRightVectorBar;":0x2957,
  "DownTee;":0x22a4, "DownTeeArrow;":0x21a7,
  "Downarrow;":0x21d3, "Dscr;":[0xd835,0xdc9f],
  "Dstrok;":0x110, "ENG;":0x14a,
  "ETH;":0xd0, "Eacute;":0xc9,
  "Ecaron;":0x11a, "Ecirc;":0xca,
  "Ecy;":0x42d, "Edot;":0x116,
  "Efr;":[0xd835,0xdd08], "Egrave;":0xc8,
  "Element;":0x2208, "Emacr;":0x112,
  "EmptySmallSquare;":0x25fb, "EmptyVerySmallSquare;":0x25ab,
  "Eogon;":0x118, "Eopf;":[0xd835,0xdd3c],
  "Epsilon;":0x395, "Equal;":0x2a75,
  "EqualTilde;":0x2242, "Equilibrium;":0x21cc,
  "Escr;":0x2130, "Esim;":0x2a73,
  "Eta;":0x397, "Euml;":0xcb,
  "Exists;":0x2203, "ExponentialE;":0x2147,
  "Fcy;":0x424, "Ffr;":[0xd835,0xdd09],
  "FilledSmallSquare;":0x25fc, "FilledVerySmallSquare;":0x25aa,
  "Fopf;":[0xd835,0xdd3d], "ForAll;":0x2200,
  "Fouriertrf;":0x2131, "Fscr;":0x2131,
  "GJcy;":0x403, "GT;":0x3e,
  "Gamma;":0x393, "Gammad;":0x3dc,
  "Gbreve;":0x11e, "Gcedil;":0x122,
  "Gcirc;":0x11c, "Gcy;":0x413,
  "Gdot;":0x120, "Gfr;":[0xd835,0xdd0a],
  "Gg;":0x22d9, "Gopf;":[0xd835,0xdd3e],
  "GreaterEqual;":0x2265, "GreaterEqualLess;":0x22db,
  "GreaterFullEqual;":0x2267, "GreaterGreater;":0x2aa2,
  "GreaterLess;":0x2277, "GreaterSlantEqual;":0x2a7e,
  "GreaterTilde;":0x2273, "Gscr;":[0xd835,0xdca2],
  "Gt;":0x226b, "HARDcy;":0x42a,
  "Hacek;":0x2c7, "Hat;":0x5e,
  "Hcirc;":0x124, "Hfr;":0x210c,
  "HilbertSpace;":0x210b, "Hopf;":0x210d,
  "HorizontalLine;":0x2500, "Hscr;":0x210b,
  "Hstrok;":0x126, "HumpDownHump;":0x224e,
  "HumpEqual;":0x224f, "IEcy;":0x415,
  "IJlig;":0x132, "IOcy;":0x401,
  "Iacute;":0xcd, "Icirc;":0xce,
  "Icy;":0x418, "Idot;":0x130,
  "Ifr;":0x2111, "Igrave;":0xcc,
  "Im;":0x2111, "Imacr;":0x12a,
  "ImaginaryI;":0x2148, "Implies;":0x21d2,
  "Int;":0x222c, "Integral;":0x222b,
  "Intersection;":0x22c2, "InvisibleComma;":0x2063,
  "InvisibleTimes;":0x2062, "Iogon;":0x12e,
  "Iopf;":[0xd835,0xdd40], "Iota;":0x399,
  "Iscr;":0x2110, "Itilde;":0x128,
  "Iukcy;":0x406, "Iuml;":0xcf,
  "Jcirc;":0x134, "Jcy;":0x419,
  "Jfr;":[0xd835,0xdd0d], "Jopf;":[0xd835,0xdd41],
  "Jscr;":[0xd835,0xdca5], "Jsercy;":0x408,
  "Jukcy;":0x404, "KHcy;":0x425,
  "KJcy;":0x40c, "Kappa;":0x39a,
  "Kcedil;":0x136, "Kcy;":0x41a,
  "Kfr;":[0xd835,0xdd0e], "Kopf;":[0xd835,0xdd42],
  "Kscr;":[0xd835,0xdca6], "LJcy;":0x409,
  "LT;":0x3c, "Lacute;":0x139,
  "Lambda;":0x39b, "Lang;":0x27ea,
  "Laplacetrf;":0x2112, "Larr;":0x219e,
  "Lcaron;":0x13d, "Lcedil;":0x13b,
  "Lcy;":0x41b, "LeftAngleBracket;":0x27e8,
  "LeftArrow;":0x2190, "LeftArrowBar;":0x21e4,
  "LeftArrowRightArrow;":0x21c6, "LeftCeiling;":0x2308,
  "LeftDoubleBracket;":0x27e6, "LeftDownTeeVector;":0x2961,
  "LeftDownVector;":0x21c3, "LeftDownVectorBar;":0x2959,
  "LeftFloor;":0x230a, "LeftRightArrow;":0x2194,
  "LeftRightVector;":0x294e, "LeftTee;":0x22a3,
  "LeftTeeArrow;":0x21a4, "LeftTeeVector;":0x295a,
  "LeftTriangle;":0x22b2, "LeftTriangleBar;":0x29cf,
  "LeftTriangleEqual;":0x22b4, "LeftUpDownVector;":0x2951,
  "LeftUpTeeVector;":0x2960, "LeftUpVector;":0x21bf,
  "LeftUpVectorBar;":0x2958, "LeftVector;":0x21bc,
  "LeftVectorBar;":0x2952, "Leftarrow;":0x21d0,
  "Leftrightarrow;":0x21d4, "LessEqualGreater;":0x22da,
  "LessFullEqual;":0x2266, "LessGreater;":0x2276,
  "LessLess;":0x2aa1, "LessSlantEqual;":0x2a7d,
  "LessTilde;":0x2272, "Lfr;":[0xd835,0xdd0f],
  "Ll;":0x22d8, "Lleftarrow;":0x21da,
  "Lmidot;":0x13f, "LongLeftArrow;":0x27f5,
  "LongLeftRightArrow;":0x27f7, "LongRightArrow;":0x27f6,
  "Longleftarrow;":0x27f8, "Longleftrightarrow;":0x27fa,
  "Longrightarrow;":0x27f9, "Lopf;":[0xd835,0xdd43],
  "LowerLeftArrow;":0x2199, "LowerRightArrow;":0x2198,
  "Lscr;":0x2112, "Lsh;":0x21b0,
  "Lstrok;":0x141, "Lt;":0x226a,
  "Map;":0x2905, "Mcy;":0x41c,
  "MediumSpace;":0x205f, "Mellintrf;":0x2133,
  "Mfr;":[0xd835,0xdd10], "MinusPlus;":0x2213,
  "Mopf;":[0xd835,0xdd44], "Mscr;":0x2133,
  "Mu;":0x39c, "NJcy;":0x40a,
  "Nacute;":0x143, "Ncaron;":0x147,
  "Ncedil;":0x145, "Ncy;":0x41d,
  "NegativeMediumSpace;":0x200b, "NegativeThickSpace;":0x200b,
  "NegativeThinSpace;":0x200b, "NegativeVeryThinSpace;":0x200b,
  "NestedGreaterGreater;":0x226b, "NestedLessLess;":0x226a,
  "NewLine;":0xa, "Nfr;":[0xd835,0xdd11],
  "NoBreak;":0x2060, "NonBreakingSpace;":0xa0,
  "Nopf;":0x2115, "Not;":0x2aec,
  "NotCongruent;":0x2262, "NotCupCap;":0x226d,
  "NotDoubleVerticalBar;":0x2226, "NotElement;":0x2209,
  "NotEqual;":0x2260, "NotEqualTilde;":[0x2242,0x338],
  "NotExists;":0x2204, "NotGreater;":0x226f,
  "NotGreaterEqual;":0x2271, "NotGreaterFullEqual;":[0x2267,0x338],
  "NotGreaterGreater;":[0x226b,0x338], "NotGreaterLess;":0x2279,
  "NotGreaterSlantEqual;":[0x2a7e,0x338], "NotGreaterTilde;":0x2275,
  "NotHumpDownHump;":[0x224e,0x338], "NotHumpEqual;":[0x224f,0x338],
  "NotLeftTriangle;":0x22ea, "NotLeftTriangleBar;":[0x29cf,0x338],
  "NotLeftTriangleEqual;":0x22ec, "NotLess;":0x226e,
  "NotLessEqual;":0x2270, "NotLessGreater;":0x2278,
  "NotLessLess;":[0x226a,0x338], "NotLessSlantEqual;":[0x2a7d,0x338],
  "NotLessTilde;":0x2274, "NotNestedGreaterGreater;":[0x2aa2,0x338],
  "NotNestedLessLess;":[0x2aa1,0x338], "NotPrecedes;":0x2280,
  "NotPrecedesEqual;":[0x2aaf,0x338], "NotPrecedesSlantEqual;":0x22e0,
  "NotReverseElement;":0x220c, "NotRightTriangle;":0x22eb,
  "NotRightTriangleBar;":[0x29d0,0x338], "NotRightTriangleEqual;":0x22ed,
  "NotSquareSubset;":[0x228f,0x338], "NotSquareSubsetEqual;":0x22e2,
  "NotSquareSuperset;":[0x2290,0x338], "NotSquareSupersetEqual;":0x22e3,
  "NotSubset;":[0x2282,0x20d2], "NotSubsetEqual;":0x2288,
  "NotSucceeds;":0x2281, "NotSucceedsEqual;":[0x2ab0,0x338],
  "NotSucceedsSlantEqual;":0x22e1, "NotSucceedsTilde;":[0x227f,0x338],
  "NotSuperset;":[0x2283,0x20d2], "NotSupersetEqual;":0x2289,
  "NotTilde;":0x2241, "NotTildeEqual;":0x2244,
  "NotTildeFullEqual;":0x2247, "NotTildeTilde;":0x2249,
  "NotVerticalBar;":0x2224, "Nscr;":[0xd835,0xdca9],
  "Ntilde;":0xd1, "Nu;":0x39d,
  "OElig;":0x152, "Oacute;":0xd3,
  "Ocirc;":0xd4, "Ocy;":0x41e,
  "Odblac;":0x150, "Ofr;":[0xd835,0xdd12],
  "Ograve;":0xd2, "Omacr;":0x14c,
  "Omega;":0x3a9, "Omicron;":0x39f,
  "Oopf;":[0xd835,0xdd46], "OpenCurlyDoubleQuote;":0x201c,
  "OpenCurlyQuote;":0x2018, "Or;":0x2a54,
  "Oscr;":[0xd835,0xdcaa], "Oslash;":0xd8,
  "Otilde;":0xd5, "Otimes;":0x2a37,
  "Ouml;":0xd6, "OverBar;":0x203e,
  "OverBrace;":0x23de, "OverBracket;":0x23b4,
  "OverParenthesis;":0x23dc, "PartialD;":0x2202,
  "Pcy;":0x41f, "Pfr;":[0xd835,0xdd13],
  "Phi;":0x3a6, "Pi;":0x3a0,
  "PlusMinus;":0xb1, "Poincareplane;":0x210c,
  "Popf;":0x2119, "Pr;":0x2abb,
  "Precedes;":0x227a, "PrecedesEqual;":0x2aaf,
  "PrecedesSlantEqual;":0x227c, "PrecedesTilde;":0x227e,
  "Prime;":0x2033, "Product;":0x220f,
  "Proportion;":0x2237, "Proportional;":0x221d,
  "Pscr;":[0xd835,0xdcab], "Psi;":0x3a8,
  "QUOT;":0x22, "Qfr;":[0xd835,0xdd14],
  "Qopf;":0x211a, "Qscr;":[0xd835,0xdcac],
  "RBarr;":0x2910, "REG;":0xae,
  "Racute;":0x154, "Rang;":0x27eb,
  "Rarr;":0x21a0, "Rarrtl;":0x2916,
  "Rcaron;":0x158, "Rcedil;":0x156,
  "Rcy;":0x420, "Re;":0x211c,
  "ReverseElement;":0x220b, "ReverseEquilibrium;":0x21cb,
  "ReverseUpEquilibrium;":0x296f, "Rfr;":0x211c,
  "Rho;":0x3a1, "RightAngleBracket;":0x27e9,
  "RightArrow;":0x2192, "RightArrowBar;":0x21e5,
  "RightArrowLeftArrow;":0x21c4, "RightCeiling;":0x2309,
  "RightDoubleBracket;":0x27e7, "RightDownTeeVector;":0x295d,
  "RightDownVector;":0x21c2, "RightDownVectorBar;":0x2955,
  "RightFloor;":0x230b, "RightTee;":0x22a2,
  "RightTeeArrow;":0x21a6, "RightTeeVector;":0x295b,
  "RightTriangle;":0x22b3, "RightTriangleBar;":0x29d0,
  "RightTriangleEqual;":0x22b5, "RightUpDownVector;":0x294f,
  "RightUpTeeVector;":0x295c, "RightUpVector;":0x21be,
  "RightUpVectorBar;":0x2954, "RightVector;":0x21c0,
  "RightVectorBar;":0x2953, "Rightarrow;":0x21d2,
  "Ropf;":0x211d, "RoundImplies;":0x2970,
  "Rrightarrow;":0x21db, "Rscr;":0x211b,
  "Rsh;":0x21b1, "RuleDelayed;":0x29f4,
  "SHCHcy;":0x429, "SHcy;":0x428,
  "SOFTcy;":0x42c, "Sacute;":0x15a,
  "Sc;":0x2abc, "Scaron;":0x160,
  "Scedil;":0x15e, "Scirc;":0x15c,
  "Scy;":0x421, "Sfr;":[0xd835,0xdd16],
  "ShortDownArrow;":0x2193, "ShortLeftArrow;":0x2190,
  "ShortRightArrow;":0x2192, "ShortUpArrow;":0x2191,
  "Sigma;":0x3a3, "SmallCircle;":0x2218,
  "Sopf;":[0xd835,0xdd4a], "Sqrt;":0x221a,
  "Square;":0x25a1, "SquareIntersection;":0x2293,
  "SquareSubset;":0x228f, "SquareSubsetEqual;":0x2291,
  "SquareSuperset;":0x2290, "SquareSupersetEqual;":0x2292,
  "SquareUnion;":0x2294, "Sscr;":[0xd835,0xdcae],
  "Star;":0x22c6, "Sub;":0x22d0,
  "Subset;":0x22d0, "SubsetEqual;":0x2286,
  "Succeeds;":0x227b, "SucceedsEqual;":0x2ab0,
  "SucceedsSlantEqual;":0x227d, "SucceedsTilde;":0x227f,
  "SuchThat;":0x220b, "Sum;":0x2211,
  "Sup;":0x22d1, "Superset;":0x2283,
  "SupersetEqual;":0x2287, "Supset;":0x22d1,
  "THORN;":0xde, "TRADE;":0x2122,
  "TSHcy;":0x40b, "TScy;":0x426,
  "Tab;":0x9, "Tau;":0x3a4,
  "Tcaron;":0x164, "Tcedil;":0x162,
  "Tcy;":0x422, "Tfr;":[0xd835,0xdd17],
  "Therefore;":0x2234, "Theta;":0x398,
  "ThickSpace;":[0x205f,0x200a], "ThinSpace;":0x2009,
  "Tilde;":0x223c, "TildeEqual;":0x2243,
  "TildeFullEqual;":0x2245, "TildeTilde;":0x2248,
  "Topf;":[0xd835,0xdd4b], "TripleDot;":0x20db,
  "Tscr;":[0xd835,0xdcaf], "Tstrok;":0x166,
  "Uacute;":0xda, "Uarr;":0x219f,
  "Uarrocir;":0x2949, "Ubrcy;":0x40e,
  "Ubreve;":0x16c, "Ucirc;":0xdb,
  "Ucy;":0x423, "Udblac;":0x170,
  "Ufr;":[0xd835,0xdd18], "Ugrave;":0xd9,
  "Umacr;":0x16a, "UnderBar;":0x5f,
  "UnderBrace;":0x23df, "UnderBracket;":0x23b5,
  "UnderParenthesis;":0x23dd, "Union;":0x22c3,
  "UnionPlus;":0x228e, "Uogon;":0x172,
  "Uopf;":[0xd835,0xdd4c], "UpArrow;":0x2191,
  "UpArrowBar;":0x2912, "UpArrowDownArrow;":0x21c5,
  "UpDownArrow;":0x2195, "UpEquilibrium;":0x296e,
  "UpTee;":0x22a5, "UpTeeArrow;":0x21a5,
  "Uparrow;":0x21d1, "Updownarrow;":0x21d5,
  "UpperLeftArrow;":0x2196, "UpperRightArrow;":0x2197,
  "Upsi;":0x3d2, "Upsilon;":0x3a5,
  "Uring;":0x16e, "Uscr;":[0xd835,0xdcb0],
  "Utilde;":0x168, "Uuml;":0xdc,
  "VDash;":0x22ab, "Vbar;":0x2aeb,
  "Vcy;":0x412, "Vdash;":0x22a9,
  "Vdashl;":0x2ae6, "Vee;":0x22c1,
  "Verbar;":0x2016, "Vert;":0x2016,
  "VerticalBar;":0x2223, "VerticalLine;":0x7c,
  "VerticalSeparator;":0x2758, "VerticalTilde;":0x2240,
  "VeryThinSpace;":0x200a, "Vfr;":[0xd835,0xdd19],
  "Vopf;":[0xd835,0xdd4d], "Vscr;":[0xd835,0xdcb1],
  "Vvdash;":0x22aa, "Wcirc;":0x174,
  "Wedge;":0x22c0, "Wfr;":[0xd835,0xdd1a],
  "Wopf;":[0xd835,0xdd4e], "Wscr;":[0xd835,0xdcb2],
  "Xfr;":[0xd835,0xdd1b], "Xi;":0x39e,
  "Xopf;":[0xd835,0xdd4f], "Xscr;":[0xd835,0xdcb3],
  "YAcy;":0x42f, "YIcy;":0x407,
  "YUcy;":0x42e, "Yacute;":0xdd,
  "Ycirc;":0x176, "Ycy;":0x42b,
  "Yfr;":[0xd835,0xdd1c], "Yopf;":[0xd835,0xdd50],
  "Yscr;":[0xd835,0xdcb4], "Yuml;":0x178,
  "ZHcy;":0x416, "Zacute;":0x179,
  "Zcaron;":0x17d, "Zcy;":0x417,
  "Zdot;":0x17b, "ZeroWidthSpace;":0x200b,
  "Zeta;":0x396, "Zfr;":0x2128,
  "Zopf;":0x2124, "Zscr;":[0xd835,0xdcb5],
  "aacute;":0xe1, "abreve;":0x103,
  "ac;":0x223e, "acE;":[0x223e,0x333],
  "acd;":0x223f, "acirc;":0xe2,
  "acute;":0xb4, "acy;":0x430,
  "aelig;":0xe6, "af;":0x2061,
  "afr;":[0xd835,0xdd1e], "agrave;":0xe0,
  "alefsym;":0x2135, "aleph;":0x2135,
  "alpha;":0x3b1, "amacr;":0x101,
  "amalg;":0x2a3f, "amp;":0x26,
  "and;":0x2227, "andand;":0x2a55,
  "andd;":0x2a5c, "andslope;":0x2a58,
  "andv;":0x2a5a, "ang;":0x2220,
  "ange;":0x29a4, "angle;":0x2220,
  "angmsd;":0x2221, "angmsdaa;":0x29a8,
  "angmsdab;":0x29a9, "angmsdac;":0x29aa,
  "angmsdad;":0x29ab, "angmsdae;":0x29ac,
  "angmsdaf;":0x29ad, "angmsdag;":0x29ae,
  "angmsdah;":0x29af, "angrt;":0x221f,
  "angrtvb;":0x22be, "angrtvbd;":0x299d,
  "angsph;":0x2222, "angst;":0xc5,
  "angzarr;":0x237c, "aogon;":0x105,
  "aopf;":[0xd835,0xdd52], "ap;":0x2248,
  "apE;":0x2a70, "apacir;":0x2a6f,
  "ape;":0x224a, "apid;":0x224b,
  "apos;":0x27, "approx;":0x2248,
  "approxeq;":0x224a, "aring;":0xe5,
  "ascr;":[0xd835,0xdcb6], "ast;":0x2a,
  "asymp;":0x2248, "asympeq;":0x224d,
  "atilde;":0xe3, "auml;":0xe4,
  "awconint;":0x2233, "awint;":0x2a11,
  "bNot;":0x2aed, "backcong;":0x224c,
  "backepsilon;":0x3f6, "backprime;":0x2035,
  "backsim;":0x223d, "backsimeq;":0x22cd,
  "barvee;":0x22bd, "barwed;":0x2305,
  "barwedge;":0x2305, "bbrk;":0x23b5,
  "bbrktbrk;":0x23b6, "bcong;":0x224c,
  "bcy;":0x431, "bdquo;":0x201e,
  "becaus;":0x2235, "because;":0x2235,
  "bemptyv;":0x29b0, "bepsi;":0x3f6,
  "bernou;":0x212c, "beta;":0x3b2,
  "beth;":0x2136, "between;":0x226c,
  "bfr;":[0xd835,0xdd1f], "bigcap;":0x22c2,
  "bigcirc;":0x25ef, "bigcup;":0x22c3,
  "bigodot;":0x2a00, "bigoplus;":0x2a01,
  "bigotimes;":0x2a02, "bigsqcup;":0x2a06,
  "bigstar;":0x2605, "bigtriangledown;":0x25bd,
  "bigtriangleup;":0x25b3, "biguplus;":0x2a04,
  "bigvee;":0x22c1, "bigwedge;":0x22c0,
  "bkarow;":0x290d, "blacklozenge;":0x29eb,
  "blacksquare;":0x25aa, "blacktriangle;":0x25b4,
  "blacktriangledown;":0x25be, "blacktriangleleft;":0x25c2,
  "blacktriangleright;":0x25b8, "blank;":0x2423,
  "blk12;":0x2592, "blk14;":0x2591,
  "blk34;":0x2593, "block;":0x2588,
  "bne;":[0x3d,0x20e5], "bnequiv;":[0x2261,0x20e5],
  "bnot;":0x2310, "bopf;":[0xd835,0xdd53],
  "bot;":0x22a5, "bottom;":0x22a5,
  "bowtie;":0x22c8, "boxDL;":0x2557,
  "boxDR;":0x2554, "boxDl;":0x2556,
  "boxDr;":0x2553, "boxH;":0x2550,
  "boxHD;":0x2566, "boxHU;":0x2569,
  "boxHd;":0x2564, "boxHu;":0x2567,
  "boxUL;":0x255d, "boxUR;":0x255a,
  "boxUl;":0x255c, "boxUr;":0x2559,
  "boxV;":0x2551, "boxVH;":0x256c,
  "boxVL;":0x2563, "boxVR;":0x2560,
  "boxVh;":0x256b, "boxVl;":0x2562,
  "boxVr;":0x255f, "boxbox;":0x29c9,
  "boxdL;":0x2555, "boxdR;":0x2552,
  "boxdl;":0x2510, "boxdr;":0x250c,
  "boxh;":0x2500, "boxhD;":0x2565,
  "boxhU;":0x2568, "boxhd;":0x252c,
  "boxhu;":0x2534, "boxminus;":0x229f,
  "boxplus;":0x229e, "boxtimes;":0x22a0,
  "boxuL;":0x255b, "boxuR;":0x2558,
  "boxul;":0x2518, "boxur;":0x2514,
  "boxv;":0x2502, "boxvH;":0x256a,
  "boxvL;":0x2561, "boxvR;":0x255e,
  "boxvh;":0x253c, "boxvl;":0x2524,
  "boxvr;":0x251c, "bprime;":0x2035,
  "breve;":0x2d8, "brvbar;":0xa6,
  "bscr;":[0xd835,0xdcb7], "bsemi;":0x204f,
  "bsim;":0x223d, "bsime;":0x22cd,
  "bsol;":0x5c, "bsolb;":0x29c5,
  "bsolhsub;":0x27c8, "bull;":0x2022,
  "bullet;":0x2022, "bump;":0x224e,
  "bumpE;":0x2aae, "bumpe;":0x224f,
  "bumpeq;":0x224f, "cacute;":0x107,
  "cap;":0x2229, "capand;":0x2a44,
  "capbrcup;":0x2a49, "capcap;":0x2a4b,
  "capcup;":0x2a47, "capdot;":0x2a40,
  "caps;":[0x2229,0xfe00], "caret;":0x2041,
  "caron;":0x2c7, "ccaps;":0x2a4d,
  "ccaron;":0x10d, "ccedil;":0xe7,
  "ccirc;":0x109, "ccups;":0x2a4c,
  "ccupssm;":0x2a50, "cdot;":0x10b,
  "cedil;":0xb8, "cemptyv;":0x29b2,
  "cent;":0xa2, "centerdot;":0xb7,
  "cfr;":[0xd835,0xdd20], "chcy;":0x447,
  "check;":0x2713, "checkmark;":0x2713,
  "chi;":0x3c7, "cir;":0x25cb,
  "cirE;":0x29c3, "circ;":0x2c6,
  "circeq;":0x2257, "circlearrowleft;":0x21ba,
  "circlearrowright;":0x21bb, "circledR;":0xae,
  "circledS;":0x24c8, "circledast;":0x229b,
  "circledcirc;":0x229a, "circleddash;":0x229d,
  "cire;":0x2257, "cirfnint;":0x2a10,
  "cirmid;":0x2aef, "cirscir;":0x29c2,
  "clubs;":0x2663, "clubsuit;":0x2663,
  "colon;":0x3a, "colone;":0x2254,
  "coloneq;":0x2254, "comma;":0x2c,
  "commat;":0x40, "comp;":0x2201,
  "compfn;":0x2218, "complement;":0x2201,
  "complexes;":0x2102, "cong;":0x2245,
  "congdot;":0x2a6d, "conint;":0x222e,
  "copf;":[0xd835,0xdd54], "coprod;":0x2210,
  "copy;":0xa9, "copysr;":0x2117,
  "crarr;":0x21b5, "cross;":0x2717,
  "cscr;":[0xd835,0xdcb8], "csub;":0x2acf,
  "csube;":0x2ad1, "csup;":0x2ad0,
  "csupe;":0x2ad2, "ctdot;":0x22ef,
  "cudarrl;":0x2938, "cudarrr;":0x2935,
  "cuepr;":0x22de, "cuesc;":0x22df,
  "cularr;":0x21b6, "cularrp;":0x293d,
  "cup;":0x222a, "cupbrcap;":0x2a48,
  "cupcap;":0x2a46, "cupcup;":0x2a4a,
  "cupdot;":0x228d, "cupor;":0x2a45,
  "cups;":[0x222a,0xfe00], "curarr;":0x21b7,
  "curarrm;":0x293c, "curlyeqprec;":0x22de,
  "curlyeqsucc;":0x22df, "curlyvee;":0x22ce,
  "curlywedge;":0x22cf, "curren;":0xa4,
  "curvearrowleft;":0x21b6, "curvearrowright;":0x21b7,
  "cuvee;":0x22ce, "cuwed;":0x22cf,
  "cwconint;":0x2232, "cwint;":0x2231,
  "cylcty;":0x232d, "dArr;":0x21d3,
  "dHar;":0x2965, "dagger;":0x2020,
  "daleth;":0x2138, "darr;":0x2193,
  "dash;":0x2010, "dashv;":0x22a3,
  "dbkarow;":0x290f, "dblac;":0x2dd,
  "dcaron;":0x10f, "dcy;":0x434,
  "dd;":0x2146, "ddagger;":0x2021,
  "ddarr;":0x21ca, "ddotseq;":0x2a77,
  "deg;":0xb0, "delta;":0x3b4,
  "demptyv;":0x29b1, "dfisht;":0x297f,
  "dfr;":[0xd835,0xdd21], "dharl;":0x21c3,
  "dharr;":0x21c2, "diam;":0x22c4,
  "diamond;":0x22c4, "diamondsuit;":0x2666,
  "diams;":0x2666, "die;":0xa8,
  "digamma;":0x3dd, "disin;":0x22f2,
  "div;":0xf7, "divide;":0xf7,
  "divideontimes;":0x22c7, "divonx;":0x22c7,
  "djcy;":0x452, "dlcorn;":0x231e,
  "dlcrop;":0x230d, "dollar;":0x24,
  "dopf;":[0xd835,0xdd55], "dot;":0x2d9,
  "doteq;":0x2250, "doteqdot;":0x2251,
  "dotminus;":0x2238, "dotplus;":0x2214,
  "dotsquare;":0x22a1, "doublebarwedge;":0x2306,
  "downarrow;":0x2193, "downdownarrows;":0x21ca,
  "downharpoonleft;":0x21c3, "downharpoonright;":0x21c2,
  "drbkarow;":0x2910, "drcorn;":0x231f,
  "drcrop;":0x230c, "dscr;":[0xd835,0xdcb9],
  "dscy;":0x455, "dsol;":0x29f6,
  "dstrok;":0x111, "dtdot;":0x22f1,
  "dtri;":0x25bf, "dtrif;":0x25be,
  "duarr;":0x21f5, "duhar;":0x296f,
  "dwangle;":0x29a6, "dzcy;":0x45f,
  "dzigrarr;":0x27ff, "eDDot;":0x2a77,
  "eDot;":0x2251, "eacute;":0xe9,
  "easter;":0x2a6e, "ecaron;":0x11b,
  "ecir;":0x2256, "ecirc;":0xea,
  "ecolon;":0x2255, "ecy;":0x44d,
  "edot;":0x117, "ee;":0x2147,
  "efDot;":0x2252, "efr;":[0xd835,0xdd22],
  "eg;":0x2a9a, "egrave;":0xe8,
  "egs;":0x2a96, "egsdot;":0x2a98,
  "el;":0x2a99, "elinters;":0x23e7,
  "ell;":0x2113, "els;":0x2a95,
  "elsdot;":0x2a97, "emacr;":0x113,
  "empty;":0x2205, "emptyset;":0x2205,
  "emptyv;":0x2205, "emsp;":0x2003,
  "emsp13;":0x2004, "emsp14;":0x2005,
  "eng;":0x14b, "ensp;":0x2002,
  "eogon;":0x119, "eopf;":[0xd835,0xdd56],
  "epar;":0x22d5, "eparsl;":0x29e3,
  "eplus;":0x2a71, "epsi;":0x3b5,
  "epsilon;":0x3b5, "epsiv;":0x3f5,
  "eqcirc;":0x2256, "eqcolon;":0x2255,
  "eqsim;":0x2242, "eqslantgtr;":0x2a96,
  "eqslantless;":0x2a95, "equals;":0x3d,
  "equest;":0x225f, "equiv;":0x2261,
  "equivDD;":0x2a78, "eqvparsl;":0x29e5,
  "erDot;":0x2253, "erarr;":0x2971,
  "escr;":0x212f, "esdot;":0x2250,
  "esim;":0x2242, "eta;":0x3b7,
  "eth;":0xf0, "euml;":0xeb,
  "euro;":0x20ac, "excl;":0x21,
  "exist;":0x2203, "expectation;":0x2130,
  "exponentiale;":0x2147, "fallingdotseq;":0x2252,
  "fcy;":0x444, "female;":0x2640,
  "ffilig;":0xfb03, "fflig;":0xfb00,
  "ffllig;":0xfb04, "ffr;":[0xd835,0xdd23],
  "filig;":0xfb01, "fjlig;":[0x66,0x6a],
  "flat;":0x266d, "fllig;":0xfb02,
  "fltns;":0x25b1, "fnof;":0x192,
  "fopf;":[0xd835,0xdd57], "forall;":0x2200,
  "fork;":0x22d4, "forkv;":0x2ad9,
  "fpartint;":0x2a0d, "frac12;":0xbd,
  "frac13;":0x2153, "frac14;":0xbc,
  "frac15;":0x2155, "frac16;":0x2159,
  "frac18;":0x215b, "frac23;":0x2154,
  "frac25;":0x2156, "frac34;":0xbe,
  "frac35;":0x2157, "frac38;":0x215c,
  "frac45;":0x2158, "frac56;":0x215a,
  "frac58;":0x215d, "frac78;":0x215e,
  "frasl;":0x2044, "frown;":0x2322,
  "fscr;":[0xd835,0xdcbb], "gE;":0x2267,
  "gEl;":0x2a8c, "gacute;":0x1f5,
  "gamma;":0x3b3, "gammad;":0x3dd,
  "gap;":0x2a86, "gbreve;":0x11f,
  "gcirc;":0x11d, "gcy;":0x433,
  "gdot;":0x121, "ge;":0x2265,
  "gel;":0x22db, "geq;":0x2265,
  "geqq;":0x2267, "geqslant;":0x2a7e,
  "ges;":0x2a7e, "gescc;":0x2aa9,
  "gesdot;":0x2a80, "gesdoto;":0x2a82,
  "gesdotol;":0x2a84, "gesl;":[0x22db,0xfe00],
  "gesles;":0x2a94, "gfr;":[0xd835,0xdd24],
  "gg;":0x226b, "ggg;":0x22d9,
  "gimel;":0x2137, "gjcy;":0x453,
  "gl;":0x2277, "glE;":0x2a92,
  "gla;":0x2aa5, "glj;":0x2aa4,
  "gnE;":0x2269, "gnap;":0x2a8a,
  "gnapprox;":0x2a8a, "gne;":0x2a88,
  "gneq;":0x2a88, "gneqq;":0x2269,
  "gnsim;":0x22e7, "gopf;":[0xd835,0xdd58],
  "grave;":0x60, "gscr;":0x210a,
  "gsim;":0x2273, "gsime;":0x2a8e,
  "gsiml;":0x2a90, "gt;":0x3e,
  "gtcc;":0x2aa7, "gtcir;":0x2a7a,
  "gtdot;":0x22d7, "gtlPar;":0x2995,
  "gtquest;":0x2a7c, "gtrapprox;":0x2a86,
  "gtrarr;":0x2978, "gtrdot;":0x22d7,
  "gtreqless;":0x22db, "gtreqqless;":0x2a8c,
  "gtrless;":0x2277, "gtrsim;":0x2273,
  "gvertneqq;":[0x2269,0xfe00], "gvnE;":[0x2269,0xfe00],
  "hArr;":0x21d4, "hairsp;":0x200a,
  "half;":0xbd, "hamilt;":0x210b,
  "hardcy;":0x44a, "harr;":0x2194,
  "harrcir;":0x2948, "harrw;":0x21ad,
  "hbar;":0x210f, "hcirc;":0x125,
  "hearts;":0x2665, "heartsuit;":0x2665,
  "hellip;":0x2026, "hercon;":0x22b9,
  "hfr;":[0xd835,0xdd25], "hksearow;":0x2925,
  "hkswarow;":0x2926, "hoarr;":0x21ff,
  "homtht;":0x223b, "hookleftarrow;":0x21a9,
  "hookrightarrow;":0x21aa, "hopf;":[0xd835,0xdd59],
  "horbar;":0x2015, "hscr;":[0xd835,0xdcbd],
  "hslash;":0x210f, "hstrok;":0x127,
  "hybull;":0x2043, "hyphen;":0x2010,
  "iacute;":0xed, "ic;":0x2063,
  "icirc;":0xee, "icy;":0x438,
  "iecy;":0x435, "iexcl;":0xa1,
  "iff;":0x21d4, "ifr;":[0xd835,0xdd26],
  "igrave;":0xec, "ii;":0x2148,
  "iiiint;":0x2a0c, "iiint;":0x222d,
  "iinfin;":0x29dc, "iiota;":0x2129,
  "ijlig;":0x133, "imacr;":0x12b,
  "image;":0x2111, "imagline;":0x2110,
  "imagpart;":0x2111, "imath;":0x131,
  "imof;":0x22b7, "imped;":0x1b5,
  "in;":0x2208, "incare;":0x2105,
  "infin;":0x221e, "infintie;":0x29dd,
  "inodot;":0x131, "int;":0x222b,
  "intcal;":0x22ba, "integers;":0x2124,
  "intercal;":0x22ba, "intlarhk;":0x2a17,
  "intprod;":0x2a3c, "iocy;":0x451,
  "iogon;":0x12f, "iopf;":[0xd835,0xdd5a],
  "iota;":0x3b9, "iprod;":0x2a3c,
  "iquest;":0xbf, "iscr;":[0xd835,0xdcbe],
  "isin;":0x2208, "isinE;":0x22f9,
  "isindot;":0x22f5, "isins;":0x22f4,
  "isinsv;":0x22f3, "isinv;":0x2208,
  "it;":0x2062, "itilde;":0x129,
  "iukcy;":0x456, "iuml;":0xef,
  "jcirc;":0x135, "jcy;":0x439,
  "jfr;":[0xd835,0xdd27], "jmath;":0x237,
  "jopf;":[0xd835,0xdd5b], "jscr;":[0xd835,0xdcbf],
  "jsercy;":0x458, "jukcy;":0x454,
  "kappa;":0x3ba, "kappav;":0x3f0,
  "kcedil;":0x137, "kcy;":0x43a,
  "kfr;":[0xd835,0xdd28], "kgreen;":0x138,
  "khcy;":0x445, "kjcy;":0x45c,
  "kopf;":[0xd835,0xdd5c], "kscr;":[0xd835,0xdcc0],
  "lAarr;":0x21da, "lArr;":0x21d0,
  "lAtail;":0x291b, "lBarr;":0x290e,
  "lE;":0x2266, "lEg;":0x2a8b,
  "lHar;":0x2962, "lacute;":0x13a,
  "laemptyv;":0x29b4, "lagran;":0x2112,
  "lambda;":0x3bb, "lang;":0x27e8,
  "langd;":0x2991, "langle;":0x27e8,
  "lap;":0x2a85, "laquo;":0xab,
  "larr;":0x2190, "larrb;":0x21e4,
  "larrbfs;":0x291f, "larrfs;":0x291d,
  "larrhk;":0x21a9, "larrlp;":0x21ab,
  "larrpl;":0x2939, "larrsim;":0x2973,
  "larrtl;":0x21a2, "lat;":0x2aab,
  "latail;":0x2919, "late;":0x2aad,
  "lates;":[0x2aad,0xfe00], "lbarr;":0x290c,
  "lbbrk;":0x2772, "lbrace;":0x7b,
  "lbrack;":0x5b, "lbrke;":0x298b,
  "lbrksld;":0x298f, "lbrkslu;":0x298d,
  "lcaron;":0x13e, "lcedil;":0x13c,
  "lceil;":0x2308, "lcub;":0x7b,
  "lcy;":0x43b, "ldca;":0x2936,
  "ldquo;":0x201c, "ldquor;":0x201e,
  "ldrdhar;":0x2967, "ldrushar;":0x294b,
  "ldsh;":0x21b2, "le;":0x2264,
  "leftarrow;":0x2190, "leftarrowtail;":0x21a2,
  "leftharpoondown;":0x21bd, "leftharpoonup;":0x21bc,
  "leftleftarrows;":0x21c7, "leftrightarrow;":0x2194,
  "leftrightarrows;":0x21c6, "leftrightharpoons;":0x21cb,
  "leftrightsquigarrow;":0x21ad, "leftthreetimes;":0x22cb,
  "leg;":0x22da, "leq;":0x2264,
  "leqq;":0x2266, "leqslant;":0x2a7d,
  "les;":0x2a7d, "lescc;":0x2aa8,
  "lesdot;":0x2a7f, "lesdoto;":0x2a81,
  "lesdotor;":0x2a83, "lesg;":[0x22da,0xfe00],
  "lesges;":0x2a93, "lessapprox;":0x2a85,
  "lessdot;":0x22d6, "lesseqgtr;":0x22da,
  "lesseqqgtr;":0x2a8b, "lessgtr;":0x2276,
  "lesssim;":0x2272, "lfisht;":0x297c,
  "lfloor;":0x230a, "lfr;":[0xd835,0xdd29],
  "lg;":0x2276, "lgE;":0x2a91,
  "lhard;":0x21bd, "lharu;":0x21bc,
  "lharul;":0x296a, "lhblk;":0x2584,
  "ljcy;":0x459, "ll;":0x226a,
  "llarr;":0x21c7, "llcorner;":0x231e,
  "llhard;":0x296b, "lltri;":0x25fa,
  "lmidot;":0x140, "lmoust;":0x23b0,
  "lmoustache;":0x23b0, "lnE;":0x2268,
  "lnap;":0x2a89, "lnapprox;":0x2a89,
  "lne;":0x2a87, "lneq;":0x2a87,
  "lneqq;":0x2268, "lnsim;":0x22e6,
  "loang;":0x27ec, "loarr;":0x21fd,
  "lobrk;":0x27e6, "longleftarrow;":0x27f5,
  "longleftrightarrow;":0x27f7, "longmapsto;":0x27fc,
  "longrightarrow;":0x27f6, "looparrowleft;":0x21ab,
  "looparrowright;":0x21ac, "lopar;":0x2985,
  "lopf;":[0xd835,0xdd5d], "loplus;":0x2a2d,
  "lotimes;":0x2a34, "lowast;":0x2217,
  "lowbar;":0x5f, "loz;":0x25ca,
  "lozenge;":0x25ca, "lozf;":0x29eb,
  "lpar;":0x28, "lparlt;":0x2993,
  "lrarr;":0x21c6, "lrcorner;":0x231f,
  "lrhar;":0x21cb, "lrhard;":0x296d,
  "lrm;":0x200e, "lrtri;":0x22bf,
  "lsaquo;":0x2039, "lscr;":[0xd835,0xdcc1],
  "lsh;":0x21b0, "lsim;":0x2272,
  "lsime;":0x2a8d, "lsimg;":0x2a8f,
  "lsqb;":0x5b, "lsquo;":0x2018,
  "lsquor;":0x201a, "lstrok;":0x142,
  "lt;":0x3c, "ltcc;":0x2aa6,
  "ltcir;":0x2a79, "ltdot;":0x22d6,
  "lthree;":0x22cb, "ltimes;":0x22c9,
  "ltlarr;":0x2976, "ltquest;":0x2a7b,
  "ltrPar;":0x2996, "ltri;":0x25c3,
  "ltrie;":0x22b4, "ltrif;":0x25c2,
  "lurdshar;":0x294a, "luruhar;":0x2966,
  "lvertneqq;":[0x2268,0xfe00], "lvnE;":[0x2268,0xfe00],
  "mDDot;":0x223a, "macr;":0xaf,
  "male;":0x2642, "malt;":0x2720,
  "maltese;":0x2720, "map;":0x21a6,
  "mapsto;":0x21a6, "mapstodown;":0x21a7,
  "mapstoleft;":0x21a4, "mapstoup;":0x21a5,
  "marker;":0x25ae, "mcomma;":0x2a29,
  "mcy;":0x43c, "mdash;":0x2014,
  "measuredangle;":0x2221, "mfr;":[0xd835,0xdd2a],
  "mho;":0x2127, "micro;":0xb5,
  "mid;":0x2223, "midast;":0x2a,
  "midcir;":0x2af0, "middot;":0xb7,
  "minus;":0x2212, "minusb;":0x229f,
  "minusd;":0x2238, "minusdu;":0x2a2a,
  "mlcp;":0x2adb, "mldr;":0x2026,
  "mnplus;":0x2213, "models;":0x22a7,
  "mopf;":[0xd835,0xdd5e], "mp;":0x2213,
  "mscr;":[0xd835,0xdcc2], "mstpos;":0x223e,
  "mu;":0x3bc, "multimap;":0x22b8,
  "mumap;":0x22b8, "nGg;":[0x22d9,0x338],
  "nGt;":[0x226b,0x20d2], "nGtv;":[0x226b,0x338],
  "nLeftarrow;":0x21cd, "nLeftrightarrow;":0x21ce,
  "nLl;":[0x22d8,0x338], "nLt;":[0x226a,0x20d2],
  "nLtv;":[0x226a,0x338], "nRightarrow;":0x21cf,
  "nVDash;":0x22af, "nVdash;":0x22ae,
  "nabla;":0x2207, "nacute;":0x144,
  "nang;":[0x2220,0x20d2], "nap;":0x2249,
  "napE;":[0x2a70,0x338], "napid;":[0x224b,0x338],
  "napos;":0x149, "napprox;":0x2249,
  "natur;":0x266e, "natural;":0x266e,
  "naturals;":0x2115, "nbsp;":0xa0,
  "nbump;":[0x224e,0x338], "nbumpe;":[0x224f,0x338],
  "ncap;":0x2a43, "ncaron;":0x148,
  "ncedil;":0x146, "ncong;":0x2247,
  "ncongdot;":[0x2a6d,0x338], "ncup;":0x2a42,
  "ncy;":0x43d, "ndash;":0x2013,
  "ne;":0x2260, "neArr;":0x21d7,
  "nearhk;":0x2924, "nearr;":0x2197,
  "nearrow;":0x2197, "nedot;":[0x2250,0x338],
  "nequiv;":0x2262, "nesear;":0x2928,
  "nesim;":[0x2242,0x338], "nexist;":0x2204,
  "nexists;":0x2204, "nfr;":[0xd835,0xdd2b],
  "ngE;":[0x2267,0x338], "nge;":0x2271,
  "ngeq;":0x2271, "ngeqq;":[0x2267,0x338],
  "ngeqslant;":[0x2a7e,0x338], "nges;":[0x2a7e,0x338],
  "ngsim;":0x2275, "ngt;":0x226f,
  "ngtr;":0x226f, "nhArr;":0x21ce,
  "nharr;":0x21ae, "nhpar;":0x2af2,
  "ni;":0x220b, "nis;":0x22fc,
  "nisd;":0x22fa, "niv;":0x220b,
  "njcy;":0x45a, "nlArr;":0x21cd,
  "nlE;":[0x2266,0x338], "nlarr;":0x219a,
  "nldr;":0x2025, "nle;":0x2270,
  "nleftarrow;":0x219a, "nleftrightarrow;":0x21ae,
  "nleq;":0x2270, "nleqq;":[0x2266,0x338],
  "nleqslant;":[0x2a7d,0x338], "nles;":[0x2a7d,0x338],
  "nless;":0x226e, "nlsim;":0x2274,
  "nlt;":0x226e, "nltri;":0x22ea,
  "nltrie;":0x22ec, "nmid;":0x2224,
  "nopf;":[0xd835,0xdd5f], "not;":0xac,
  "notin;":0x2209, "notinE;":[0x22f9,0x338],
  "notindot;":[0x22f5,0x338], "notinva;":0x2209,
  "notinvb;":0x22f7, "notinvc;":0x22f6,
  "notni;":0x220c, "notniva;":0x220c,
  "notnivb;":0x22fe, "notnivc;":0x22fd,
  "npar;":0x2226, "nparallel;":0x2226,
  "nparsl;":[0x2afd,0x20e5], "npart;":[0x2202,0x338],
  "npolint;":0x2a14, "npr;":0x2280,
  "nprcue;":0x22e0, "npre;":[0x2aaf,0x338],
  "nprec;":0x2280, "npreceq;":[0x2aaf,0x338],
  "nrArr;":0x21cf, "nrarr;":0x219b,
  "nrarrc;":[0x2933,0x338], "nrarrw;":[0x219d,0x338],
  "nrightarrow;":0x219b, "nrtri;":0x22eb,
  "nrtrie;":0x22ed, "nsc;":0x2281,
  "nsccue;":0x22e1, "nsce;":[0x2ab0,0x338],
  "nscr;":[0xd835,0xdcc3], "nshortmid;":0x2224,
  "nshortparallel;":0x2226, "nsim;":0x2241,
  "nsime;":0x2244, "nsimeq;":0x2244,
  "nsmid;":0x2224, "nspar;":0x2226,
  "nsqsube;":0x22e2, "nsqsupe;":0x22e3,
  "nsub;":0x2284, "nsubE;":[0x2ac5,0x338],
  "nsube;":0x2288, "nsubset;":[0x2282,0x20d2],
  "nsubseteq;":0x2288, "nsubseteqq;":[0x2ac5,0x338],
  "nsucc;":0x2281, "nsucceq;":[0x2ab0,0x338],
  "nsup;":0x2285, "nsupE;":[0x2ac6,0x338],
  "nsupe;":0x2289, "nsupset;":[0x2283,0x20d2],
  "nsupseteq;":0x2289, "nsupseteqq;":[0x2ac6,0x338],
  "ntgl;":0x2279, "ntilde;":0xf1,
  "ntlg;":0x2278, "ntriangleleft;":0x22ea,
  "ntrianglelefteq;":0x22ec, "ntriangleright;":0x22eb,
  "ntrianglerighteq;":0x22ed, "nu;":0x3bd,
  "num;":0x23, "numero;":0x2116,
  "numsp;":0x2007, "nvDash;":0x22ad,
  "nvHarr;":0x2904, "nvap;":[0x224d,0x20d2],
  "nvdash;":0x22ac, "nvge;":[0x2265,0x20d2],
  "nvgt;":[0x3e,0x20d2], "nvinfin;":0x29de,
  "nvlArr;":0x2902, "nvle;":[0x2264,0x20d2],
  "nvlt;":[0x3c,0x20d2], "nvltrie;":[0x22b4,0x20d2],
  "nvrArr;":0x2903, "nvrtrie;":[0x22b5,0x20d2],
  "nvsim;":[0x223c,0x20d2], "nwArr;":0x21d6,
  "nwarhk;":0x2923, "nwarr;":0x2196,
  "nwarrow;":0x2196, "nwnear;":0x2927,
  "oS;":0x24c8, "oacute;":0xf3,
  "oast;":0x229b, "ocir;":0x229a,
  "ocirc;":0xf4, "ocy;":0x43e,
  "odash;":0x229d, "odblac;":0x151,
  "odiv;":0x2a38, "odot;":0x2299,
  "odsold;":0x29bc, "oelig;":0x153,
  "ofcir;":0x29bf, "ofr;":[0xd835,0xdd2c],
  "ogon;":0x2db, "ograve;":0xf2,
  "ogt;":0x29c1, "ohbar;":0x29b5,
  "ohm;":0x3a9, "oint;":0x222e,
  "olarr;":0x21ba, "olcir;":0x29be,
  "olcross;":0x29bb, "oline;":0x203e,
  "olt;":0x29c0, "omacr;":0x14d,
  "omega;":0x3c9, "omicron;":0x3bf,
  "omid;":0x29b6, "ominus;":0x2296,
  "oopf;":[0xd835,0xdd60], "opar;":0x29b7,
  "operp;":0x29b9, "oplus;":0x2295,
  "or;":0x2228, "orarr;":0x21bb,
  "ord;":0x2a5d, "order;":0x2134,
  "orderof;":0x2134, "ordf;":0xaa,
  "ordm;":0xba, "origof;":0x22b6,
  "oror;":0x2a56, "orslope;":0x2a57,
  "orv;":0x2a5b, "oscr;":0x2134,
  "oslash;":0xf8, "osol;":0x2298,
  "otilde;":0xf5, "otimes;":0x2297,
  "otimesas;":0x2a36, "ouml;":0xf6,
  "ovbar;":0x233d, "par;":0x2225,
  "para;":0xb6, "parallel;":0x2225,
  "parsim;":0x2af3, "parsl;":0x2afd,
  "part;":0x2202, "pcy;":0x43f,
  "percnt;":0x25, "period;":0x2e,
  "permil;":0x2030, "perp;":0x22a5,
  "pertenk;":0x2031, "pfr;":[0xd835,0xdd2d],
  "phi;":0x3c6, "phiv;":0x3d5,
  "phmmat;":0x2133, "phone;":0x260e,
  "pi;":0x3c0, "pitchfork;":0x22d4,
  "piv;":0x3d6, "planck;":0x210f,
  "planckh;":0x210e, "plankv;":0x210f,
  "plus;":0x2b, "plusacir;":0x2a23,
  "plusb;":0x229e, "pluscir;":0x2a22,
  "plusdo;":0x2214, "plusdu;":0x2a25,
  "pluse;":0x2a72, "plusmn;":0xb1,
  "plussim;":0x2a26, "plustwo;":0x2a27,
  "pm;":0xb1, "pointint;":0x2a15,
  "popf;":[0xd835,0xdd61], "pound;":0xa3,
  "pr;":0x227a, "prE;":0x2ab3,
  "prap;":0x2ab7, "prcue;":0x227c,
  "pre;":0x2aaf, "prec;":0x227a,
  "precapprox;":0x2ab7, "preccurlyeq;":0x227c,
  "preceq;":0x2aaf, "precnapprox;":0x2ab9,
  "precneqq;":0x2ab5, "precnsim;":0x22e8,
  "precsim;":0x227e, "prime;":0x2032,
  "primes;":0x2119, "prnE;":0x2ab5,
  "prnap;":0x2ab9, "prnsim;":0x22e8,
  "prod;":0x220f, "profalar;":0x232e,
  "profline;":0x2312, "profsurf;":0x2313,
  "prop;":0x221d, "propto;":0x221d,
  "prsim;":0x227e, "prurel;":0x22b0,
  "pscr;":[0xd835,0xdcc5], "psi;":0x3c8,
  "puncsp;":0x2008, "qfr;":[0xd835,0xdd2e],
  "qint;":0x2a0c, "qopf;":[0xd835,0xdd62],
  "qprime;":0x2057, "qscr;":[0xd835,0xdcc6],
  "quaternions;":0x210d, "quatint;":0x2a16,
  "quest;":0x3f, "questeq;":0x225f,
  "quot;":0x22, "rAarr;":0x21db,
  "rArr;":0x21d2, "rAtail;":0x291c,
  "rBarr;":0x290f, "rHar;":0x2964,
  "race;":[0x223d,0x331], "racute;":0x155,
  "radic;":0x221a, "raemptyv;":0x29b3,
  "rang;":0x27e9, "rangd;":0x2992,
  "range;":0x29a5, "rangle;":0x27e9,
  "raquo;":0xbb, "rarr;":0x2192,
  "rarrap;":0x2975, "rarrb;":0x21e5,
  "rarrbfs;":0x2920, "rarrc;":0x2933,
  "rarrfs;":0x291e, "rarrhk;":0x21aa,
  "rarrlp;":0x21ac, "rarrpl;":0x2945,
  "rarrsim;":0x2974, "rarrtl;":0x21a3,
  "rarrw;":0x219d, "ratail;":0x291a,
  "ratio;":0x2236, "rationals;":0x211a,
  "rbarr;":0x290d, "rbbrk;":0x2773,
  "rbrace;":0x7d, "rbrack;":0x5d,
  "rbrke;":0x298c, "rbrksld;":0x298e,
  "rbrkslu;":0x2990, "rcaron;":0x159,
  "rcedil;":0x157, "rceil;":0x2309,
  "rcub;":0x7d, "rcy;":0x440,
  "rdca;":0x2937, "rdldhar;":0x2969,
  "rdquo;":0x201d, "rdquor;":0x201d,
  "rdsh;":0x21b3, "real;":0x211c,
  "realine;":0x211b, "realpart;":0x211c,
  "reals;":0x211d, "rect;":0x25ad,
  "reg;":0xae, "rfisht;":0x297d,
  "rfloor;":0x230b, "rfr;":[0xd835,0xdd2f],
  "rhard;":0x21c1, "rharu;":0x21c0,
  "rharul;":0x296c, "rho;":0x3c1,
  "rhov;":0x3f1, "rightarrow;":0x2192,
  "rightarrowtail;":0x21a3, "rightharpoondown;":0x21c1,
  "rightharpoonup;":0x21c0, "rightleftarrows;":0x21c4,
  "rightleftharpoons;":0x21cc, "rightrightarrows;":0x21c9,
  "rightsquigarrow;":0x219d, "rightthreetimes;":0x22cc,
  "ring;":0x2da, "risingdotseq;":0x2253,
  "rlarr;":0x21c4, "rlhar;":0x21cc,
  "rlm;":0x200f, "rmoust;":0x23b1,
  "rmoustache;":0x23b1, "rnmid;":0x2aee,
  "roang;":0x27ed, "roarr;":0x21fe,
  "robrk;":0x27e7, "ropar;":0x2986,
  "ropf;":[0xd835,0xdd63], "roplus;":0x2a2e,
  "rotimes;":0x2a35, "rpar;":0x29,
  "rpargt;":0x2994, "rppolint;":0x2a12,
  "rrarr;":0x21c9, "rsaquo;":0x203a,
  "rscr;":[0xd835,0xdcc7], "rsh;":0x21b1,
  "rsqb;":0x5d, "rsquo;":0x2019,
  "rsquor;":0x2019, "rthree;":0x22cc,
  "rtimes;":0x22ca, "rtri;":0x25b9,
  "rtrie;":0x22b5, "rtrif;":0x25b8,
  "rtriltri;":0x29ce, "ruluhar;":0x2968,
  "rx;":0x211e, "sacute;":0x15b,
  "sbquo;":0x201a, "sc;":0x227b,
  "scE;":0x2ab4, "scap;":0x2ab8,
  "scaron;":0x161, "sccue;":0x227d,
  "sce;":0x2ab0, "scedil;":0x15f,
  "scirc;":0x15d, "scnE;":0x2ab6,
  "scnap;":0x2aba, "scnsim;":0x22e9,
  "scpolint;":0x2a13, "scsim;":0x227f,
  "scy;":0x441, "sdot;":0x22c5,
  "sdotb;":0x22a1, "sdote;":0x2a66,
  "seArr;":0x21d8, "searhk;":0x2925,
  "searr;":0x2198, "searrow;":0x2198,
  "sect;":0xa7, "semi;":0x3b,
  "seswar;":0x2929, "setminus;":0x2216,
  "setmn;":0x2216, "sext;":0x2736,
  "sfr;":[0xd835,0xdd30], "sfrown;":0x2322,
  "sharp;":0x266f, "shchcy;":0x449,
  "shcy;":0x448, "shortmid;":0x2223,
  "shortparallel;":0x2225, "shy;":0xad,
  "sigma;":0x3c3, "sigmaf;":0x3c2,
  "sigmav;":0x3c2, "sim;":0x223c,
  "simdot;":0x2a6a, "sime;":0x2243,
  "simeq;":0x2243, "simg;":0x2a9e,
  "simgE;":0x2aa0, "siml;":0x2a9d,
  "simlE;":0x2a9f, "simne;":0x2246,
  "simplus;":0x2a24, "simrarr;":0x2972,
  "slarr;":0x2190, "smallsetminus;":0x2216,
  "smashp;":0x2a33, "smeparsl;":0x29e4,
  "smid;":0x2223, "smile;":0x2323,
  "smt;":0x2aaa, "smte;":0x2aac,
  "smtes;":[0x2aac,0xfe00], "softcy;":0x44c,
  "sol;":0x2f, "solb;":0x29c4,
  "solbar;":0x233f, "sopf;":[0xd835,0xdd64],
  "spades;":0x2660, "spadesuit;":0x2660,
  "spar;":0x2225, "sqcap;":0x2293,
  "sqcaps;":[0x2293,0xfe00], "sqcup;":0x2294,
  "sqcups;":[0x2294,0xfe00], "sqsub;":0x228f,
  "sqsube;":0x2291, "sqsubset;":0x228f,
  "sqsubseteq;":0x2291, "sqsup;":0x2290,
  "sqsupe;":0x2292, "sqsupset;":0x2290,
  "sqsupseteq;":0x2292, "squ;":0x25a1,
  "square;":0x25a1, "squarf;":0x25aa,
  "squf;":0x25aa, "srarr;":0x2192,
  "sscr;":[0xd835,0xdcc8], "ssetmn;":0x2216,
  "ssmile;":0x2323, "sstarf;":0x22c6,
  "star;":0x2606, "starf;":0x2605,
  "straightepsilon;":0x3f5, "straightphi;":0x3d5,
  "strns;":0xaf, "sub;":0x2282,
  "subE;":0x2ac5, "subdot;":0x2abd,
  "sube;":0x2286, "subedot;":0x2ac3,
  "submult;":0x2ac1, "subnE;":0x2acb,
  "subne;":0x228a, "subplus;":0x2abf,
  "subrarr;":0x2979, "subset;":0x2282,
  "subseteq;":0x2286, "subseteqq;":0x2ac5,
  "subsetneq;":0x228a, "subsetneqq;":0x2acb,
  "subsim;":0x2ac7, "subsub;":0x2ad5,
  "subsup;":0x2ad3, "succ;":0x227b,
  "succapprox;":0x2ab8, "succcurlyeq;":0x227d,
  "succeq;":0x2ab0, "succnapprox;":0x2aba,
  "succneqq;":0x2ab6, "succnsim;":0x22e9,
  "succsim;":0x227f, "sum;":0x2211,
  "sung;":0x266a, "sup;":0x2283,
  "sup1;":0xb9, "sup2;":0xb2,
  "sup3;":0xb3, "supE;":0x2ac6,
  "supdot;":0x2abe, "supdsub;":0x2ad8,
  "supe;":0x2287, "supedot;":0x2ac4,
  "suphsol;":0x27c9, "suphsub;":0x2ad7,
  "suplarr;":0x297b, "supmult;":0x2ac2,
  "supnE;":0x2acc, "supne;":0x228b,
  "supplus;":0x2ac0, "supset;":0x2283,
  "supseteq;":0x2287, "supseteqq;":0x2ac6,
  "supsetneq;":0x228b, "supsetneqq;":0x2acc,
  "supsim;":0x2ac8, "supsub;":0x2ad4,
  "supsup;":0x2ad6, "swArr;":0x21d9,
  "swarhk;":0x2926, "swarr;":0x2199,
  "swarrow;":0x2199, "swnwar;":0x292a,
  "szlig;":0xdf, "target;":0x2316,
  "tau;":0x3c4, "tbrk;":0x23b4,
  "tcaron;":0x165, "tcedil;":0x163,
  "tcy;":0x442, "tdot;":0x20db,
  "telrec;":0x2315, "tfr;":[0xd835,0xdd31],
  "there4;":0x2234, "therefore;":0x2234,
  "theta;":0x3b8, "thetasym;":0x3d1,
  "thetav;":0x3d1, "thickapprox;":0x2248,
  "thicksim;":0x223c, "thinsp;":0x2009,
  "thkap;":0x2248, "thksim;":0x223c,
  "thorn;":0xfe, "tilde;":0x2dc,
  "times;":0xd7, "timesb;":0x22a0,
  "timesbar;":0x2a31, "timesd;":0x2a30,
  "tint;":0x222d, "toea;":0x2928,
  "top;":0x22a4, "topbot;":0x2336,
  "topcir;":0x2af1, "topf;":[0xd835,0xdd65],
  "topfork;":0x2ada, "tosa;":0x2929,
  "tprime;":0x2034, "trade;":0x2122,
  "triangle;":0x25b5, "triangledown;":0x25bf,
  "triangleleft;":0x25c3, "trianglelefteq;":0x22b4,
  "triangleq;":0x225c, "triangleright;":0x25b9,
  "trianglerighteq;":0x22b5, "tridot;":0x25ec,
  "trie;":0x225c, "triminus;":0x2a3a,
  "triplus;":0x2a39, "trisb;":0x29cd,
  "tritime;":0x2a3b, "trpezium;":0x23e2,
  "tscr;":[0xd835,0xdcc9], "tscy;":0x446,
  "tshcy;":0x45b, "tstrok;":0x167,
  "twixt;":0x226c, "twoheadleftarrow;":0x219e,
  "twoheadrightarrow;":0x21a0, "uArr;":0x21d1,
  "uHar;":0x2963, "uacute;":0xfa,
  "uarr;":0x2191, "ubrcy;":0x45e,
  "ubreve;":0x16d, "ucirc;":0xfb,
  "ucy;":0x443, "udarr;":0x21c5,
  "udblac;":0x171, "udhar;":0x296e,
  "ufisht;":0x297e, "ufr;":[0xd835,0xdd32],
  "ugrave;":0xf9, "uharl;":0x21bf,
  "uharr;":0x21be, "uhblk;":0x2580,
  "ulcorn;":0x231c, "ulcorner;":0x231c,
  "ulcrop;":0x230f, "ultri;":0x25f8,
  "umacr;":0x16b, "uml;":0xa8,
  "uogon;":0x173, "uopf;":[0xd835,0xdd66],
  "uparrow;":0x2191, "updownarrow;":0x2195,
  "upharpoonleft;":0x21bf, "upharpoonright;":0x21be,
  "uplus;":0x228e, "upsi;":0x3c5,
  "upsih;":0x3d2, "upsilon;":0x3c5,
  "upuparrows;":0x21c8, "urcorn;":0x231d,
  "urcorner;":0x231d, "urcrop;":0x230e,
  "uring;":0x16f, "urtri;":0x25f9,
  "uscr;":[0xd835,0xdcca], "utdot;":0x22f0,
  "utilde;":0x169, "utri;":0x25b5,
  "utrif;":0x25b4, "uuarr;":0x21c8,
  "uuml;":0xfc, "uwangle;":0x29a7,
  "vArr;":0x21d5, "vBar;":0x2ae8,
  "vBarv;":0x2ae9, "vDash;":0x22a8,
  "vangrt;":0x299c, "varepsilon;":0x3f5,
  "varkappa;":0x3f0, "varnothing;":0x2205,
  "varphi;":0x3d5, "varpi;":0x3d6,
  "varpropto;":0x221d, "varr;":0x2195,
  "varrho;":0x3f1, "varsigma;":0x3c2,
  "varsubsetneq;":[0x228a,0xfe00], "varsubsetneqq;":[0x2acb,0xfe00],
  "varsupsetneq;":[0x228b,0xfe00], "varsupsetneqq;":[0x2acc,0xfe00],
  "vartheta;":0x3d1, "vartriangleleft;":0x22b2,
  "vartriangleright;":0x22b3, "vcy;":0x432,
  "vdash;":0x22a2, "vee;":0x2228,
  "veebar;":0x22bb, "veeeq;":0x225a,
  "vellip;":0x22ee, "verbar;":0x7c,
  "vert;":0x7c, "vfr;":[0xd835,0xdd33],
  "vltri;":0x22b2, "vnsub;":[0x2282,0x20d2],
  "vnsup;":[0x2283,0x20d2], "vopf;":[0xd835,0xdd67],
  "vprop;":0x221d, "vrtri;":0x22b3,
  "vscr;":[0xd835,0xdccb], "vsubnE;":[0x2acb,0xfe00],
  "vsubne;":[0x228a,0xfe00], "vsupnE;":[0x2acc,0xfe00],
  "vsupne;":[0x228b,0xfe00], "vzigzag;":0x299a,
  "wcirc;":0x175, "wedbar;":0x2a5f,
  "wedge;":0x2227, "wedgeq;":0x2259,
  "weierp;":0x2118, "wfr;":[0xd835,0xdd34],
  "wopf;":[0xd835,0xdd68], "wp;":0x2118,
  "wr;":0x2240, "wreath;":0x2240,
  "wscr;":[0xd835,0xdccc], "xcap;":0x22c2,
  "xcirc;":0x25ef, "xcup;":0x22c3,
  "xdtri;":0x25bd, "xfr;":[0xd835,0xdd35],
  "xhArr;":0x27fa, "xharr;":0x27f7,
  "xi;":0x3be, "xlArr;":0x27f8,
  "xlarr;":0x27f5, "xmap;":0x27fc,
  "xnis;":0x22fb, "xodot;":0x2a00,
  "xopf;":[0xd835,0xdd69], "xoplus;":0x2a01,
  "xotime;":0x2a02, "xrArr;":0x27f9,
  "xrarr;":0x27f6, "xscr;":[0xd835,0xdccd],
  "xsqcup;":0x2a06, "xuplus;":0x2a04,
  "xutri;":0x25b3, "xvee;":0x22c1,
  "xwedge;":0x22c0, "yacute;":0xfd,
  "yacy;":0x44f, "ycirc;":0x177,
  "ycy;":0x44b, "yen;":0xa5,
  "yfr;":[0xd835,0xdd36], "yicy;":0x457,
  "yopf;":[0xd835,0xdd6a], "yscr;":[0xd835,0xdcce],
  "yucy;":0x44e, "yuml;":0xff,
  "zacute;":0x17a, "zcaron;":0x17e,
  "zcy;":0x437, "zdot;":0x17c,
  "zeetrf;":0x2128, "zeta;":0x3b6,
  "zfr;":[0xd835,0xdd37], "zhcy;":0x436,
  "zigrarr;":0x21dd, "zopf;":[0xd835,0xdd6b],
  "zscr;":[0xd835,0xdccf], "zwj;":0x200d,
  "zwnj;":0x200c
};

// Regular expression constants used by the tokenizer and parser

// This regular expression matches the portion of a character reference
// (decimal, hex, or named) that comes after the ampersand. I'd like to
// use the y modifier to make it match at lastIndex, but for compatability
// with Node, I can't.
var CHARREF = /^#[0-9]+[^0-9]|^#[xX][0-9a-fA-F]+[^0-9a-fA-F]|^[a-zA-Z][a-zA-Z0-9]*[^a-zA-Z0-9]/;

// Like the above, but for named char refs, the last char can't be =
var ATTRCHARREF = /^#[0-9]+[^0-9]|^#[xX][0-9a-fA-F]+[^0-9a-fA-F]|^[a-zA-Z][a-zA-Z0-9]*[^=a-zA-Z0-9]/;

var DATATEXT = /[^&<\r\u0000\uffff]*/g;
var RAWTEXT = /[^<\r\u0000\uffff]*/g;
var PLAINTEXT = /[^\r\u0000\uffff]*/g;
var SIMPLETAG = /^(\/)?([a-z]+)>/g;
var SIMPLEATTR = /^([a-z]+) *= *('[^'&\r\u0000]*'|"[^"&\r\u0000]*"|[^&> \t\n\r\f\u0000][ \t\n\f])/g;

var NONWS = /[^\x09\x0A\x0C\x0D\x20]/;
var ALLNONWS = /[^\x09\x0A\x0C\x0D\x20]/g; // like above, with g flag
var NONWSNONNUL = /[^\x00\x09\x0A\x0C\x0D\x20]/; // don't allow NUL either
var LEADINGWS = /^[\x09\x0A\x0C\x0D\x20]+/;
var NULCHARS = /\x00/g;

/***
 * These are utility functions that don't use any of the parser's
 * internal state.
 */
function buf2str(buf) {
  var CHUNKSIZE=16384;
  if (buf.length < CHUNKSIZE) {
    return String.fromCharCode.apply(String, buf);
  }
  // special case for large strings, to avoid busting the stack.
  var result = '';
  for (var i = 0; i < buf.length; i += CHUNKSIZE) {
    result += String.fromCharCode.apply(String, buf.slice(i, i+CHUNKSIZE));
  }
  return result;
}

// Determine whether the element is a member of the set.
// The set is an object that maps namespaces to objects. The objects
// then map local tagnames to the value true if that tag is part of the set
function isA(elt, set) {
  var tagnames = set[elt.namespaceURI];
  return tagnames && tagnames[elt.localName];
}

function isMathmlTextIntegrationPoint(n) {
  return isA(n, mathmlTextIntegrationPointSet);
}

function isHTMLIntegrationPoint(n) {
  if (isA(n, htmlIntegrationPointSet)) return true;
  if (n.namespaceURI === NAMESPACE.MATHML &&
    n.localName === "annotation-xml") {
    var encoding = n.getAttribute("encoding");
    if (encoding) encoding = encoding.toLowerCase();
    if (encoding === "text/html" ||
      encoding === "application/xhtml+xml")
      return true;
  }
  return false;
}

function adjustSVGTagName(name) {
  if (name in svgTagNameAdjustments)
    return svgTagNameAdjustments[name];
  else
    return name;
}

function adjustSVGAttributes(attrs) {
  for(var i = 0, n = attrs.length; i < n; i++) {
    if (attrs[i][0] in svgAttrAdjustments) {
      attrs[i][0] = svgAttrAdjustments[attrs[i][0]];
    }
  }
}

function adjustMathMLAttributes(attrs) {
  for(var i = 0, n = attrs.length; i < n; i++) {
    if (attrs[i][0] === "definitionurl") {
      attrs[i][0] = "definitionURL";
      break;
    }
  }
}

function adjustForeignAttributes(attrs) {
  for(var i = 0, n = attrs.length; i < n; i++) {
    if (attrs[i][0] in foreignAttributes) {
      // Attributes with namespaces get a 3rd element:
      // [Qname, value, namespace]
      attrs[i].push(foreignAttributes[attrs[i][0]]);
    }
  }
}

// For each attribute in attrs, if elt doesn't have an attribute
// by that name, add the attribute to elt
// XXX: I'm ignoring namespaces for now
function transferAttributes(attrs, elt) {
  for(var i = 0, n = attrs.length; i < n; i++) {
    var name = attrs[i][0], value = attrs[i][1];
    if (elt.hasAttribute(name)) continue;
    elt._setAttribute(name, value);
  }
}

/***
 * The ElementStack class
 */
HTMLParser.ElementStack = function ElementStack() {
  this.elements = [];
  this.top = null; // stack.top is the "current node" in the spec
};

/*
// This is for debugging only
HTMLParser.ElementStack.prototype.toString = function(e) {
  return "STACK: " +
  this.elements.map(function(e) {return e.localName;}).join("-");
}
*/

HTMLParser.ElementStack.prototype.push = function(e) {
  this.elements.push(e);
  this.top = e;
};

HTMLParser.ElementStack.prototype.pop = function(e) {
  this.elements.pop();
  this.top = this.elements[this.elements.length-1];
};

// Pop elements off the stack up to and including the first
// element with the specified (HTML) tagname
HTMLParser.ElementStack.prototype.popTag = function(tag) {
  for(var i = this.elements.length-1; i >= 0; i--) {
    var e = this.elements[i];
    if (e.namespaceURI !== NAMESPACE.HTML) continue;
    if (e.localName === tag) break;
  }
  this.elements.length = i;
  this.top = this.elements[i-1];
};

// Pop elements off the stack up to and including the first
// element that is an instance of the specified type
HTMLParser.ElementStack.prototype.popElementType = function(type) {
  for(var i = this.elements.length-1; i >= 0; i--) {
    if (this.elements[i] instanceof type) break;
  }
  this.elements.length = i;
  this.top = this.elements[i-1];
};

// Pop elements off the stack up to and including the element e.
// Note that this is very different from removeElement()
// This requires that e is on the stack.
HTMLParser.ElementStack.prototype.popElement = function(e) {
  for(var i = this.elements.length-1; i >= 0; i--) {
    if (this.elements[i] === e) break;
  }
  this.elements.length = i;
  this.top = this.elements[i-1];
};

// Remove a specific element from the stack.
// Do nothing if the element is not on the stack
HTMLParser.ElementStack.prototype.removeElement = function(e) {
  if (this.top === e) this.pop();
  else {
    var idx = this.elements.lastIndexOf(e);
    if (idx !== -1)
      this.elements.splice(idx, 1);
  }
};

HTMLParser.ElementStack.prototype.clearToContext = function(type) {
  // Note that we don't loop to 0. Never pop the <html> elt off.
  for(var i = this.elements.length-1; i > 0; i--) {
    if (this.elements[i] instanceof type) break;
  }
  this.elements.length = i+1;
  this.top = this.elements[i];
};

HTMLParser.ElementStack.prototype.inSpecificScope = function(tag, set) {
  for(var i = this.elements.length-1; i >= 0; i--) {
    var elt = this.elements[i];
    var ns = elt.namespaceURI;
    var localname = elt.localName;
    if (ns === NAMESPACE.HTML && localname === tag) return true;
    var tags = set[ns];
    if (tags && localname in tags) return false;
  }
  return false;
};

// Like the above, but for a specific element, not a tagname
HTMLParser.ElementStack.prototype.elementInSpecificScope = function(target, set) {
  for(var i = this.elements.length-1; i >= 0; i--) {
    var elt = this.elements[i];
    if (elt === target) return true;
    var tags = set[elt.namespaceURI];
    if (tags && elt.localName in tags) return false;
  }
  return false;
};

// Like the above, but for an element interface, not a tagname
HTMLParser.ElementStack.prototype.elementTypeInSpecificScope = function(target, set) {
  for(var i = this.elements.length-1; i >= 0; i--) {
    var elt = this.elements[i];
    if (elt instanceof target) return true;
    var tags = set[elt.namespaceURI];
    if (tags && elt.localName in tags) return false;
  }
  return false;
};

HTMLParser.ElementStack.prototype.inScope = function(tag) {
  return this.inSpecificScope(tag, inScopeSet);
};

HTMLParser.ElementStack.prototype.elementInScope = function(e) {
  return this.elementInSpecificScope(e, inScopeSet);
};

HTMLParser.ElementStack.prototype.elementTypeInScope = function(type) {
  return this.elementTypeInSpecificScope(type, inScopeSet);
};

HTMLParser.ElementStack.prototype.inButtonScope = function(tag) {
  return this.inSpecificScope(tag, inButtonScopeSet);
};

HTMLParser.ElementStack.prototype.inListItemScope = function(tag) {
  return this.inSpecificScope(tag, inListItemScopeSet);
};

HTMLParser.ElementStack.prototype.inTableScope = function(tag) {
  return this.inSpecificScope(tag, inTableScopeSet);
};

HTMLParser.ElementStack.prototype.inSelectScope = function(tag) {
  // Can't implement this one with inSpecificScope, since it involves
  // a set defined by inverting another set. So implement manually.
  for(var i = this.elements.length-1; i >= 0; i--) {
    var elt = this.elements[i];
    if (elt.namespaceURI !== NAMESPACE.HTML) return false;
    var localname = elt.localName;
    if (localname === tag) return true;
    if (localname !== "optgroup" && localname !== "option")
      return false;
  }
  return false;
};

HTMLParser.ElementStack.prototype.generateImpliedEndTags = function(butnot) {
  for(var i = this.elements.length-1; i >= 0; i--) {
    var e = this.elements[i];
    if (butnot && e.localName === butnot) break;
    if (!isA(this.elements[i], impliedEndTagsSet)) break;
  }

  this.elements.length = i+1;
  this.top = this.elements[i];
};

/***
 * The ActiveFormattingElements class
 */
HTMLParser.ActiveFormattingElements = function AFE() {
  this.list = []; // elements
  this.attrs = []; // attribute tokens for cloning
};

HTMLParser.ActiveFormattingElements.prototype.MARKER = { localName: "|" };

/*
// For debugging
HTMLParser.ActiveFormattingElements.prototype.toString = function() {
  return "AFE: " +
  this.list.map(function(e) { return e.localName; }).join("-");
}
*/

HTMLParser.ActiveFormattingElements.prototype.insertMarker = function() {
  this.list.push(this.MARKER);
  this.attrs.push(this.MARKER);
};

HTMLParser.ActiveFormattingElements.prototype.push = function(elt, attrs) {
  // Scan backwards: if there are already 3 copies of this element
  // before we encounter a marker, then drop the last one
  var count = 0;
  for(var i = this.list.length-1; i >= 0; i--) {
    if (this.list[i] === this.MARKER) break;
    // equal() is defined below
    if (equal(elt, this.list[i], this.attrs[i])) {
      count++;
      if (count === 3) {
        this.list.splice(i, 1);
        this.attrs.splice(i, 1);
        break;
      }
    }
  }


  // Now push the element onto the list
  this.list.push(elt);

  // Copy the attributes and push those on, too
  var attrcopy = [];
  for(var i = 0; i < attrs.length; i++) {
    attrcopy[i] = attrs[i];
  }

  this.attrs.push(attrcopy);

  // This function defines equality of two elements for the purposes
  // of the AFE list.  Note that it compares the new elements
  // attributes to the saved array of attributes associated with
  // the old element because a script could have changed the
  // old element's set of attributes
  function equal(newelt, oldelt, oldattrs) {
    if (newelt.localName !== oldelt.localName) return false;
    if (newelt._numattrs !== oldattrs.length) return false;
    for(var i = 0, n = oldattrs.length; i < n; i++) {
      var oldname = oldattrs[i][0];
      var oldval = oldattrs[i][1];
      if (!newelt.hasAttribute(oldname)) return false;
      if (newelt.getAttribute(oldname) !== oldval) return false;
    }
    return true;
  }
};

HTMLParser.ActiveFormattingElements.prototype.clearToMarker = function() {
  for(var i = this.list.length-1; i >= 0; i--) {
    if (this.list[i] === this.MARKER) break;
  }
  if (i < 0) i = 0;
  this.list.length = i;
  this.attrs.length = i;
};

// Find and return the last element with the specified tag between the
// end of the list and the last marker on the list.
// Used when parsing <a> in_body_mode()
HTMLParser.ActiveFormattingElements.prototype.findElementByTag = function(tag) {
  for(var i = this.list.length-1; i >= 0; i--) {
    var elt = this.list[i];
    if (elt === this.MARKER) break;
    if (elt.localName === tag) return elt;
  }
  return null;
};

HTMLParser.ActiveFormattingElements.prototype.indexOf = function(e) {
  return this.list.lastIndexOf(e);
};

// Find the element e in the list and remove it
// Used when parsing <a> in_body()
HTMLParser.ActiveFormattingElements.prototype.remove = function(e) {
  var idx = this.list.lastIndexOf(e);
  if (idx !== -1) {
    this.list.splice(idx, 1);
    this.attrs.splice(idx, 1);
  }
};

// Find element a in the list and replace it with element b
// XXX: Do I need to handle attributes here?
HTMLParser.ActiveFormattingElements.prototype.replace = function(a, b, attrs) {
  var idx = this.list.lastIndexOf(a);
  if (idx !== -1) {
    this.list[idx] = b;
    if (attrs) this.attrs[idx] = attrs;
  }
};

// Find a in the list and insert b after it
// This is only used for insert a bookmark object, so the
// attrs array doesn't really matter
HTMLParser.ActiveFormattingElements.prototype.insertAfter = function(a,b) {
  var idx = this.list.lastIndexOf(a);
  if (idx !== -1) {
    this.list.splice(idx, 0, b);
    this.attrs.splice(idx, 0, b);
  }
};




/***
 * This is the parser factory function. It is the return value of
 * the outer closure that it is defined within.  Most of the parser
 * implementation details are inside this function.
 */
function HTMLParser(address, fragmentContext, options) {
  /***
   * These are the parser's state variables
   */
  // Scanner state
  var chars = null;
  var numchars = 0; // Length of chars
  var nextchar = 0; // Index of next char
  var input_complete = false; // Becomes true when end() called.
  var scanner_skip_newline = false; // If previous char was CR
  var reentrant_invocations = 0;
  var saved_scanner_state = [];
  var leftovers = "";
  var first_batch = true;
  var paused = 0; // Becomes non-zero while loading scripts


  // Tokenizer state
  var tokenizer = data_state; // Current tokenizer state
  var savedTokenizerStates = []; // Stack of saved states
  var tagnamebuf = [];
  var lasttagname = ""; // holds the target end tag for text states
  var tempbuf = [];
  var attrnamebuf = [];
  var attrvaluebuf = [];
  var commentbuf = [];
  var doctypenamebuf = [];
  var doctypepublicbuf = [];
  var doctypesystembuf = [];
  var attributes = [];
  var is_end_tag = false;

  // Tree builder state
  var parser = initial_mode; // Current insertion mode
  var originalInsertionMode = null; // A saved insertion mode
  var stack = new HTMLParser.ElementStack(); // Stack of open elements
  var afe = new HTMLParser.ActiveFormattingElements(); // mis-nested tags
  var fragment = (fragmentContext!==undefined); // For innerHTML, etc.
  var script_nesting_level = 0;
  var parser_pause_flag = false;
  var head_element_pointer = null;
  var form_element_pointer = null;
  var scripting_enabled = true;
  if (options && options.scripting_enabled === false)
    scripting_enabled = false;
  var frameset_ok = true;
  var force_quirks = false;
  var pending_table_text;
  var text_integration_mode; // XXX a spec bug workaround?

  // A single run of characters, buffered up to be sent to
  // the parser as a single string.
  var textrun = [];
  var textIncludesNUL = false;
  var ignore_linefeed = false;

  /***
   * This is the parser object that will be the return value of this
   * factory function, which is some 5000 lines below.
   * Note that the variable "parser" is the current state of the
   * parser's state machine.  This variable "htmlparser" is the
   * return value and defines the public API of the parser
   */
  var htmlparser = {
    document: function() {
      return doc;
    },

    // Internal function used from HTMLScriptElement to pause the
    // parser while a script is being loaded from the network
    pause: function() {
      // print("pausing parser");
      paused++;
    },

    // Called when a script finishes loading
    resume: function() {
      // print("resuming parser");
      paused--;
      // XXX: added this to force a resumption.
      // Is this the right thing to do?
      this.parse("");
    },

    // Parse the HTML text s.
    // The second argument should be true if there is no more
    // text to be parsed, and should be false or omitted otherwise.
    // The second argument must not be set for recursive invocations
    // from document.write()
    parse: function(s, end) {

      // If we're paused, remember the text to parse, but
      // don't parse it now.
      if (paused > 0) {
        leftovers += s;
        return;
      }


      if (reentrant_invocations === 0) {
        // A normal, top-level invocation
        if (leftovers) {
          s = leftovers + s;
          leftovers = "";
        }

        // Add a special marker character to the end of
        // the buffer.  If the scanner is at the end of
        // the buffer and input_complete is set, then this
        // character will transform into an EOF token.
        // Having an actual character that represents EOF
        // in the character buffer makes lookahead regexp
        // matching work more easily, and this is
        // important for character references.
        if (end) {
          s += "\uFFFF";
          input_complete = true; // Makes scanChars() send EOF
        }

        chars = s;
        numchars = s.length;
        nextchar = 0;

        if (first_batch) {
          // We skip a leading Byte Order Mark (\uFEFF)
          // on first batch of text we're given
          first_batch = false;
          if (chars.charCodeAt(0) === 0xFEFF) nextchar = 1;
        }

        reentrant_invocations++;
        scanChars();
        leftovers = chars.substring(nextchar, numchars);
        reentrant_invocations--;
      }
      else {
        // This is the re-entrant case, which we have to
        // handle a little differently.
        reentrant_invocations++;

        // Save current scanner state
        saved_scanner_state.push(chars, numchars, nextchar);

        // Set new scanner state
        chars = s;
        numchars = s.length;
        nextchar = 0;

        // Now scan as many of these new chars as we can
        scanChars();

        leftovers = chars.substring(nextchar, numchars);

        // restore old scanner state
        nextchar = saved_scanner_state.pop();
        numchars = saved_scanner_state.pop();
        chars = saved_scanner_state.pop();

        // If there were leftover chars from this invocation
        // insert them into the pending invocation's buffer
        // and trim already processed chars at the same time
        if (leftovers) {
          chars = leftovers + chars.substring(nextchar);
          numchars = chars.length;
          nextchar = 0;
          leftovers = "";
        }

        // Decrement the counter
        reentrant_invocations--;
      }
    }
  };


  // This is the document we'll be building up
  var doc = new Document(true, address);

  // The document needs to know about the parser, for document.write().
  // This _parser property will be deleted when we're done parsing.
  doc._parser = htmlparser;

  // XXX I think that any document we use this parser on should support
  // scripts. But I may need to configure that through a parser parameter
  // Only documents with windows ("browsing contexts" to be precise)
  // allow scripting.
  doc._scripting_enabled = scripting_enabled;


  /***
   * The actual code of the HTMLParser() factory function begins here.
   */

  if (fragmentContext) { // for innerHTML parsing
    if (fragmentContext.ownerDocument._quirks)
      doc._quirks = true;
    if (fragmentContext.ownerDocument._limitedQuirks)
      doc._limitedQuirks = true;

    // Set the initial tokenizer state
    if (fragmentContext.namespaceURI === NAMESPACE.HTML) {
      switch(fragmentContext.localName) {
      case "title":
      case "textarea":
        tokenizer = rcdata_state;
        break;
      case "style":
      case "xmp":
      case "iframe":
      case "noembed":
      case "noframes":
      case "script":
      case "plaintext":
        tokenizer = plaintext_state;
        break;
      case "noscript":
        if (scripting_enabled)
          tokenizer = plaintext_state;
      }
    }

    var root = doc.createElement("html");
    doc._appendChild(root);
    stack.push(root);
    resetInsertionMode();

    for(var e = fragmentContext; e !== null; e = e.parentElement) {
      if (e instanceof impl.HTMLFormElement) {
        form_element_pointer = e;
        break;
      }
    }
  }

  /***
   * Scanner functions
   */
  // Loop through the characters in chars, and pass them one at a time
  // to the tokenizer FSM. Return when no more characters can be processed
  // (This may leave 1 or more characters in the buffer: like a CR
  // waiting to see if the next char is LF, or for states that require
  // lookahead...)
  function scanChars() {
    var codepoint, s, pattern, eof, matched;

    while(nextchar < numchars) {

      // If we just tokenized a </script> tag, then the paused flag
      // may have been set to tell us to stop tokenizing while
      // the script is loading
      if (paused > 0) {
        return;
      }


      switch(typeof tokenizer.lookahead) {
      case 'undefined':
        codepoint = chars.charCodeAt(nextchar++);
        if (scanner_skip_newline) {
          scanner_skip_newline = false;
          if (codepoint === 0x000A) {
            nextchar++;
            continue;
          }
        }
        switch(codepoint) {
        case 0x000D:
          // CR always turns into LF, but if the next character
          // is LF, then that second LF is skipped.
          if (nextchar < numchars) {
            if (chars.charCodeAt(nextchar) === 0x000A)
              nextchar++;
          }
          else {
            // We don't know the next char right now, so we
            // can't check if it is a LF.  So set a flag
            scanner_skip_newline = true;
          }

          // In either case, emit a LF
          tokenizer(0x000A);

          break;
        case 0xFFFF:
          if (input_complete && nextchar === numchars) {
            tokenizer(EOF); // codepoint will be 0xFFFF here
            break;
          }
          /* falls through */
        default:
          tokenizer(codepoint);
          break;
        }
        break;

      case 'number':
        codepoint = chars.charCodeAt(nextchar);

        // The only tokenizer states that require fixed lookahead
        // only consume alphanum characters, so we don't have
        // to worry about CR and LF in this case

        // tokenizer wants n chars of lookahead
        var n = tokenizer.lookahead;

        if (n < numchars - nextchar) {
          // If we can look ahead that far
          s = chars.substring(nextchar, nextchar+n);
          eof = false;
        }
        else { // if we don't have that many characters
          if (input_complete) { // If no more are coming
            // Just return what we have
            s = chars.substring(nextchar, numchars);
            eof = true;
            if (codepoint === 0xFFFF && nextchar === numchars-1)
              codepoint = EOF;
          }
          else {
            // Return now and wait for more chars later
            return;
          }
        }
        tokenizer(codepoint, s, eof);
        break;
      case 'string':
        codepoint = chars.charCodeAt(nextchar);

        // tokenizer wants characters up to a matching string
        pattern = tokenizer.lookahead;
        var pos = chars.indexOf(pattern, nextchar);
        if (pos !== -1) {
          s = chars.substring(nextchar, pos + pattern.length);
          eof = false;
        }
        else {  // No match
          // If more characters coming, wait for them
          if (!input_complete) return;

          // Otherwise, we've got to return what we've got
          s = chars.substring(nextchar, numchars);
          if (codepoint === 0xFFFF && nextchar === numchars-1)
            codepoint = EOF;
          eof = true;
        }

        // The tokenizer states that require this kind of
        // lookahead have to be careful to handle CR characters
        // correctly
        tokenizer(codepoint, s, eof);
        break;
      case 'object':
      case 'function':
        codepoint = chars.charCodeAt(nextchar);

        // tokenizer wants characters that match a regexp
        // The only tokenizer states that use regexp lookahead
        // are for character entities, and the patterns never
        // match CR or LF, so we don't need to worry about that
        // here.

        // XXX
        // Ideally, I'd use the non-standard y modifier on
        // these regexps and set pattern.lastIndex to nextchar.
        // But v8 and Node don't support /y, so I have to do
        // the substring below
        pattern = tokenizer.lookahead;
        matched = chars.substring(nextchar).match(pattern);
        if (matched) {
          // Found a match.
          // lastIndex now points to the first char after it
          s = matched[0];
          eof = false;
        }
        else {
          // No match.  If we're not at the end of input, then
          // wait for more chars
          if (!input_complete) return;

          // Otherwise, pass an empty string.  This is
          // different than the string-based lookahead
          // above. Regexp-based lookahead is only used
          // for character references, and a partial one
          // will not parse.  Also, a char ref
          // terminated with EOF will parse in the if
          // branch above, so here we're dealing with
          // things that really aren't char refs
          s = "";
          eof = true;
        }

        tokenizer(codepoint, s, eof);
        break;
      }
    }
  }


  /***
   * Tokenizer utility functions
   */
  function addAttribute(namebuf,valuebuf) {
    var name = buf2str(namebuf);
    var value;

    // Make sure there isn't already an attribute with this name
    // If there is, ignore this one.
    for(var i = 0; i < attributes.length; i++) {
      if (attributes[i][0] === name) return;
    }

    if (valuebuf) {
      attributes.push([name, buf2str(valuebuf)]);
    }
    else {
      attributes.push([name]);
    }
  }

  // Shortcut for simple attributes
  function handleSimpleAttribute() {
    SIMPLEATTR.lastIndex = nextchar-1;
    var matched = SIMPLEATTR.exec(chars);
    if (!matched) return false;
    var name = matched[1];
    var value = matched[2];
    var len = value.length;
    switch(value[0]) {
    case '"':
    case "'":
      value = value.substring(1, len-1);
      nextchar += (matched[0].length-1);
      tokenizer = after_attribute_value_quoted_state;
      break;
    default:
      tokenizer = before_attribute_name_state;
      nextchar += (matched[0].length-1);
      value = value.substring(0, len-1);
      break;
    }

    // Make sure there isn't already an attribute with this name
    // If there is, ignore this one.
    for(var i = 0; i < attributes.length; i++) {
      if (attributes[i][0] === name) return true;
    }

    attributes.push([name, value]);
    return true;
  }


  function pushState() { savedTokenizerStates.push(tokenizer); }
  function popState() { tokenizer = savedTokenizerStates.pop(); }
  function beginTagName() {
    is_end_tag = false;
    tagnamebuf.length = 0;
    attributes.length = 0;
  }
  function beginEndTagName() {
    is_end_tag = true;
    tagnamebuf.length = 0;
    attributes.length = 0;
  }

  function beginTempBuf() { tempbuf.length = 0; }
  function beginAttrName() { attrnamebuf.length = 0; }
  function beginAttrValue() { attrvaluebuf.length = 0; }
  function beginComment() { commentbuf.length = 0; }
  function beginDoctype() {
    doctypenamebuf.length = 0;
    doctypepublicbuf = null;
    doctypesystembuf = null;
  }
  function beginDoctypePublicId() { doctypepublicbuf = []; }
  function beginDoctypeSystemId() { doctypesystembuf = []; }
  function forcequirks() { force_quirks = true; }
  function cdataAllowed() {
    return stack.top &&
      stack.top.namespaceURI !== "http://www.w3.org/1999/xhtml";
  }

  // Return true if the codepoints in the specified buffer match the
  // characters of lasttagname
  function appropriateEndTag(buf) {
    if (buf.length !== lasttagname.length) return false;
    for(var i = 0, n = buf.length; i < n; i++) {
      if (buf[i] !== lasttagname.charCodeAt(i)) return false;
    }
    return true;
  }

  function flushText() {
    if (textrun.length > 0) {
      var s = buf2str(textrun);
      textrun.length = 0;

      if (ignore_linefeed) {
        ignore_linefeed = false;
        if (s[0] === "\n") s = s.substring(1);
        if (s.length === 0) return;
      }

      insertToken(TEXT, s);
      textIncludesNUL = false;
    }
    ignore_linefeed = false;
  }

  // emit a string of chars that match a regexp
  // Returns false if no chars matched.
  function emitCharsWhile(pattern) {
    pattern.lastIndex = nextchar-1;
    var match = pattern.exec(chars)[0];
    if (!match) return false;
    emitCharString(match);
    nextchar += match.length - 1;
    return true;
  }

  // This is used by CDATA sections
  function emitCharString(s) {
    if (textrun.length > 0) flushText();

    if (ignore_linefeed) {
      ignore_linefeed = false;
      if (s[0] === "\n") s = s.substring(1);
      if (s.length === 0) return;
    }

    insertToken(TEXT, s);
  }

  function emitTag() {
    if (is_end_tag) insertToken(ENDTAG, buf2str(tagnamebuf));
    else {
      // Remember the last open tag we emitted
      var tagname = buf2str(tagnamebuf);
      tagnamebuf.length = 0;
      lasttagname = tagname;
      insertToken(TAG, tagname, attributes);
    }
  }


  // A shortcut: look ahead and if this is a open or close tag
  // in lowercase with no spaces and no attributes, just emit it now.
  function emitSimpleTag() {
    SIMPLETAG.lastIndex = nextchar;
    var matched = SIMPLETAG.exec(chars);
    if (!matched) return false;
    var tagname = matched[2];
    var endtag = matched[1];
    if (endtag) {
      nextchar += (tagname.length+2);
      insertToken(ENDTAG, tagname);
    }
    else {
      nextchar += (tagname.length+1);
      lasttagname = tagname;
      insertToken(TAG, tagname, NOATTRS);
    }
    return true;
  }

  function emitSelfClosingTag() {
    if (is_end_tag) insertToken(ENDTAG, buf2str(tagnamebuf), null, true);
    else {
      insertToken(TAG, buf2str(tagnamebuf), attributes, true);
    }
  }

  function emitDoctype() {
    insertToken(DOCTYPE,
          buf2str(doctypenamebuf),
          doctypepublicbuf ? buf2str(doctypepublicbuf) : undefined,
          doctypesystembuf ? buf2str(doctypesystembuf) : undefined);
  }

  function emitEOF() {
    flushText();
    parser(EOF); // EOF never goes to insertForeignContent()
    doc.modclock = 1; // Start tracking modifications
  }

  // Insert a token, either using the current parser insertio mode
  // (for HTML stuff) or using the insertForeignToken() method.
  function insertToken(t, value, arg3, arg4) {
    flushText();
    var current = stack.top;

    if (!current || current.namespaceURI === NAMESPACE.HTML) {
      // This is the common case
      parser(t, value, arg3, arg4);
    }
    else {
      // Otherwise we may need to insert this token as foreign content
      if (t !== TAG && t !== TEXT) {
        insertForeignToken(t, value, arg3, arg4);
      }
      else {
        // But in some cases we treat it as regular content
        if ((isMathmlTextIntegrationPoint(current) &&
           (t === TEXT ||
            (t === TAG &&
             value !== "mglyph" && value !== "malignmark"))) ||
          (t === TAG &&
           value === "svg" &&
           current.namespaceURI === NAMESPACE.MATHML &&
           current.localName === "annotation-xml") ||
          isHTMLIntegrationPoint(current)) {

          // XXX: the text_integration_mode stuff is an
          // attempted bug workaround of mine
          text_integration_mode = true;
          parser(t, value, arg3, arg4);
          text_integration_mode = false;
        }
        // Otherwise it is foreign content
        else {
          insertForeignToken(t, value, arg3, arg4);
        }
      }
    }
  }


  /***
   * Tree building utility functions
   */
  function insertComment(data) {
    stack.top._appendChild(doc.createComment(data));
  }

  function insertText(s) {
    if (foster_parent_mode && isA(stack.top, tablesectionrowSet)) {
      fosterParent(doc.createTextNode(s));
    }
    else {
      var lastChild = stack.top.lastChild;
      if (lastChild && lastChild.nodeType === Node.TEXT_NODE) {
        lastChild.appendData(s);
      }
      else {
        stack.top._appendChild(doc.createTextNode(s));
      }
    }
  }

  function createHTMLElt(name, attrs) {
    // Create the element this way, rather than with
    // doc.createElement because createElement() does error
    // checking on the element name that we need to avoid here.
    var elt = html.createElement(doc, name, null);

    if (attrs) {
      for(var i = 0, n = attrs.length; i < n; i++) {
        // Use the _ version to avoid testing the validity
        // of the attribute name
        elt._setAttribute(attrs[i][0], attrs[i][1]);
      }
    }
    // XXX
    // If the element is a resettable form element,
    // run its reset algorithm now
    return elt;
  }

  // The in_table insertion mode turns on this flag, and that makes
  // insertHTMLElement use the foster parenting algorithm for elements
  // tags inside a table
  var foster_parent_mode = false;

  function insertHTMLElement(name, attrs) {
    var elt = createHTMLElt(name, attrs);
    insertElement(elt);

    // XXX
    // If this is a form element, set its form attribute property here
    if (isA(elt, formassociatedSet)) {
      elt._form = form_element_pointer;
    }

    return elt;
  }

  // Insert the element into the open element or foster parent it
  function insertElement(elt) {
    if (foster_parent_mode && isA(stack.top, tablesectionrowSet)) {
      fosterParent(elt);
    }
    else {
      stack.top._appendChild(elt);
    }

    stack.push(elt);
  }

  function insertForeignElement(name, attrs, ns) {
    var elt = doc.createElementNS(ns, name);
    if (attrs) {
      for(var i = 0, n = attrs.length; i < n; i++) {
        var attr = attrs[i];
        if (attr.length == 2)
          elt._setAttribute(attr[0], attr[1]);
        else {
          elt._setAttributeNS(attr[2], attr[0], attr[1]);
        }
      }
    }

    insertElement(elt);
  }

  function fosterParent(elt) {
    var parent, before;

    for(var i = stack.elements.length-1; i >= 0; i--) {
      if (stack.elements[i] instanceof impl.HTMLTableElement) {
        parent = stack.elements[i].parentElement;
        if (parent)
          before = stack.elements[i];
        else
          parent = stack.elements[i-1];

        break;
      }
    }
    if (!parent) parent = stack.elements[0];

    if (elt.nodeType === Node.TEXT_NODE) {
      var prev;
      if (before) prev = before.previousSibling;
      else prev = parent.lastChild;
      if (prev && prev.nodeType === Node.TEXT_NODE) {
        prev.appendData(elt.data);
        return;
      }
    }
    if (before)
      parent.insertBefore(elt, before);
    else
      parent._appendChild(elt);
  }


  function resetInsertionMode() {
    var last = false;
    for(var i = stack.elements.length-1; i >= 0; i--) {
      var node = stack.elements[i];
      if (i === 0) {
        last = true;
        node = fragmentContext;
      }
      if (node.namespaceURI === NAMESPACE.HTML) {
        var tag = node.localName;
        switch(tag) {
        case "select":
          parser = in_select_mode;
          return;
        case "tr":
          parser = in_row_mode;
          return;
        case "tbody":
        case "tfoot":
        case "thead":
          parser = in_table_body_mode;
          return;
        case "caption":
          parser = in_caption_mode;
          return;
        case "colgroup":
          parser = in_column_group_mode;
          return;
        case "table":
          parser = in_table_mode;
          return;
        case "head": // Not in_head_mode!
        case "body":
          parser = in_body_mode;
          return;
        case "frameset":
          parser = in_frameset_mode;
          return;
        case "html":
          parser = before_head_mode;
          return;
        default:
          if (!last && (tag === "td" || tag === "th")) {
            parser = in_cell_mode;
            return;
          }
        }
      }
      if (last) {
        parser = in_body_mode;
        return;
      }
    }
  }


  function parseRawText(name, attrs) {
    insertHTMLElement(name, attrs);
    tokenizer = rawtext_state;
    originalInsertionMode = parser;
    parser = text_mode;
  }

  function parseRCDATA(name, attrs) {
    insertHTMLElement(name, attrs);
    tokenizer = rcdata_state;
    originalInsertionMode = parser;
    parser = text_mode;
  }

  // Make a copy of element i on the list of active formatting
  // elements, using its original attributes, not current
  // attributes (which may have been modified by a script)
  function afeclone(i) {
    return createHTMLElt(afe.list[i].localName, afe.attrs[i]);
  }


  function afereconstruct() {
    if (afe.list.length === 0) return;
    var entry = afe.list[afe.list.length-1];
    // If the last is a marker , do nothing
    if (entry === afe.MARKER) return;
    // Or if it is an open element, do nothing
    if (stack.elements.lastIndexOf(entry) !== -1) return;

    // Loop backward through the list until we find a marker or an
    // open element, and then move forward one from there.
    for(var i = afe.list.length-2; i >= 0; i--) {
      entry = afe.list[i];
      if (entry === afe.MARKER) break;
      if (stack.elements.lastIndexOf(entry) !== -1) break;
    }

    // Now loop forward, starting from the element after the current
    // one, recreating formatting elements and pushing them back onto
    // the list of open elements
    for(i = i+1; i < afe.list.length; i++) {
      var newelt = afeclone(i);
      insertElement(newelt);
      afe.list[i] = newelt;
    }
  }

  // Used by the adoptionAgency() function
  var BOOKMARK = {localName:"BM"};

  function adoptionAgency(tag) {
    // Let outer loop counter be zero.
    var outer = 0;

    // Outer loop: If outer loop counter is greater than or
    // equal to eight, then abort these steps.
    while(outer < 8) {
      // Increment outer loop counter by one.
      outer++;

      // Let the formatting element be the last element in the list
      // of active formatting elements that: is between the end of
      // the list and the last scope marker in the list, if any, or
      // the start of the list otherwise, and has the same tag name
      // as the token.
      var fmtelt = afe.findElementByTag(tag);

      // If there is no such node, then abort these steps and instead
      // act as described in the "any other end tag" entry below.
      if (!fmtelt) {
        return false; // false means handle by the default case
      }

      // Otherwise, if there is such a node, but that node is not in
      // the stack of open elements, then this is a parse error;
      // remove the element from the list, and abort these steps.
      var index = stack.elements.lastIndexOf(fmtelt);
      if (index === -1) {
        afe.remove(fmtelt);
        return true;   // true means no more handling required
      }

      // Otherwise, if there is such a node, and that node is also in
      // the stack of open elements, but the element is not in scope,
      // then this is a parse error; ignore the token, and abort
      // these steps.
      if (!stack.elementInScope(fmtelt)) {
        return true;
      }

      // Let the furthest block be the topmost node in the stack of
      // open elements that is lower in the stack than the formatting
      // element, and is an element in the special category. There
      // might not be one.
      var furthestblock = null, furthestblockindex;
      for(var i = index+1; i < stack.elements.length; i++) {
        if (isA(stack.elements[i], specialSet)) {
          furthestblock = stack.elements[i];
          furthestblockindex = i;
          break;
        }
      }

      // If there is no furthest block, then the UA must skip the
      // subsequent steps and instead just pop all the nodes from the
      // bottom of the stack of open elements, from the current node
      // up to and including the formatting element, and remove the
      // formatting element from the list of active formatting
      // elements.
      if (!furthestblock) {
        stack.popElement(fmtelt);
        afe.remove(fmtelt);
        return true;
      }
      else {
        // Let the common ancestor be the element immediately above
        // the formatting element in the stack of open elements.
        var ancestor = stack.elements[index-1];

        // Let a bookmark note the position of the formatting
        // element in the list of active formatting elements
        // relative to the elements on either side of it in the
        // list.
        afe.insertAfter(fmtelt, BOOKMARK);

        // Let node and last node be the furthest block.
        var node = furthestblock;
        var lastnode = furthestblock;
        var nodeindex = furthestblockindex;
        var nodeafeindex;

        // Let inner loop counter be zero.
        var inner = 0;

        // Inner loop: If inner loop counter is greater than
        // or equal to three, then abort these steps.
        while(inner < 3) {

          // Increment inner loop counter by one.
          inner++;

          // Let node be the element immediately above node in
          // the stack of open elements, or if node is no longer
          // in the stack of open elements (e.g. because it got
          // removed by the next step), the element that was
          // immediately above node in the stack of open elements
          // before node was removed.
          node = stack.elements[--nodeindex];

          // If node is not in the list of active formatting
          // elements, then remove node from the stack of open
          // elements and then go back to the step labeled inner
          // loop.
          nodeafeindex = afe.indexOf(node);
          if (nodeafeindex === -1) {
            stack.removeElement(node);
            continue;
          }

          // Otherwise, if node is the formatting element, then go
          // to the next step in the overall algorithm.
          if (node === fmtelt) break;

          // Create an element for the token for which the
          // element node was created, replace the entry for node
          // in the list of active formatting elements with an
          // entry for the new element, replace the entry for
          // node in the stack of open elements with an entry for
          // the new element, and let node be the new element.
          var newelt = afeclone(nodeafeindex);
          afe.replace(node, newelt);
          stack.elements[nodeindex] = newelt;
          node = newelt;

          // If last node is the furthest block, then move the
          // aforementioned bookmark to be immediately after the
          // new node in the list of active formatting elements.
          if (lastnode === furthestblock) {
            afe.remove(BOOKMARK);
            afe.insertAfter(newelt, BOOKMARK);
          }

          // Insert last node into node, first removing it from
          // its previous parent node if any.
          node._appendChild(lastnode);

          // Let last node be node.
          lastnode = node;
        }

        // If the common ancestor node is a table, tbody, tfoot,
        // thead, or tr element, then, foster parent whatever last
        // node ended up being in the previous step, first removing
        // it from its previous parent node if any.
        if (isA(ancestor, tablesectionrowSet)) {
          fosterParent(lastnode);
        }
        // Otherwise, append whatever last node ended up being in
        // the previous step to the common ancestor node, first
        // removing it from its previous parent node if any.
        else {
          ancestor._appendChild(lastnode);
        }

        // Create an element for the token for which the
        // formatting element was created.
        var newelt2 = afeclone(afe.indexOf(fmtelt));

        // Take all of the child nodes of the furthest block and
        // append them to the element created in the last step.
        while(furthestblock.hasChildNodes()) {
          newelt2._appendChild(furthestblock.firstChild);
        }

        // Append that new element to the furthest block.
        furthestblock._appendChild(newelt2);

        // Remove the formatting element from the list of active
        // formatting elements, and insert the new element into the
        // list of active formatting elements at the position of
        // the aforementioned bookmark.
        afe.remove(fmtelt);
        afe.replace(BOOKMARK, newelt2);

        // Remove the formatting element from the stack of open
        // elements, and insert the new element into the stack of
        // open elements immediately below the position of the
        // furthest block in that stack.
        stack.removeElement(fmtelt);
        var pos = stack.elements.lastIndexOf(furthestblock);
        stack.elements.splice(pos+1, 0, newelt2);
      }
    }

    return true;
  }

  // We do this when we get /script in in_text_mode
  function handleScriptEnd() {
    // XXX:
    // This is just a stub implementation right now and doesn't run scripts.
    // Getting this method right involves the event loop, URL resolution
    // script fetching etc. For now I just want to be able to parse
    // documents and test the parser.

    var script = stack.top;
    stack.pop();
    parser = originalInsertionMode;
    //script._prepare();
    return;

    // XXX: here is what this method is supposed to do

    // Provide a stable state.

    // Let script be the current node (which will be a script
    // element).

    // Pop the current node off the stack of open elements.

    // Switch the insertion mode to the original insertion mode.

    // Let the old insertion point have the same value as the current
    // insertion point. Let the insertion point be just before the
    // next input character.

    // Increment the parser's script nesting level by one.

    // Prepare the script. This might cause some script to execute,
    // which might cause new characters to be inserted into the
    // tokenizer, and might cause the tokenizer to output more tokens,
    // resulting in a reentrant invocation of the parser.

    // Decrement the parser's script nesting level by one. If the
    // parser's script nesting level is zero, then set the parser
    // pause flag to false.

    // Let the insertion point have the value of the old insertion
    // point. (In other words, restore the insertion point to its
    // previous value. This value might be the "undefined" value.)

    // At this stage, if there is a pending parsing-blocking script,
    // then:

    // If the script nesting level is not zero:

    //   Set the parser pause flag to true, and abort the processing
    //   of any nested invocations of the tokenizer, yielding
    //   control back to the caller. (Tokenization will resume when
    //   the caller returns to the "outer" tree construction stage.)

    //   The tree construction stage of this particular parser is
    //   being called reentrantly, say from a call to
    //   document.write().

    // Otherwise:

    //     Run these steps:

    //       Let the script be the pending parsing-blocking
    //       script. There is no longer a pending
    //       parsing-blocking script.

    //       Block the tokenizer for this instance of the HTML
    //       parser, such that the event loop will not run tasks
    //       that invoke the tokenizer.

    //       If the parser's Document has a style sheet that is
    //       blocking scripts or the script's "ready to be
    //       parser-executed" flag is not set: spin the event
    //       loop until the parser's Document has no style sheet
    //       that is blocking scripts and the script's "ready to
    //       be parser-executed" flag is set.

    //       Unblock the tokenizer for this instance of the HTML
    //       parser, such that tasks that invoke the tokenizer
    //       can again be run.

    //       Let the insertion point be just before the next
    //       input character.

    //       Increment the parser's script nesting level by one
    //       (it should be zero before this step, so this sets
    //       it to one).

    //       Execute the script.

    //       Decrement the parser's script nesting level by
    //       one. If the parser's script nesting level is zero
    //       (which it always should be at this point), then set
    //       the parser pause flag to false.

    //       Let the insertion point be undefined again.

    //       If there is once again a pending parsing-blocking
    //       script, then repeat these steps from step 1.


  }

  function stopParsing() {
    // XXX This is just a temporary implementation to get the parser working.
    // A full implementation involves scripts and events and the event loop.

    // Remove the link from document to parser.
    // This is instead of "set the insertion point to undefined".
    // It means that document.write() can't write into the doc anymore.
    delete doc._parser;

    stack.elements.length = 0; // pop everything off

    // If there is a window object associated with the document
    // then trigger an load event on it
    if (doc.defaultView) {
      doc.defaultView.dispatchEvent(new impl.Event("load",{}));
    }

  }

  /****
   * Tokenizer states
   */

  /**
   * This file was partially mechanically generated from
   * http://www.whatwg.org/specs/web-apps/current-work/multipage/tokenization.html
   *
   * After mechanical conversion, it was further converted from
   * prose to JS by hand, but the intent is that it is a very
   * faithful rendering of the HTML tokenization spec in
   * JavaScript.
   *
   * It is not a goal of this tokenizer to detect or report
   * parse errors.
   *
   * XXX The tokenizer is supposed to work with straight UTF32
   * codepoints. But I don't think it has any dependencies on
   * any character outside of the BMP so I think it is safe to
   * pass it UTF16 characters. I don't think it will ever change
   * state in the middle of a surrogate pair.
   */

  /*
   * Each state is represented by a function.  For most states, the
   * scanner simply passes the next character (as an integer
   * codepoint) to the current state function and automatically
   * consumes the character.  If the state function can't process
   * the character it can call pushback() to push it back to the
   * scanner.
   *
   * Some states require lookahead, though.  If a state function has
   * a lookahead property, then it is invoked differently.  In this
   * case, the scanner invokes the function with 3 arguments: 1) the
   * next codepoint 2) a string of lookahead text 3) a boolean that
   * is true if the lookahead goes all the way to the EOF. (XXX
   * actually maybe this third is not necessary... the lookahead
   * could just include \uFFFF?)
   *
   * If the lookahead property of a state function is an integer, it
   * specifies the number of characters required. If it is a string,
   * then the scanner will scan for that string and return all
   * characters up to and including that sequence, or up to EOF.  If
   * the lookahead property is a regexp, then the scanner will match
   * the regexp at the current point and return the matching string.
   *
   * States that require lookahead are responsible for explicitly
   * consuming the characters they process. They do this by
   * incrementing nextchar by the number of processed characters.
   */

  function data_state(c) {
    switch(c) {
    case 0x0026: // AMPERSAND
      tokenizer = character_reference_in_data_state;
      break;
    case 0x003C: // LESS-THAN SIGN
      if (emitSimpleTag()) // Shortcut for <p>, <dl>, </div> etc.
        break;
      tokenizer = tag_open_state;
      break;
    case 0x0000: // NULL
      // Usually null characters emitted by the tokenizer will be
      // ignored by the tree builder, but sometimes they'll be
      // converted to \uFFFD.  I don't want to have the search every
      // string emitted to replace NULs, so I'll set a flag
      // if I've emitted a NUL.
      textrun.push(c);
      textIncludesNUL = true;
      break;
    case -1: // EOF
      emitEOF();
      break;
    default:
      // Instead of just pushing a single character and then
      // coming back to the very same place, lookahead and
      // emit everything we can at once.
      emitCharsWhile(DATATEXT) || textrun.push(c);
      break;
    }
  }

  function character_reference_in_data_state(c, lookahead, eof) {
    var char = parseCharRef(lookahead, false);
    if (char !== null) {
      if (typeof char === "number") textrun.push(char);
      else pushAll(textrun, char); // An array of characters
    }
    else
      textrun.push(0x0026); // AMPERSAND;

    tokenizer = data_state;
  }
  character_reference_in_data_state.lookahead = CHARREF;

  function rcdata_state(c) {
    // Save the open tag so we can find a matching close tag
    switch(c) {
    case 0x0026: // AMPERSAND
      tokenizer = character_reference_in_rcdata_state;
      break;
    case 0x003C: // LESS-THAN SIGN
      tokenizer = rcdata_less_than_sign_state;
      break;
    case 0x0000: // NULL
      textrun.push(0xFFFD); // REPLACEMENT CHARACTER
      textIncludesNUL = true;
      break;
    case -1: // EOF
      emitEOF();
      break;
    default:
      textrun.push(c);
      break;
    }
  }

  function character_reference_in_rcdata_state(c, lookahead, eof) {
    var char = parseCharRef(lookahead, false);
    if (char !== null) {
      if (typeof char === "number") textrun.push(char);
      else pushAll(textrun, char); // An array of characters
    }
    else
      textrun.push(0x0026); // AMPERSAND;

    tokenizer = rcdata_state;
  }
  character_reference_in_rcdata_state.lookahead = CHARREF;

  function rawtext_state(c) {
    switch(c) {
    case 0x003C: // LESS-THAN SIGN
      tokenizer = rawtext_less_than_sign_state;
      break;
    case 0x0000: // NULL
      textrun.push(0xFFFD); // REPLACEMENT CHARACTER
      break;
    case -1: // EOF
      emitEOF();
      break;
    default:
      emitCharsWhile(RAWTEXT) || textrun.push(c);
      break;
    }
  }

  function script_data_state(c) {
    switch(c) {
    case 0x003C: // LESS-THAN SIGN
      tokenizer = script_data_less_than_sign_state;
      break;
    case 0x0000: // NULL
      textrun.push(0xFFFD); // REPLACEMENT CHARACTER
      break;
    case -1: // EOF
      emitEOF();
      break;
    default:
      emitCharsWhile(RAWTEXT) || textrun.push(c);
      break;
    }
  }

  function plaintext_state(c) {
    switch(c) {
    case 0x0000: // NULL
      textrun.push(0xFFFD); // REPLACEMENT CHARACTER
      break;
    case -1: // EOF
      emitEOF();
      break;
    default:
      emitCharsWhile(PLAINTEXT) || textrun.push(c);
      break;
    }
  }

  function tag_open_state(c) {
    switch(c) {
    case 0x0021: // EXCLAMATION MARK
      tokenizer = markup_declaration_open_state;
      break;
    case 0x002F: // SOLIDUS
      tokenizer = end_tag_open_state;
      break;
    case 0x0041:  // [A-Z]
    case 0x0042:case 0x0043:case 0x0044:case 0x0045:case 0x0046:
    case 0x0047:case 0x0048:case 0x0049:case 0x004A:case 0x004B:
    case 0x004C:case 0x004D:case 0x004E:case 0x004F:case 0x0050:
    case 0x0051:case 0x0052:case 0x0053:case 0x0054:case 0x0055:
    case 0x0056:case 0x0057:case 0x0058:case 0x0059:case 0x005A:
      c += 0x20; // to lowercase
      /* falls through */

    case 0x0061:  // [a-z]
    case 0x0062:case 0x0063:case 0x0064:case 0x0065:case 0x0066:
    case 0x0067:case 0x0068:case 0x0069:case 0x006A:case 0x006B:
    case 0x006C:case 0x006D:case 0x006E:case 0x006F:case 0x0070:
    case 0x0071:case 0x0072:case 0x0073:case 0x0074:case 0x0075:
    case 0x0076:case 0x0077:case 0x0078:case 0x0079:case 0x007A:
      beginTagName();
      tagnamebuf.push(c);
      tokenizer = tag_name_state;
      break;
    case 0x003F: // QUESTION MARK
      nextchar--; // pushback
      tokenizer = bogus_comment_state;
      break;
    default:
      textrun.push(0x003C); // LESS-THAN SIGN
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    }
  }

  function end_tag_open_state(c) {
    switch(c) {
    case 0x0041:  // [A-Z]
    case 0x0042:case 0x0043:case 0x0044:case 0x0045:case 0x0046:
    case 0x0047:case 0x0048:case 0x0049:case 0x004A:case 0x004B:
    case 0x004C:case 0x004D:case 0x004E:case 0x004F:case 0x0050:
    case 0x0051:case 0x0052:case 0x0053:case 0x0054:case 0x0055:
    case 0x0056:case 0x0057:case 0x0058:case 0x0059:case 0x005A:
      c += 0x20; // to lowercase
      /* falls through */

    case 0x0061:  // [a-z]
    case 0x0062:case 0x0063:case 0x0064:case 0x0065:case 0x0066:
    case 0x0067:case 0x0068:case 0x0069:case 0x006A:case 0x006B:
    case 0x006C:case 0x006D:case 0x006E:case 0x006F:case 0x0070:
    case 0x0071:case 0x0072:case 0x0073:case 0x0074:case 0x0075:
    case 0x0076:case 0x0077:case 0x0078:case 0x0079:case 0x007A:
      beginEndTagName();
      tagnamebuf.push(c);
      tokenizer = tag_name_state;
      break;
    case 0x003E: // GREATER-THAN SIGN
      tokenizer = data_state;
      break;
    case -1: // EOF
      textrun.push(0x003C); // LESS-THAN SIGN
      textrun.push(0x002F); // SOLIDUS
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      nextchar--; // pushback
      tokenizer = bogus_comment_state;
      break;
    }
  }

  function tag_name_state(c) {
    switch(c) {
    case 0x0009: // CHARACTER TABULATION (tab)
    case 0x000A: // LINE FEED (LF)
    case 0x000C: // FORM FEED (FF)
    case 0x0020: // SPACE
      tokenizer = before_attribute_name_state;
      break;
    case 0x002F: // SOLIDUS
      tokenizer = self_closing_start_tag_state;
      break;
    case 0x003E: // GREATER-THAN SIGN
      tokenizer = data_state;
      emitTag();
      break;
    case 0x0041:  // [A-Z]
    case 0x0042:case 0x0043:case 0x0044:case 0x0045:case 0x0046:
    case 0x0047:case 0x0048:case 0x0049:case 0x004A:case 0x004B:
    case 0x004C:case 0x004D:case 0x004E:case 0x004F:case 0x0050:
    case 0x0051:case 0x0052:case 0x0053:case 0x0054:case 0x0055:
    case 0x0056:case 0x0057:case 0x0058:case 0x0059:case 0x005A:
      tagnamebuf.push(c + 0x0020);
      break;
    case 0x0000: // NULL
      tagnamebuf.push(0xFFFD /* REPLACEMENT CHARACTER */);
      break;
    case -1: // EOF
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      tagnamebuf.push(c);
      // appendCharsWhile(tagnamebuf, TAGNAMECHARS) || tagnamebuf.push(c);
      break;
    }
  }

  function rcdata_less_than_sign_state(c) {
    /* identical to the RAWTEXT less-than sign state, except s/RAWTEXT/RCDATA/g */
    if (c === 0x002F) {  // SOLIDUS
      beginTempBuf();
      tokenizer = rcdata_end_tag_open_state;
    }
    else {
      textrun.push(0x003C); // LESS-THAN SIGN
      nextchar--; // pushback
      tokenizer = rcdata_state;
    }
  }

  function rcdata_end_tag_open_state(c) {
    /* identical to the RAWTEXT (and Script data) end tag open state, except s/RAWTEXT/RCDATA/g */
    switch(c) {
    case 0x0041:  // [A-Z]
    case 0x0042:case 0x0043:case 0x0044:case 0x0045:case 0x0046:
    case 0x0047:case 0x0048:case 0x0049:case 0x004A:case 0x004B:
    case 0x004C:case 0x004D:case 0x004E:case 0x004F:case 0x0050:
    case 0x0051:case 0x0052:case 0x0053:case 0x0054:case 0x0055:
    case 0x0056:case 0x0057:case 0x0058:case 0x0059:case 0x005A:
      beginEndTagName();
      tagnamebuf.push(c + 0x0020);
      tempbuf.push(c);
      tokenizer = rcdata_end_tag_name_state;
      break;
    case 0x0061:  // [a-z]
    case 0x0062:case 0x0063:case 0x0064:case 0x0065:case 0x0066:
    case 0x0067:case 0x0068:case 0x0069:case 0x006A:case 0x006B:
    case 0x006C:case 0x006D:case 0x006E:case 0x006F:case 0x0070:
    case 0x0071:case 0x0072:case 0x0073:case 0x0074:case 0x0075:
    case 0x0076:case 0x0077:case 0x0078:case 0x0079:case 0x007A:
      beginEndTagName();
      tagnamebuf.push(c);
      tempbuf.push(c);
      tokenizer = rcdata_end_tag_name_state;
      break;
    default:
      textrun.push(0x003C); // LESS-THAN SIGN
      textrun.push(0x002F); // SOLIDUS
      nextchar--; // pushback
      tokenizer = rcdata_state;
      break;
    }
  }

  function rcdata_end_tag_name_state(c) {
    /* identical to the RAWTEXT (and Script data) end tag name state, except s/RAWTEXT/RCDATA/g */
    switch(c) {
    case 0x0009: // CHARACTER TABULATION (tab)
    case 0x000A: // LINE FEED (LF)
    case 0x000C: // FORM FEED (FF)
    case 0x0020: // SPACE
      if (appropriateEndTag(tagnamebuf)) {
        tokenizer = before_attribute_name_state;
        return;
      }
      break;
    case 0x002F: // SOLIDUS
      if (appropriateEndTag(tagnamebuf)) {
        tokenizer = self_closing_start_tag_state;
        return;
      }
      break;
    case 0x003E: // GREATER-THAN SIGN
      if (appropriateEndTag(tagnamebuf)) {
        tokenizer = data_state;
        emitTag();
        return;
      }
      break;
    case 0x0041:  // [A-Z]
    case 0x0042:case 0x0043:case 0x0044:case 0x0045:case 0x0046:
    case 0x0047:case 0x0048:case 0x0049:case 0x004A:case 0x004B:
    case 0x004C:case 0x004D:case 0x004E:case 0x004F:case 0x0050:
    case 0x0051:case 0x0052:case 0x0053:case 0x0054:case 0x0055:
    case 0x0056:case 0x0057:case 0x0058:case 0x0059:case 0x005A:

      tagnamebuf.push(c + 0x0020);
      tempbuf.push(c);
      return;
    case 0x0061:  // [a-z]
    case 0x0062:case 0x0063:case 0x0064:case 0x0065:case 0x0066:
    case 0x0067:case 0x0068:case 0x0069:case 0x006A:case 0x006B:
    case 0x006C:case 0x006D:case 0x006E:case 0x006F:case 0x0070:
    case 0x0071:case 0x0072:case 0x0073:case 0x0074:case 0x0075:
    case 0x0076:case 0x0077:case 0x0078:case 0x0079:case 0x007A:

      tagnamebuf.push(c);
      tempbuf.push(c);
      return;
    default:
      break;
    }

    // If we don't return in one of the cases above, then this was not
    // an appropriately matching close tag, so back out by emitting all
    // the characters as text
    textrun.push(0x003C); // LESS-THAN SIGN
    textrun.push(0x002F); // SOLIDUS
    pushAll(textrun, tempbuf);
    nextchar--; // pushback
    tokenizer = rcdata_state;
  }

  function rawtext_less_than_sign_state(c) {
    /* identical to the RCDATA less-than sign state, except s/RCDATA/RAWTEXT/g
     */
    if (c === 0x002F) { // SOLIDUS
      beginTempBuf();
      tokenizer = rawtext_end_tag_open_state;
    }
    else {
      textrun.push(0x003C); // LESS-THAN SIGN
      nextchar--; // pushback
      tokenizer = rawtext_state;
    }
  }

  function rawtext_end_tag_open_state(c) {
    /* identical to the RCDATA (and Script data) end tag open state, except s/RCDATA/RAWTEXT/g */
    switch(c) {
    case 0x0041:  // [A-Z]
    case 0x0042:case 0x0043:case 0x0044:case 0x0045:case 0x0046:
    case 0x0047:case 0x0048:case 0x0049:case 0x004A:case 0x004B:
    case 0x004C:case 0x004D:case 0x004E:case 0x004F:case 0x0050:
    case 0x0051:case 0x0052:case 0x0053:case 0x0054:case 0x0055:
    case 0x0056:case 0x0057:case 0x0058:case 0x0059:case 0x005A:
      beginEndTagName();
      tagnamebuf.push(c + 0x0020);
      tempbuf.push(c);
      tokenizer = rawtext_end_tag_name_state;
      break;
    case 0x0061:  // [a-z]
    case 0x0062:case 0x0063:case 0x0064:case 0x0065:case 0x0066:
    case 0x0067:case 0x0068:case 0x0069:case 0x006A:case 0x006B:
    case 0x006C:case 0x006D:case 0x006E:case 0x006F:case 0x0070:
    case 0x0071:case 0x0072:case 0x0073:case 0x0074:case 0x0075:
    case 0x0076:case 0x0077:case 0x0078:case 0x0079:case 0x007A:
      beginEndTagName();
      tagnamebuf.push(c);
      tempbuf.push(c);
      tokenizer = rawtext_end_tag_name_state;
      break;
    default:
      textrun.push(0x003C); // LESS-THAN SIGN
      textrun.push(0x002F); // SOLIDUS
      nextchar--; // pushback
      tokenizer = rawtext_state;
      break;
    }
  }

  function rawtext_end_tag_name_state(c) {
    /* identical to the RCDATA (and Script data) end tag name state, except s/RCDATA/RAWTEXT/g */
    switch(c) {
    case 0x0009: // CHARACTER TABULATION (tab)
    case 0x000A: // LINE FEED (LF)
    case 0x000C: // FORM FEED (FF)
    case 0x0020: // SPACE
      if (appropriateEndTag(tagnamebuf)) {
        tokenizer = before_attribute_name_state;
        return;
      }
      break;
    case 0x002F: // SOLIDUS
      if (appropriateEndTag(tagnamebuf)) {
        tokenizer = self_closing_start_tag_state;
        return;
      }
      break;
    case 0x003E: // GREATER-THAN SIGN
      if (appropriateEndTag(tagnamebuf)) {
        tokenizer = data_state;
        emitTag();
        return;
      }
      break;
    case 0x0041:  // [A-Z]
    case 0x0042:case 0x0043:case 0x0044:case 0x0045:case 0x0046:
    case 0x0047:case 0x0048:case 0x0049:case 0x004A:case 0x004B:
    case 0x004C:case 0x004D:case 0x004E:case 0x004F:case 0x0050:
    case 0x0051:case 0x0052:case 0x0053:case 0x0054:case 0x0055:
    case 0x0056:case 0x0057:case 0x0058:case 0x0059:case 0x005A:
      tagnamebuf.push(c + 0x0020);
      tempbuf.push(c);
      return;
    case 0x0061:  // [a-z]
    case 0x0062:case 0x0063:case 0x0064:case 0x0065:case 0x0066:
    case 0x0067:case 0x0068:case 0x0069:case 0x006A:case 0x006B:
    case 0x006C:case 0x006D:case 0x006E:case 0x006F:case 0x0070:
    case 0x0071:case 0x0072:case 0x0073:case 0x0074:case 0x0075:
    case 0x0076:case 0x0077:case 0x0078:case 0x0079:case 0x007A:
      tagnamebuf.push(c);
      tempbuf.push(c);
      return;
    default:
      break;
    }

    // If we don't return in one of the cases above, then this was not
    // an appropriately matching close tag, so back out by emitting all
    // the characters as text
    textrun.push(0x003C); // LESS-THAN SIGN
    textrun.push(0x002F); // SOLIDUS
    pushAll(textrun,tempbuf);
    nextchar--; // pushback
    tokenizer = rawtext_state;
  }

  function script_data_less_than_sign_state(c) {
    switch(c) {
    case 0x002F: // SOLIDUS
      beginTempBuf();
      tokenizer = script_data_end_tag_open_state;
      break;
    case 0x0021: // EXCLAMATION MARK
      tokenizer = script_data_escape_start_state;
      textrun.push(0x003C); // LESS-THAN SIGN
      textrun.push(0x0021); // EXCLAMATION MARK
      break;
    default:
      textrun.push(0x003C); // LESS-THAN SIGN
      nextchar--; // pushback
      tokenizer = script_data_state;
      break;
    }
  }

  function script_data_end_tag_open_state(c) {
    /* identical to the RCDATA (and RAWTEXT) end tag open state, except s/RCDATA/Script data/g */
    switch(c) {
    case 0x0041:  // [A-Z]
    case 0x0042:case 0x0043:case 0x0044:case 0x0045:case 0x0046:
    case 0x0047:case 0x0048:case 0x0049:case 0x004A:case 0x004B:
    case 0x004C:case 0x004D:case 0x004E:case 0x004F:case 0x0050:
    case 0x0051:case 0x0052:case 0x0053:case 0x0054:case 0x0055:
    case 0x0056:case 0x0057:case 0x0058:case 0x0059:case 0x005A:
      beginEndTagName();
      tagnamebuf.push(c + 0x0020);
      tempbuf.push(c);
      tokenizer = script_data_end_tag_name_state;
      break;
    case 0x0061:  // [a-z]
    case 0x0062:case 0x0063:case 0x0064:case 0x0065:case 0x0066:
    case 0x0067:case 0x0068:case 0x0069:case 0x006A:case 0x006B:
    case 0x006C:case 0x006D:case 0x006E:case 0x006F:case 0x0070:
    case 0x0071:case 0x0072:case 0x0073:case 0x0074:case 0x0075:
    case 0x0076:case 0x0077:case 0x0078:case 0x0079:case 0x007A:
      beginEndTagName();
      tagnamebuf.push(c);
      tempbuf.push(c);
      tokenizer = script_data_end_tag_name_state;
      break;
    default:
      textrun.push(0x003C); // LESS-THAN SIGN
      textrun.push(0x002F); // SOLIDUS
      nextchar--; // pushback
      tokenizer = script_data_state;
      break;
    }
  }

  function script_data_end_tag_name_state(c) {
    /* identical to the RCDATA (and RAWTEXT) end tag name state, except s/RCDATA/Script data/g */
    switch(c) {
    case 0x0009: // CHARACTER TABULATION (tab)
    case 0x000A: // LINE FEED (LF)
    case 0x000C: // FORM FEED (FF)
    case 0x0020: // SPACE
      if (appropriateEndTag(tagnamebuf)) {
        tokenizer = before_attribute_name_state;
        return;
      }
      break;
    case 0x002F: // SOLIDUS
      if (appropriateEndTag(tagnamebuf)) {
        tokenizer = self_closing_start_tag_state;
        return;
      }
      break;
    case 0x003E: // GREATER-THAN SIGN
      if (appropriateEndTag(tagnamebuf)) {
        tokenizer = data_state;
        emitTag();
        return;
      }
      break;
    case 0x0041:  // [A-Z]
    case 0x0042:case 0x0043:case 0x0044:case 0x0045:case 0x0046:
    case 0x0047:case 0x0048:case 0x0049:case 0x004A:case 0x004B:
    case 0x004C:case 0x004D:case 0x004E:case 0x004F:case 0x0050:
    case 0x0051:case 0x0052:case 0x0053:case 0x0054:case 0x0055:
    case 0x0056:case 0x0057:case 0x0058:case 0x0059:case 0x005A:

      tagnamebuf.push(c + 0x0020);
      tempbuf.push(c);
      return;
    case 0x0061:  // [a-z]
    case 0x0062:case 0x0063:case 0x0064:case 0x0065:case 0x0066:
    case 0x0067:case 0x0068:case 0x0069:case 0x006A:case 0x006B:
    case 0x006C:case 0x006D:case 0x006E:case 0x006F:case 0x0070:
    case 0x0071:case 0x0072:case 0x0073:case 0x0074:case 0x0075:
    case 0x0076:case 0x0077:case 0x0078:case 0x0079:case 0x007A:

      tagnamebuf.push(c);
      tempbuf.push(c);
      return;
    default:
      break;
    }

    // If we don't return in one of the cases above, then this was not
    // an appropriately matching close tag, so back out by emitting all
    // the characters as text
    textrun.push(0x003C); // LESS-THAN SIGN
    textrun.push(0x002F); // SOLIDUS
    pushAll(textrun,tempbuf);
    nextchar--; // pushback
    tokenizer = script_data_state;
  }

  function script_data_escape_start_state(c) {
    if (c === 0x002D) { // HYPHEN-MINUS
      tokenizer = script_data_escape_start_dash_state;
      textrun.push(0x002D); // HYPHEN-MINUS
    }
    else {
      nextchar--; // pushback
      tokenizer = script_data_state;
    }
  }

  function script_data_escape_start_dash_state(c) {
    if (c === 0x002D) { // HYPHEN-MINUS
      tokenizer = script_data_escaped_dash_dash_state;
      textrun.push(0x002D); // HYPHEN-MINUS
    }
    else {
      nextchar--; // pushback
      tokenizer = script_data_state;
    }
  }

  function script_data_escaped_state(c) {
    switch(c) {
    case 0x002D: // HYPHEN-MINUS
      tokenizer = script_data_escaped_dash_state;
      textrun.push(0x002D); // HYPHEN-MINUS
      break;
    case 0x003C: // LESS-THAN SIGN
      tokenizer = script_data_escaped_less_than_sign_state;
      break;
    case 0x0000: // NULL
      textrun.push(0xFFFD); // REPLACEMENT CHARACTER
      break;
    case -1: // EOF
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      textrun.push(c);
      break;
    }
  }

  function script_data_escaped_dash_state(c) {
    switch(c) {
    case 0x002D: // HYPHEN-MINUS
      tokenizer = script_data_escaped_dash_dash_state;
      textrun.push(0x002D); // HYPHEN-MINUS
      break;
    case 0x003C: // LESS-THAN SIGN
      tokenizer = script_data_escaped_less_than_sign_state;
      break;
    case 0x0000: // NULL
      tokenizer = script_data_escaped_state;
      textrun.push(0xFFFD); // REPLACEMENT CHARACTER
      break;
    case -1: // EOF
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      tokenizer = script_data_escaped_state;
      textrun.push(c);
      break;
    }
  }

  function script_data_escaped_dash_dash_state(c) {
    switch(c) {
    case 0x002D: // HYPHEN-MINUS
      textrun.push(0x002D); // HYPHEN-MINUS
      break;
    case 0x003C: // LESS-THAN SIGN
      tokenizer = script_data_escaped_less_than_sign_state;
      break;
    case 0x003E: // GREATER-THAN SIGN
      tokenizer = script_data_state;
      textrun.push(0x003E); // GREATER-THAN SIGN
      break;
    case 0x0000: // NULL
      tokenizer = script_data_escaped_state;
      textrun.push(0xFFFD); // REPLACEMENT CHARACTER
      break;
    case -1: // EOF
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      tokenizer = script_data_escaped_state;
      textrun.push(c);
      break;
    }
  }

  function script_data_escaped_less_than_sign_state(c) {
    switch(c) {
    case 0x002F: // SOLIDUS
      beginTempBuf();
      tokenizer = script_data_escaped_end_tag_open_state;
      break;
    case 0x0041:  // [A-Z]
    case 0x0042:case 0x0043:case 0x0044:case 0x0045:case 0x0046:
    case 0x0047:case 0x0048:case 0x0049:case 0x004A:case 0x004B:
    case 0x004C:case 0x004D:case 0x004E:case 0x004F:case 0x0050:
    case 0x0051:case 0x0052:case 0x0053:case 0x0054:case 0x0055:
    case 0x0056:case 0x0057:case 0x0058:case 0x0059:case 0x005A:
      beginTempBuf();
      tempbuf.push(c + 0x0020);
      tokenizer = script_data_double_escape_start_state;
      textrun.push(0x003C); // LESS-THAN SIGN
      textrun.push(c);
      break;
    case 0x0061:  // [a-z]
    case 0x0062:case 0x0063:case 0x0064:case 0x0065:case 0x0066:
    case 0x0067:case 0x0068:case 0x0069:case 0x006A:case 0x006B:
    case 0x006C:case 0x006D:case 0x006E:case 0x006F:case 0x0070:
    case 0x0071:case 0x0072:case 0x0073:case 0x0074:case 0x0075:
    case 0x0076:case 0x0077:case 0x0078:case 0x0079:case 0x007A:
      beginTempBuf();
      tempbuf.push(c);
      tokenizer = script_data_double_escape_start_state;
      textrun.push(0x003C); // LESS-THAN SIGN
      textrun.push(c);
      break;
    default:
      textrun.push(0x003C); // LESS-THAN SIGN
      nextchar--; // pushback
      tokenizer = script_data_escaped_state;
      break;
    }
  }

  function script_data_escaped_end_tag_open_state(c) {
    switch(c) {
    case 0x0041:  // [A-Z]
    case 0x0042:case 0x0043:case 0x0044:case 0x0045:case 0x0046:
    case 0x0047:case 0x0048:case 0x0049:case 0x004A:case 0x004B:
    case 0x004C:case 0x004D:case 0x004E:case 0x004F:case 0x0050:
    case 0x0051:case 0x0052:case 0x0053:case 0x0054:case 0x0055:
    case 0x0056:case 0x0057:case 0x0058:case 0x0059:case 0x005A:
      beginEndTagName();
      tagnamebuf.push(c + 0x0020);
      tempbuf.push(c);
      tokenizer = script_data_escaped_end_tag_name_state;
      break;
    case 0x0061:  // [a-z]
    case 0x0062:case 0x0063:case 0x0064:case 0x0065:case 0x0066:
    case 0x0067:case 0x0068:case 0x0069:case 0x006A:case 0x006B:
    case 0x006C:case 0x006D:case 0x006E:case 0x006F:case 0x0070:
    case 0x0071:case 0x0072:case 0x0073:case 0x0074:case 0x0075:
    case 0x0076:case 0x0077:case 0x0078:case 0x0079:case 0x007A:
      beginEndTagName();
      tagnamebuf.push(c);
      tempbuf.push(c);
      tokenizer = script_data_escaped_end_tag_name_state;
      break;
    default:
      textrun.push(0x003C); // LESS-THAN SIGN
      textrun.push(0x002F); // SOLIDUS
      nextchar--; // pushback
      tokenizer = script_data_escaped_state;
      break;
    }
  }

  function script_data_escaped_end_tag_name_state(c) {
    switch(c) {
    case 0x0009: // CHARACTER TABULATION (tab)
    case 0x000A: // LINE FEED (LF)
    case 0x000C: // FORM FEED (FF)
    case 0x0020: // SPACE
      if (appropriateEndTag(tagnamebuf)) {
        tokenizer = before_attribute_name_state;
        return;
      }
      break;
    case 0x002F: // SOLIDUS
      if (appropriateEndTag(tagnamebuf)) {
        tokenizer = self_closing_start_tag_state;
        return;
      }
      break;
    case 0x003E: // GREATER-THAN SIGN
      if (appropriateEndTag(tagnamebuf)) {
        tokenizer = data_state;
        emitTag();
        return;
      }
      break;
    case 0x0041:  // [A-Z]
    case 0x0042:case 0x0043:case 0x0044:case 0x0045:case 0x0046:
    case 0x0047:case 0x0048:case 0x0049:case 0x004A:case 0x004B:
    case 0x004C:case 0x004D:case 0x004E:case 0x004F:case 0x0050:
    case 0x0051:case 0x0052:case 0x0053:case 0x0054:case 0x0055:
    case 0x0056:case 0x0057:case 0x0058:case 0x0059:case 0x005A:
      tagnamebuf.push(c + 0x0020);
      tempbuf.push(c);
      return;
    case 0x0061:  // [a-z]
    case 0x0062:case 0x0063:case 0x0064:case 0x0065:case 0x0066:
    case 0x0067:case 0x0068:case 0x0069:case 0x006A:case 0x006B:
    case 0x006C:case 0x006D:case 0x006E:case 0x006F:case 0x0070:
    case 0x0071:case 0x0072:case 0x0073:case 0x0074:case 0x0075:
    case 0x0076:case 0x0077:case 0x0078:case 0x0079:case 0x007A:
      tagnamebuf.push(c);
      tempbuf.push(c);
      return;
    default:
      break;
    }

    // We get here in the default case, and if the closing tagname
    // is not an appropriate tagname.
    textrun.push(0x003C); // LESS-THAN SIGN
    textrun.push(0x002F); // SOLIDUS
    pushAll(textrun,tempbuf);
    nextchar--; // pushback
    tokenizer = script_data_escaped_state;
  }

  function script_data_double_escape_start_state(c) {
    switch(c) {
    case 0x0009: // CHARACTER TABULATION (tab)
    case 0x000A: // LINE FEED (LF)
    case 0x000C: // FORM FEED (FF)
    case 0x0020: // SPACE
    case 0x002F: // SOLIDUS
    case 0x003E: // GREATER-THAN SIGN
      if (buf2str(tempbuf) === "script") {
        tokenizer = script_data_double_escaped_state;
      }
      else {
        tokenizer = script_data_escaped_state;
      }
      textrun.push(c);
      break;
    case 0x0041:  // [A-Z]
    case 0x0042:case 0x0043:case 0x0044:case 0x0045:case 0x0046:
    case 0x0047:case 0x0048:case 0x0049:case 0x004A:case 0x004B:
    case 0x004C:case 0x004D:case 0x004E:case 0x004F:case 0x0050:
    case 0x0051:case 0x0052:case 0x0053:case 0x0054:case 0x0055:
    case 0x0056:case 0x0057:case 0x0058:case 0x0059:case 0x005A:
      tempbuf.push(c + 0x0020);
      textrun.push(c);
      break;
    case 0x0061:  // [a-z]
    case 0x0062:case 0x0063:case 0x0064:case 0x0065:case 0x0066:
    case 0x0067:case 0x0068:case 0x0069:case 0x006A:case 0x006B:
    case 0x006C:case 0x006D:case 0x006E:case 0x006F:case 0x0070:
    case 0x0071:case 0x0072:case 0x0073:case 0x0074:case 0x0075:
    case 0x0076:case 0x0077:case 0x0078:case 0x0079:case 0x007A:
      tempbuf.push(c);
      textrun.push(c);
      break;
    default:
      nextchar--; // pushback
      tokenizer = script_data_escaped_state;
      break;
    }
  }

  function script_data_double_escaped_state(c) {
    switch(c) {
    case 0x002D: // HYPHEN-MINUS
      tokenizer = script_data_double_escaped_dash_state;
      textrun.push(0x002D); // HYPHEN-MINUS
      break;
    case 0x003C: // LESS-THAN SIGN
      tokenizer = script_data_double_escaped_less_than_sign_state;
      textrun.push(0x003C); // LESS-THAN SIGN
      break;
    case 0x0000: // NULL
      textrun.push(0xFFFD); // REPLACEMENT CHARACTER
      break;
    case -1: // EOF
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      textrun.push(c);
      break;
    }
  }

  function script_data_double_escaped_dash_state(c) {
    switch(c) {
    case 0x002D: // HYPHEN-MINUS
      tokenizer = script_data_double_escaped_dash_dash_state;
      textrun.push(0x002D); // HYPHEN-MINUS
      break;
    case 0x003C: // LESS-THAN SIGN
      tokenizer = script_data_double_escaped_less_than_sign_state;
      textrun.push(0x003C); // LESS-THAN SIGN
      break;
    case 0x0000: // NULL
      tokenizer = script_data_double_escaped_state;
      textrun.push(0xFFFD); // REPLACEMENT CHARACTER
      break;
    case -1: // EOF
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      tokenizer = script_data_double_escaped_state;
      textrun.push(c);
      break;
    }
  }

  function script_data_double_escaped_dash_dash_state(c) {
    switch(c) {
    case 0x002D: // HYPHEN-MINUS
      textrun.push(0x002D); // HYPHEN-MINUS
      break;
    case 0x003C: // LESS-THAN SIGN
      tokenizer = script_data_double_escaped_less_than_sign_state;
      textrun.push(0x003C); // LESS-THAN SIGN
      break;
    case 0x003E: // GREATER-THAN SIGN
      tokenizer = script_data_state;
      textrun.push(0x003E); // GREATER-THAN SIGN
      break;
    case 0x0000: // NULL
      tokenizer = script_data_double_escaped_state;
      textrun.push(0xFFFD); // REPLACEMENT CHARACTER
      break;
    case -1: // EOF
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      tokenizer = script_data_double_escaped_state;
      textrun.push(c);
      break;
    }
  }

  function script_data_double_escaped_less_than_sign_state(c) {
    if (c === 0x002F) { // SOLIDUS
      beginTempBuf();
      tokenizer = script_data_double_escape_end_state;
      textrun.push(0x002F); // SOLIDUS
    }
    else {
      nextchar--; // pushback
      tokenizer = script_data_double_escaped_state;
    }
  }

  function script_data_double_escape_end_state(c) {
    switch(c) {
    case 0x0009: // CHARACTER TABULATION (tab)
    case 0x000A: // LINE FEED (LF)
    case 0x000C: // FORM FEED (FF)
    case 0x0020: // SPACE
    case 0x002F: // SOLIDUS
    case 0x003E: // GREATER-THAN SIGN
      if (buf2str(tempbuf) === "script") {
        tokenizer = script_data_escaped_state;
      }
      else {
        tokenizer = script_data_double_escaped_state;
      }
      textrun.push(c);
      break;
    case 0x0041:  // [A-Z]
    case 0x0042:case 0x0043:case 0x0044:case 0x0045:case 0x0046:
    case 0x0047:case 0x0048:case 0x0049:case 0x004A:case 0x004B:
    case 0x004C:case 0x004D:case 0x004E:case 0x004F:case 0x0050:
    case 0x0051:case 0x0052:case 0x0053:case 0x0054:case 0x0055:
    case 0x0056:case 0x0057:case 0x0058:case 0x0059:case 0x005A:
      tempbuf.push(c + 0x0020);
      textrun.push(c);
      break;
    case 0x0061:  // [a-z]
    case 0x0062:case 0x0063:case 0x0064:case 0x0065:case 0x0066:
    case 0x0067:case 0x0068:case 0x0069:case 0x006A:case 0x006B:
    case 0x006C:case 0x006D:case 0x006E:case 0x006F:case 0x0070:
    case 0x0071:case 0x0072:case 0x0073:case 0x0074:case 0x0075:
    case 0x0076:case 0x0077:case 0x0078:case 0x0079:case 0x007A:
      tempbuf.push(c);
      textrun.push(c);
      break;
    default:
      nextchar--; // pushback
      tokenizer = script_data_double_escaped_state;
      break;
    }
  }

  function before_attribute_name_state(c) {
    switch(c) {
    case 0x0009: // CHARACTER TABULATION (tab)
    case 0x000A: // LINE FEED (LF)
    case 0x000C: // FORM FEED (FF)
    case 0x0020: // SPACE
      /* Ignore the character. */
      break;
    case 0x002F: // SOLIDUS
      tokenizer = self_closing_start_tag_state;
      break;
    case 0x003E: // GREATER-THAN SIGN
      tokenizer = data_state;
      emitTag();
      break;
    case 0x0041:  // [A-Z]
    case 0x0042:case 0x0043:case 0x0044:case 0x0045:case 0x0046:
    case 0x0047:case 0x0048:case 0x0049:case 0x004A:case 0x004B:
    case 0x004C:case 0x004D:case 0x004E:case 0x004F:case 0x0050:
    case 0x0051:case 0x0052:case 0x0053:case 0x0054:case 0x0055:
    case 0x0056:case 0x0057:case 0x0058:case 0x0059:case 0x005A:
      beginAttrName();
      attrnamebuf.push(c + 0x0020);
      tokenizer = attribute_name_state;
      break;
    case 0x0000: // NULL
      beginAttrName();
      attrnamebuf.push(0xFFFD);
      tokenizer = attribute_name_state;
      break;
    case -1: // EOF
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    case 0x0022: // QUOTATION MARK
    case 0x0027: // APOSTROPHE
    case 0x003C: // LESS-THAN SIGN
    case 0x003D: // EQUALS SIGN
      /* falls through */
    default:
      if (handleSimpleAttribute()) break;
      beginAttrName();
      attrnamebuf.push(c);
      tokenizer = attribute_name_state;
      break;
    }
  }

  function attribute_name_state(c) {
    switch(c) {
    case 0x0009: // CHARACTER TABULATION (tab)
    case 0x000A: // LINE FEED (LF)
    case 0x000C: // FORM FEED (FF)
    case 0x0020: // SPACE
      tokenizer = after_attribute_name_state;
      break;
    case 0x002F: // SOLIDUS
      addAttribute(attrnamebuf);
      tokenizer = self_closing_start_tag_state;
      break;
    case 0x003D: // EQUALS SIGN
      beginAttrValue();
      tokenizer = before_attribute_value_state;
      break;
    case 0x003E: // GREATER-THAN SIGN
      addAttribute(attrnamebuf);
      tokenizer = data_state;
      emitTag();
      break;
    case 0x0041:  // [A-Z]
    case 0x0042:case 0x0043:case 0x0044:case 0x0045:case 0x0046:
    case 0x0047:case 0x0048:case 0x0049:case 0x004A:case 0x004B:
    case 0x004C:case 0x004D:case 0x004E:case 0x004F:case 0x0050:
    case 0x0051:case 0x0052:case 0x0053:case 0x0054:case 0x0055:
    case 0x0056:case 0x0057:case 0x0058:case 0x0059:case 0x005A:
      attrnamebuf.push(c + 0x0020);
      break;
    case 0x0000: // NULL
      attrnamebuf.push(0xFFFD /* REPLACEMENT CHARACTER */);
      break;
    case -1: // EOF
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    case 0x0022: // QUOTATION MARK
    case 0x0027: // APOSTROPHE
    case 0x003C: // LESS-THAN SIGN
      /* falls through */
    default:
      attrnamebuf.push(c);
      break;
    }
  }

  function after_attribute_name_state(c) {
    switch(c) {
    case 0x0009: // CHARACTER TABULATION (tab)
    case 0x000A: // LINE FEED (LF)
    case 0x000C: // FORM FEED (FF)
    case 0x0020: // SPACE
      /* Ignore the character. */
      break;
    case 0x002F: // SOLIDUS
      addAttribute(attrnamebuf);
      tokenizer = self_closing_start_tag_state;
      break;
    case 0x003D: // EQUALS SIGN
      beginAttrValue();
      tokenizer = before_attribute_value_state;
      break;
    case 0x003E: // GREATER-THAN SIGN
      tokenizer = data_state;
      addAttribute(attrnamebuf);
      emitTag();
      break;
    case 0x0041:  // [A-Z]
    case 0x0042:case 0x0043:case 0x0044:case 0x0045:case 0x0046:
    case 0x0047:case 0x0048:case 0x0049:case 0x004A:case 0x004B:
    case 0x004C:case 0x004D:case 0x004E:case 0x004F:case 0x0050:
    case 0x0051:case 0x0052:case 0x0053:case 0x0054:case 0x0055:
    case 0x0056:case 0x0057:case 0x0058:case 0x0059:case 0x005A:
      addAttribute(attrnamebuf);
      beginAttrName();
      attrnamebuf.push(c + 0x0020);
      tokenizer = attribute_name_state;
      break;
    case 0x0000: // NULL
      addAttribute(attrnamebuf);
      beginAttrName();
      attrnamebuf.push(0xFFFD);
      tokenizer = attribute_name_state;
      break;
    case -1: // EOF
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    case 0x0022: // QUOTATION MARK
    case 0x0027: // APOSTROPHE
    case 0x003C: // LESS-THAN SIGN
      /* falls through */
    default:
      addAttribute(attrnamebuf);
      beginAttrName();
      attrnamebuf.push(c);
      tokenizer = attribute_name_state;
      break;
    }
  }

  function before_attribute_value_state(c) {
    switch(c) {
    case 0x0009: // CHARACTER TABULATION (tab)
    case 0x000A: // LINE FEED (LF)
    case 0x000C: // FORM FEED (FF)
    case 0x0020: // SPACE
      /* Ignore the character. */
      break;
    case 0x0022: // QUOTATION MARK
      tokenizer = attribute_value_double_quoted_state;
      break;
    case 0x0026: // AMPERSAND
      nextchar--; // pushback
      tokenizer = attribute_value_unquoted_state;
      break;
    case 0x0027: // APOSTROPHE
      tokenizer = attribute_value_single_quoted_state;
      break;
    case 0x0000: // NULL
      attrvaluebuf.push(0xFFFD /* REPLACEMENT CHARACTER */);
      tokenizer = attribute_value_unquoted_state;
      break;
    case 0x003E: // GREATER-THAN SIGN
      addAttribute(attrnamebuf);
      emitTag();
      tokenizer = data_state;
      break;
    case -1: // EOF
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    case 0x003C: // LESS-THAN SIGN
    case 0x003D: // EQUALS SIGN
    case 0x0060: // GRAVE ACCENT
      /* falls through */
    default:
      attrvaluebuf.push(c);
      tokenizer = attribute_value_unquoted_state;
      break;
    }
  }

  function attribute_value_double_quoted_state(c) {
    switch(c) {
    case 0x0022: // QUOTATION MARK
      addAttribute(attrnamebuf, attrvaluebuf);
      tokenizer = after_attribute_value_quoted_state;
      break;
    case 0x0026: // AMPERSAND
      pushState();
      tokenizer = character_reference_in_attribute_value_state;
      break;
    case 0x0000: // NULL
      attrvaluebuf.push(0xFFFD /* REPLACEMENT CHARACTER */);
      break;
    case -1: // EOF
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      attrvaluebuf.push(c);
      // appendCharsWhile(attrvaluebuf, DBLQUOTEATTRVAL);
      break;
    }
  }

  function attribute_value_single_quoted_state(c) {
    switch(c) {
    case 0x0027: // APOSTROPHE
      addAttribute(attrnamebuf, attrvaluebuf);
      tokenizer = after_attribute_value_quoted_state;
      break;
    case 0x0026: // AMPERSAND
      pushState();
      tokenizer = character_reference_in_attribute_value_state;
      break;
    case 0x0000: // NULL
      attrvaluebuf.push(0xFFFD /* REPLACEMENT CHARACTER */);
      break;
    case -1: // EOF
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      attrvaluebuf.push(c);
      // appendCharsWhile(attrvaluebuf, SINGLEQUOTEATTRVAL);
      break;
    }
  }

  function attribute_value_unquoted_state(c) {
    switch(c) {
    case 0x0009: // CHARACTER TABULATION (tab)
    case 0x000A: // LINE FEED (LF)
    case 0x000C: // FORM FEED (FF)
    case 0x0020: // SPACE
      addAttribute(attrnamebuf, attrvaluebuf);
      tokenizer = before_attribute_name_state;
      break;
    case 0x0026: // AMPERSAND
      pushState();
      tokenizer = character_reference_in_attribute_value_state;
      break;
    case 0x003E: // GREATER-THAN SIGN
      addAttribute(attrnamebuf, attrvaluebuf);
      tokenizer = data_state;
      emitTag();
      break;
    case 0x0000: // NULL
      attrvaluebuf.push(0xFFFD /* REPLACEMENT CHARACTER */);
      break;
    case -1: // EOF
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    case 0x0022: // QUOTATION MARK
    case 0x0027: // APOSTROPHE
    case 0x003C: // LESS-THAN SIGN
    case 0x003D: // EQUALS SIGN
    case 0x0060: // GRAVE ACCENT
      /* falls through */
    default:
      attrvaluebuf.push(c);
      // appendCharsWhile(attrvaluebuf, UNQUOTEDATTRVAL);
      break;
    }
  }

  function character_reference_in_attribute_value_state(c, lookahead, eof) {
    var char = parseCharRef(lookahead, true);
    if (char !== null) {
      if (typeof char === "number")
        attrvaluebuf.push(char);
      else {
        // An array of numbers
        for(var i = 0; i < char.length; i++) {
          attrvaluebuf.push(char[i]);
        }
      }
    }
    else {
      attrvaluebuf.push(0x0026); // AMPERSAND;
    }

    popState();
  }
  character_reference_in_attribute_value_state.lookahead = ATTRCHARREF;

  function after_attribute_value_quoted_state(c) {
    switch(c) {
    case 0x0009: // CHARACTER TABULATION (tab)
    case 0x000A: // LINE FEED (LF)
    case 0x000C: // FORM FEED (FF)
    case 0x0020: // SPACE
      tokenizer = before_attribute_name_state;
      break;
    case 0x002F: // SOLIDUS
      tokenizer = self_closing_start_tag_state;
      break;
    case 0x003E: // GREATER-THAN SIGN
      tokenizer = data_state;
      emitTag();
      break;
    case -1: // EOF
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      nextchar--; // pushback
      tokenizer = before_attribute_name_state;
      break;
    }
  }

  function self_closing_start_tag_state(c) {
    switch(c) {
    case 0x003E: // GREATER-THAN SIGN
      // Set the <i>self-closing flag</i> of the current tag token.
      tokenizer = data_state;
      emitSelfClosingTag(true);
      break;
    case -1: // EOF
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      nextchar--; // pushback
      tokenizer = before_attribute_name_state;
      break;
    }
  }

  function bogus_comment_state(c, lookahead, eof) {
    var len = lookahead.length;

    if (eof) {
      nextchar += len-1; // don't consume the eof
    }
    else {
      nextchar += len;
    }

    var comment = lookahead.substring(0, len-1);

    comment = comment.replace(/\u0000/g,"\uFFFD");
    comment = comment.replace(/\u000D\u000A/g,"\u000A");
    comment = comment.replace(/\u000D/g,"\u000A");

    insertToken(COMMENT, comment);
    tokenizer = data_state;
  }
  bogus_comment_state.lookahead = ">";

  function markup_declaration_open_state(c, lookahead, eof) {
    if (lookahead[0] === "-" && lookahead[1] === "-") {
      nextchar += 2;
      beginComment();
      tokenizer = comment_start_state;
      return;
    }

    if (lookahead.toUpperCase() === "DOCTYPE") {
      nextchar += 7;
      tokenizer = doctype_state;
    }
    else if (lookahead === "[CDATA[" && cdataAllowed()) {
      nextchar += 7;
      tokenizer = cdata_section_state;
    }
    else {
      tokenizer = bogus_comment_state;
    }
  }
  markup_declaration_open_state.lookahead = 7;

  function comment_start_state(c) {
    beginComment();
    switch(c) {
    case 0x002D: // HYPHEN-MINUS
      tokenizer = comment_start_dash_state;
      break;
    case 0x0000: // NULL
      commentbuf.push(0xFFFD /* REPLACEMENT CHARACTER */);
      tokenizer = comment_state;
      break;
    case 0x003E: // GREATER-THAN SIGN
      tokenizer = data_state;
      insertToken(COMMENT, buf2str(commentbuf));
      break; /* see comment in comment end state */
    case -1: // EOF
      insertToken(COMMENT, buf2str(commentbuf));
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      commentbuf.push(c);
      tokenizer = comment_state;
      break;
    }
  }

  function comment_start_dash_state(c) {
    switch(c) {
    case 0x002D: // HYPHEN-MINUS
      tokenizer = comment_end_state;
      break;
    case 0x0000: // NULL
      commentbuf.push(0x002D /* HYPHEN-MINUS */);
      commentbuf.push(0xFFFD);
      tokenizer = comment_state;
      break;
    case 0x003E: // GREATER-THAN SIGN
      tokenizer = data_state;
      insertToken(COMMENT, buf2str(commentbuf));
      break;
    case -1: // EOF
      insertToken(COMMENT, buf2str(commentbuf));
      nextchar--; // pushback
      tokenizer = data_state;
      break; /* see comment in comment end state */
    default:
      commentbuf.push(0x002D /* HYPHEN-MINUS */);
      commentbuf.push(c);
      tokenizer = comment_state;
      break;
    }
  }

  function comment_state(c) {
    switch(c) {
    case 0x002D: // HYPHEN-MINUS
      tokenizer = comment_end_dash_state;
      break;
    case 0x0000: // NULL
      commentbuf.push(0xFFFD /* REPLACEMENT CHARACTER */);
      break;
    case -1: // EOF
      insertToken(COMMENT, buf2str(commentbuf));
      nextchar--; // pushback
      tokenizer = data_state;
      break; /* see comment in comment end state */
    default:
      commentbuf.push(c);
      break;
    }
  }

  function comment_end_dash_state(c) {
    switch(c) {
    case 0x002D: // HYPHEN-MINUS
      tokenizer = comment_end_state;
      break;
    case 0x0000: // NULL
      commentbuf.push(0x002D /* HYPHEN-MINUS */);
      commentbuf.push(0xFFFD);
      tokenizer = comment_state;
      break;
    case -1: // EOF
      insertToken(COMMENT, buf2str(commentbuf));
      nextchar--; // pushback
      tokenizer = data_state;
      break; /* see comment in comment end state */
    default:
      commentbuf.push(0x002D /* HYPHEN-MINUS */);
      commentbuf.push(c);
      tokenizer = comment_state;
      break;
    }
  }

  function comment_end_state(c) {
    switch(c) {
    case 0x003E: // GREATER-THAN SIGN
      tokenizer = data_state;
      insertToken(COMMENT, buf2str(commentbuf));
      break;
    case 0x0000: // NULL
      commentbuf.push(0x002D);
      commentbuf.push(0x002D);
      commentbuf.push(0xFFFD);
      tokenizer = comment_state;
      break;
    case 0x0021: // EXCLAMATION MARK
      tokenizer = comment_end_bang_state;
      break;
    case 0x002D: // HYPHEN-MINUS
      commentbuf.push(0x002D);
      break;
    case -1: // EOF
      insertToken(COMMENT, buf2str(commentbuf));
      nextchar--; // pushback
      tokenizer = data_state;
      break; /* For security reasons: otherwise, hostile user could put a script in a comment e.g. in a blog comment and then DOS the server so that the end tag isn't read, and then the commented script tag would be treated as live code */
    default:
      commentbuf.push(0x002D);
      commentbuf.push(0x002D);
      commentbuf.push(c);
      tokenizer = comment_state;
      break;
    }
  }

  function comment_end_bang_state(c) {
    switch(c) {
    case 0x002D: // HYPHEN-MINUS
      commentbuf.push(0x002D);
      commentbuf.push(0x002D);
      commentbuf.push(0x0021);
      tokenizer = comment_end_dash_state;
      break;
    case 0x003E: // GREATER-THAN SIGN
      tokenizer = data_state;
      insertToken(COMMENT, buf2str(commentbuf));
      break;
    case 0x0000: // NULL
      commentbuf.push(0x002D);
      commentbuf.push(0x002D);
      commentbuf.push(0x0021);
      commentbuf.push(0xFFFD);
      tokenizer = comment_state;
      break;
    case -1: // EOF
      insertToken(COMMENT, buf2str(commentbuf));
      nextchar--; // pushback
      tokenizer = data_state;
      break; /* see comment in comment end state */
    default:
      commentbuf.push(0x002D);
      commentbuf.push(0x002D);
      commentbuf.push(0x0021);
      commentbuf.push(c);
      tokenizer = comment_state;
      break;
    }
  }

  function doctype_state(c) {
    switch(c) {
    case 0x0009: // CHARACTER TABULATION (tab)
    case 0x000A: // LINE FEED (LF)
    case 0x000C: // FORM FEED (FF)
    case 0x0020: // SPACE
      tokenizer = before_doctype_name_state;
      break;
    case -1: // EOF
      beginDoctype();
      forcequirks();
      emitDoctype();
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      nextchar--; // pushback
      tokenizer = before_doctype_name_state;
      break;
    }
  }

  function before_doctype_name_state(c) {
    switch(c) {
    case 0x0009: // CHARACTER TABULATION (tab)
    case 0x000A: // LINE FEED (LF)
    case 0x000C: // FORM FEED (FF)
    case 0x0020: // SPACE
      /* Ignore the character. */
      break;
    case 0x0041:  // [A-Z]
    case 0x0042:case 0x0043:case 0x0044:case 0x0045:case 0x0046:
    case 0x0047:case 0x0048:case 0x0049:case 0x004A:case 0x004B:
    case 0x004C:case 0x004D:case 0x004E:case 0x004F:case 0x0050:
    case 0x0051:case 0x0052:case 0x0053:case 0x0054:case 0x0055:
    case 0x0056:case 0x0057:case 0x0058:case 0x0059:case 0x005A:
      beginDoctype();
      doctypenamebuf.push(c + 0x0020);
      tokenizer = doctype_name_state;
      break;
    case 0x0000: // NULL
      beginDoctype();
      doctypenamebuf.push(0xFFFD);
      tokenizer = doctype_name_state;
      break;
    case 0x003E: // GREATER-THAN SIGN
      beginDoctype();
      tokenizer = data_state;
      forcequirks();
      emitDoctype();
      break;
    case -1: // EOF
      beginDoctype();
      forcequirks();
      emitDoctype();
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      beginDoctype();
      doctypenamebuf.push(c);
      tokenizer = doctype_name_state;
      break;
    }
  }

  function doctype_name_state(c) {
    switch(c) {
    case 0x0009: // CHARACTER TABULATION (tab)
    case 0x000A: // LINE FEED (LF)
    case 0x000C: // FORM FEED (FF)
    case 0x0020: // SPACE
      tokenizer = after_doctype_name_state;
      break;
    case 0x003E: // GREATER-THAN SIGN
      tokenizer = data_state;
      emitDoctype();
      break;
    case 0x0041:  // [A-Z]
    case 0x0042:case 0x0043:case 0x0044:case 0x0045:case 0x0046:
    case 0x0047:case 0x0048:case 0x0049:case 0x004A:case 0x004B:
    case 0x004C:case 0x004D:case 0x004E:case 0x004F:case 0x0050:
    case 0x0051:case 0x0052:case 0x0053:case 0x0054:case 0x0055:
    case 0x0056:case 0x0057:case 0x0058:case 0x0059:case 0x005A:
      doctypenamebuf.push(c + 0x0020);
      break;
    case 0x0000: // NULL
      doctypenamebuf.push(0xFFFD /* REPLACEMENT CHARACTER */);
      break;
    case -1: // EOF
      forcequirks();
      emitDoctype();
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      doctypenamebuf.push(c);
      break;
    }
  }

  function after_doctype_name_state(c, lookahead, eof) {
    switch(c) {
    case 0x0009: // CHARACTER TABULATION (tab)
    case 0x000A: // LINE FEED (LF)
    case 0x000C: // FORM FEED (FF)
    case 0x0020: // SPACE
      /* Ignore the character. */
      nextchar += 1;
      break;
    case 0x003E: // GREATER-THAN SIGN
      tokenizer = data_state;
      nextchar += 1;
      emitDoctype();
      break;
    case -1: // EOF
      forcequirks();
      emitDoctype();
      tokenizer = data_state;
      break;
    default:
      lookahead = lookahead.toUpperCase();
      if (lookahead === "PUBLIC") {
        nextchar += 6;
        tokenizer = after_doctype_public_keyword_state;
      }
      else if (lookahead === "SYSTEM") {
        nextchar += 6;
        tokenizer = after_doctype_system_keyword_state;
      }
      else {
        forcequirks();
        tokenizer = bogus_doctype_state;
      }
      break;
    }
  }
  after_doctype_name_state.lookahead = 6;

  function after_doctype_public_keyword_state(c) {
    switch(c) {
    case 0x0009: // CHARACTER TABULATION (tab)
    case 0x000A: // LINE FEED (LF)
    case 0x000C: // FORM FEED (FF)
    case 0x0020: // SPACE
      tokenizer = before_doctype_public_identifier_state;
      break;
    case 0x0022: // QUOTATION MARK
      beginDoctypePublicId();
      tokenizer = doctype_public_identifier_double_quoted_state;
      break;
    case 0x0027: // APOSTROPHE
      beginDoctypePublicId();
      tokenizer = doctype_public_identifier_single_quoted_state;
      break;
    case 0x003E: // GREATER-THAN SIGN
      forcequirks();
      tokenizer = data_state;
      emitDoctype();
      break;
    case -1: // EOF
      forcequirks();
      emitDoctype();
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      forcequirks();
      tokenizer = bogus_doctype_state;
      break;
    }
  }

  function before_doctype_public_identifier_state(c) {
    switch(c) {
    case 0x0009: // CHARACTER TABULATION (tab)
    case 0x000A: // LINE FEED (LF)
    case 0x000C: // FORM FEED (FF)
    case 0x0020: // SPACE
      /* Ignore the character. */
      break;
    case 0x0022: // QUOTATION MARK
      beginDoctypePublicId();
      tokenizer = doctype_public_identifier_double_quoted_state;
      break;
    case 0x0027: // APOSTROPHE
      beginDoctypePublicId();
      tokenizer = doctype_public_identifier_single_quoted_state;
      break;
    case 0x003E: // GREATER-THAN SIGN
      forcequirks();
      tokenizer = data_state;
      emitDoctype();
      break;
    case -1: // EOF
      forcequirks();
      emitDoctype();
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      forcequirks();
      tokenizer = bogus_doctype_state;
      break;
    }
  }

  function doctype_public_identifier_double_quoted_state(c) {
    switch(c) {
    case 0x0022: // QUOTATION MARK
      tokenizer = after_doctype_public_identifier_state;
      break;
    case 0x0000: // NULL
      doctypepublicbuf.push(0xFFFD /* REPLACEMENT CHARACTER */);
      break;
    case 0x003E: // GREATER-THAN SIGN
      forcequirks();
      tokenizer = data_state;
      emitDoctype();
      break;
    case -1: // EOF
      forcequirks();
      emitDoctype();
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      doctypepublicbuf.push(c);
      break;
    }
  }

  function doctype_public_identifier_single_quoted_state(c) {
    switch(c) {
    case 0x0027: // APOSTROPHE
      tokenizer = after_doctype_public_identifier_state;
      break;
    case 0x0000: // NULL
      doctypepublicbuf.push(0xFFFD /* REPLACEMENT CHARACTER */);
      break;
    case 0x003E: // GREATER-THAN SIGN
      forcequirks();
      tokenizer = data_state;
      emitDoctype();
      break;
    case -1: // EOF
      forcequirks();
      emitDoctype();
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      doctypepublicbuf.push(c);
      break;
    }
  }

  function after_doctype_public_identifier_state(c) {
    switch(c) {
    case 0x0009: // CHARACTER TABULATION (tab)
    case 0x000A: // LINE FEED (LF)
    case 0x000C: // FORM FEED (FF)
    case 0x0020: // SPACE
      tokenizer = between_doctype_public_and_system_identifiers_state;
      break;
    case 0x003E: // GREATER-THAN SIGN
      tokenizer = data_state;
      emitDoctype();
      break;
    case 0x0022: // QUOTATION MARK
      beginDoctypeSystemId();
      tokenizer = doctype_system_identifier_double_quoted_state;
      break;
    case 0x0027: // APOSTROPHE
      beginDoctypeSystemId();
      tokenizer = doctype_system_identifier_single_quoted_state;
      break;
    case -1: // EOF
      forcequirks();
      emitDoctype();
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      forcequirks();
      tokenizer = bogus_doctype_state;
      break;
    }
  }

  function between_doctype_public_and_system_identifiers_state(c) {
    switch(c) {
    case 0x0009: // CHARACTER TABULATION (tab)
    case 0x000A: // LINE FEED (LF)
    case 0x000C: // FORM FEED (FF)
    case 0x0020: // SPACE Ignore the character.
      break;
    case 0x003E: // GREATER-THAN SIGN
      tokenizer = data_state;
      emitDoctype();
      break;
    case 0x0022: // QUOTATION MARK
      beginDoctypeSystemId();
      tokenizer = doctype_system_identifier_double_quoted_state;
      break;
    case 0x0027: // APOSTROPHE
      beginDoctypeSystemId();
      tokenizer = doctype_system_identifier_single_quoted_state;
      break;
    case -1: // EOF
      forcequirks();
      emitDoctype();
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      forcequirks();
      tokenizer = bogus_doctype_state;
      break;
    }
  }

  function after_doctype_system_keyword_state(c) {
    switch(c) {
    case 0x0009: // CHARACTER TABULATION (tab)
    case 0x000A: // LINE FEED (LF)
    case 0x000C: // FORM FEED (FF)
    case 0x0020: // SPACE
      tokenizer = before_doctype_system_identifier_state;
      break;
    case 0x0022: // QUOTATION MARK
      beginDoctypeSystemId();
      tokenizer = doctype_system_identifier_double_quoted_state;
      break;
    case 0x0027: // APOSTROPHE
      beginDoctypeSystemId();
      tokenizer = doctype_system_identifier_single_quoted_state;
      break;
    case 0x003E: // GREATER-THAN SIGN
      forcequirks();
      tokenizer = data_state;
      emitDoctype();
      break;
    case -1: // EOF
      forcequirks();
      emitDoctype();
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      forcequirks();
      tokenizer = bogus_doctype_state;
      break;
    }
  }

  function before_doctype_system_identifier_state(c) {
    switch(c) {
    case 0x0009: // CHARACTER TABULATION (tab)
    case 0x000A: // LINE FEED (LF)
    case 0x000C: // FORM FEED (FF)
    case 0x0020: // SPACE Ignore the character.
      break;
    case 0x0022: // QUOTATION MARK
      beginDoctypeSystemId();
      tokenizer = doctype_system_identifier_double_quoted_state;
      break;
    case 0x0027: // APOSTROPHE
      beginDoctypeSystemId();
      tokenizer = doctype_system_identifier_single_quoted_state;
      break;
    case 0x003E: // GREATER-THAN SIGN
      forcequirks();
      tokenizer = data_state;
      emitDoctype();
      break;
    case -1: // EOF
      forcequirks();
      emitDoctype();
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      forcequirks();
      tokenizer = bogus_doctype_state;
      break;
    }
  }

  function doctype_system_identifier_double_quoted_state(c) {
    switch(c) {
    case 0x0022: // QUOTATION MARK
      tokenizer = after_doctype_system_identifier_state;
      break;
    case 0x0000: // NULL
      doctypesystembuf.push(0xFFFD /* REPLACEMENT CHARACTER */);
      break;
    case 0x003E: // GREATER-THAN SIGN
      forcequirks();
      tokenizer = data_state;
      emitDoctype();
      break;
    case -1: // EOF
      forcequirks();
      emitDoctype();
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      doctypesystembuf.push(c);
      break;
    }
  }

  function doctype_system_identifier_single_quoted_state(c) {
    switch(c) {
    case 0x0027: // APOSTROPHE
      tokenizer = after_doctype_system_identifier_state;
      break;
    case 0x0000: // NULL
      doctypesystembuf.push(0xFFFD /* REPLACEMENT CHARACTER */);
      break;
    case 0x003E: // GREATER-THAN SIGN
      forcequirks();
      tokenizer = data_state;
      emitDoctype();
      break;
    case -1: // EOF
      forcequirks();
      emitDoctype();
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      doctypesystembuf.push(c);
      break;
    }
  }

  function after_doctype_system_identifier_state(c) {
    switch(c) {
    case 0x0009: // CHARACTER TABULATION (tab)
    case 0x000A: // LINE FEED (LF)
    case 0x000C: // FORM FEED (FF)
    case 0x0020: // SPACE
      /* Ignore the character. */
      break;
    case 0x003E: // GREATER-THAN SIGN
      tokenizer = data_state;
      emitDoctype();
      break;
    case -1: // EOF
      forcequirks();
      emitDoctype();
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      tokenizer = bogus_doctype_state;
      /* This does *not* set the DOCTYPE token's force-quirks flag. */
      break;
    }
  }

  function bogus_doctype_state(c) {
    switch(c) {
    case 0x003E: // GREATER-THAN SIGN
      tokenizer = data_state;
      emitDoctype();
      break;
    case -1: // EOF
      emitDoctype();
      nextchar--; // pushback
      tokenizer = data_state;
      break;
    default:
      /* Ignore the character. */
      break;
    }
  }

  function cdata_section_state(c, lookahead, eof) {
    var len = lookahead.length;
    var output;
    if (eof) {
      nextchar += len-1; // leave the EOF in the scanner
      output = lookahead.substring(0, len-1); // don't include the EOF
    }
    else {
      nextchar += len;
      output = lookahead.substring(0,len-3); // don't emit the ]]>
    }

    if (output.length > 0) {
      if (output.indexOf("\u0000") !== -1)
        textIncludesNUL = true;

      // XXX Have to deal with CR and CRLF here?
      if (output.indexOf("\r") !== -1) {
        output = output.replace(/\r\n/, "\n").replace(/\r/, "\n");
      }

      emitCharString(output);
    }

    tokenizer = data_state;
  }
  cdata_section_state.lookahead = "]]>";


  /***
   * The tree builder insertion modes
   */

  // 11.2.5.4.1 The "initial" insertion mode
  function initial_mode(t, value, arg3, arg4) {
    switch(t) {
    case 1: // TEXT
      value = value.replace(LEADINGWS, ""); // Ignore spaces
      if (value.length === 0) return; // Are we done?
      break; // Handle anything non-space text below
    case 4: // COMMENT
      doc._appendChild(doc.createComment(value));
      return;
    case 5: // DOCTYPE
      var name = value;
      var publicid = arg3;
      var systemid = arg4;
      // Use the constructor directly instead of
      // implementation.createDocumentType because the create
      // function throws errors on invalid characters, and
      // we don't want the parser to throw them.
      doc.appendChild(new DocumentType(name,publicid, systemid));

      // Note that there is no public API for setting quirks mode We can
      // do this here because we have access to implementation details
      if (force_quirks ||
        name.toLowerCase() !== "html" ||
        quirkyPublicIds.test(publicid) ||
        (systemid && systemid.toLowerCase() === quirkySystemId) ||
        (systemid === undefined &&
         conditionallyQuirkyPublicIds.test(publicid)))
        doc._quirks = true;
      else if (limitedQuirkyPublicIds.test(publicid) ||
           (systemid !== undefined &&
            conditionallyQuirkyPublicIds.test(publicid)))
        doc._limitedQuirks = true;
      parser = before_html_mode;
      return;
    }

    // tags or non-whitespace text
    doc._quirks = true;
    parser = before_html_mode;
    parser(t,value,arg3,arg4);
  }

  // 11.2.5.4.2 The "before html" insertion mode
  function before_html_mode(t,value,arg3,arg4) {
    var elt;
    switch(t) {
    case 1: // TEXT
      value = value.replace(LEADINGWS, ""); // Ignore spaces
      if (value.length === 0) return; // Are we done?
      break; // Handle anything non-space text below
    case 5: // DOCTYPE
      /* ignore the token */
      return;
    case 4: // COMMENT
      doc._appendChild(doc.createComment(value));
      return;
    case 2: // TAG
      if (value === "html") {
        elt = createHTMLElt(value, arg3);
        stack.push(elt);
        doc.appendChild(elt);
        // XXX: handle application cache here
        parser = before_head_mode;
        return;
      }
      break;
    case 3: // ENDTAG
      switch(value) {
      case "html":
      case "head":
      case "body":
      case "br":
        break;  // fall through on these
      default:
        return; // ignore most end tags
      }
    }

    // Anything that didn't get handled above is handled like this:
    elt = createHTMLElt("html", null);
    stack.push(elt);
    doc.appendChild(elt);
    // XXX: handle application cache here
    parser = before_head_mode;
    parser(t,value,arg3,arg4);
  }

  // 11.2.5.4.3 The "before head" insertion mode
  function before_head_mode(t,value,arg3,arg4) {
    switch(t) {
    case 1: // TEXT
      value = value.replace(LEADINGWS, "");  // Ignore spaces
      if (value.length === 0) return; // Are we done?
      break;  // Handle anything non-space text below
    case 5: // DOCTYPE
      /* ignore the token */
      return;
    case 4: // COMMENT
      insertComment(value);
      return;
    case 2: // TAG
      switch(value) {
      case "html":
        in_body_mode(t,value,arg3,arg4);
        return;
      case "head":
        var elt = insertHTMLElement(value, arg3);
        head_element_pointer = elt;
        parser = in_head_mode;
        return;
      }
      break;
    case 3: // ENDTAG
      switch(value) {
      case "html":
      case "head":
      case "body":
      case "br":
        break;
      default:
        return; // ignore most end tags
      }
    }

    // If not handled explicitly above
    before_head_mode(TAG, "head", null); // create a head tag
    parser(t, value, arg3, arg4); // then try again with this token
  }

  function in_head_mode(t, value, arg3, arg4) {
    switch(t) {
    case 1: // TEXT
      var ws = value.match(LEADINGWS);
      if (ws) {
        insertText(ws[0]);
        value = value.substring(ws[0].length);
      }
      if (value.length === 0) return;
      break; // Handle non-whitespace below
    case 4: // COMMENT
      insertComment(value);
      return;
    case 5: // DOCTYPE
      return;
    case 2: // TAG
      switch(value) {
      case "html":
        in_body_mode(t, value, arg3, arg4);
        return;
      case "meta":
        // XXX:
        // May need to change the encoding based on this tag
        /* falls through */
      case "base":
      case "basefont":
      case "bgsound":
      case "command":
      case "link":
        insertHTMLElement(value, arg3);
        stack.pop();
        return;
      case "title":
        parseRCDATA(value, arg3);
        return;
      case "noscript":
        if (!scripting_enabled) {
          insertHTMLElement(value, arg3);
          parser = in_head_noscript_mode;
          return;
        }
        // Otherwise, if scripting is enabled...
        /* falls through */
      case "noframes":
      case "style":
        parseRawText(value,arg3);
        return;
      case "script":
        var elt = createHTMLElt(value, arg3);
        elt._parser_inserted = true;
        elt._force_async = false;
        if (fragment) elt._already_started = true;
        flushText();
        stack.top._appendChild(elt);
        stack.push(elt);
        tokenizer = script_data_state;
        originalInsertionMode = parser;
        parser = text_mode;
        return;
      case "head":
        return; // ignore it
      }
      break;
    case 3: // ENDTAG
      switch(value) {
      case "head":
        stack.pop();
        parser = after_head_mode;
        return;
      case "body":
      case "html":
      case "br":
        break; // handle these at the bottom of the function
      default:
        // ignore any other end tag
        return;
      }
      break;
    }

    // If not handled above
    in_head_mode(ENDTAG, "head", null);   // synthetic </head>
    parser(t, value, arg3, arg4);   // Then redo this one
  }

  // 13.2.5.4.5 The "in head noscript" insertion mode
  function in_head_noscript_mode(t, value, arg3, arg4) {
    switch(t) {
    case 5: // DOCTYPE
      return;
    case 4: // COMMENT
      in_head_mode(t, value);
      return;
    case 1: // TEXT
      var ws = value.match(LEADINGWS);
      if (ws) {
        in_head_mode(t, ws[0]);
        value = value.substring(ws[0].length);
      }
      if (value.length === 0) return; // no more text
      break; // Handle non-whitespace below
    case 2: // TAG
      switch(value) {
      case "html":
        in_body_mode(t, value, arg3, arg4);
        return;
      case "basefont":
      case "bgsound":
      case "link":
      case "meta":
      case "noframes":
      case "style":
        in_head_mode(t, value, arg3);
        return;
      case "head":
      case "noscript":
        return;
      }
      break;
    case 3: // ENDTAG
      switch(value) {
      case "noscript":
        stack.pop();
        parser = in_head_mode;
        return;
      case "br":
        break;  // goes to the outer default
      default:
        return; // ignore other end tags
      }
      break;
    }

    // If not handled above
    in_head_noscript_mode(ENDTAG, "noscript", null);
    parser(t, value, arg3, arg4);
  }

  function after_head_mode(t, value, arg3, arg4) {
    switch(t) {
    case 1: // TEXT
      var ws = value.match(LEADINGWS);
      if (ws) {
        insertText(ws[0]);
        value = value.substring(ws[0].length);
      }
      if (value.length === 0) return;
      break; // Handle non-whitespace below
    case 4: // COMMENT
      insertComment(value);
      return;
    case 5: // DOCTYPE
      return;
    case 2: // TAG
      switch(value) {
      case "html":
        in_body_mode(t, value, arg3, arg4);
        return;
      case "body":
        insertHTMLElement(value, arg3);
        frameset_ok = false;
        parser = in_body_mode;
        return;
      case "frameset":
        insertHTMLElement(value, arg3);
        parser = in_frameset_mode;
        return;
      case "base":
      case "basefont":
      case "bgsound":
      case "link":
      case "meta":
      case "noframes":
      case "script":
      case "style":
      case "title":
        stack.push(head_element_pointer);
        in_head_mode(TAG, value, arg3);
        stack.removeElement(head_element_pointer);
        return;
      case "head":
        return;
      }
      break;
    case 3: // ENDTAG
      switch(value) {
      case "body":
      case "html":
      case "br":
        break;
      default:
        return;  // ignore any other end tag
      }
      break;
    }

    after_head_mode(TAG, "body", null);
    frameset_ok = true;
    parser(t, value, arg3, arg4);
  }

  // 13.2.5.4.7 The "in body" insertion mode
  function in_body_mode(t,value,arg3,arg4) {
    var body, i, node;
    switch(t) {
    case 1: // TEXT
      if (textIncludesNUL) {
        value = value.replace(NULCHARS, "");
        if (value.length === 0) return;
      }
      // If any non-space characters
      if (frameset_ok && NONWS.test(value))
        frameset_ok = false;
      afereconstruct();
      insertText(value);
      return;
    case 5: // DOCTYPE
      return;
    case 4: // COMMENT
      insertComment(value);
      return;
    case -1: // EOF
      stopParsing();
      return;
    case 2: // TAG
      switch(value) {
      case "html":
        transferAttributes(arg3, stack.elements[0]);
        return;
      case "base":
      case "basefont":
      case "bgsound":
      case "command":
      case "link":
      case "meta":
      case "noframes":
      case "script":
      case "style":
      case "title":
        in_head_mode(TAG, value, arg3);
        return;
      case "body":
        body = stack.elements[1];
        if (!body || !(body instanceof impl.HTMLBodyElement))
          return;
        frameset_ok = false;
        transferAttributes(arg3, body);
        return;
      case "frameset":
        if (!frameset_ok) return;
        body = stack.elements[1];
        if (!body || !(body instanceof impl.HTMLBodyElement))
          return;
        if (body.parentNode) body.parentNode.removeChild(body);
        while(!(stack.top instanceof impl.HTMLHtmlElement))
          stack.pop();
        insertHTMLElement(value, arg3);
        parser = in_frameset_mode;
        return;

      case "address":
      case "article":
      case "aside":
      case "blockquote":
      case "center":
      case "details":
      case "dir":
      case "div":
      case "dl":
      case "fieldset":
      case "figcaption":
      case "figure":
      case "footer":
      case "header":
      case "hgroup":
      case "menu":
      case "nav":
      case "ol":
      case "p":
      case "section":
      case "summary":
      case "ul":
        if (stack.inButtonScope("p")) in_body_mode(ENDTAG, "p");
        insertHTMLElement(value, arg3);
        return;

      case "h1":
      case "h2":
      case "h3":
      case "h4":
      case "h5":
      case "h6":
        if (stack.inButtonScope("p")) in_body_mode(ENDTAG, "p");
        if (stack.top instanceof impl.HTMLHeadingElement)
          stack.pop();
        insertHTMLElement(value, arg3);
        return;

      case "pre":
      case "listing":
        if (stack.inButtonScope("p")) in_body_mode(ENDTAG, "p");
        insertHTMLElement(value, arg3);
        ignore_linefeed = true;
        frameset_ok = false;
        return;

      case "form":
        if (form_element_pointer) return;
        if (stack.inButtonScope("p")) in_body_mode(ENDTAG, "p");
        form_element_pointer = insertHTMLElement(value, arg3);
        return;

      case "li":
        frameset_ok = false;
        for(i = stack.elements.length-1; i >= 0; i--) {
          node = stack.elements[i];
          if (node instanceof impl.HTMLLIElement) {
            in_body_mode(ENDTAG, "li");
            break;
          }
          if (isA(node, specialSet) && !isA(node, addressdivpSet))
            break;
        }
        if (stack.inButtonScope("p")) in_body_mode(ENDTAG, "p");
        insertHTMLElement(value, arg3);
        return;

      case "dd":
      case "dt":
        frameset_ok = false;
        for(i = stack.elements.length-1; i >= 0; i--) {
          node = stack.elements[i];
          if (isA(node, dddtSet)) {
            in_body_mode(ENDTAG, node.localName);
            break;
          }
          if (isA(node, specialSet) && !isA(node, addressdivpSet))
            break;
        }
        if (stack.inButtonScope("p")) in_body_mode(ENDTAG, "p");
        insertHTMLElement(value, arg3);
        return;

      case "plaintext":
        if (stack.inButtonScope("p")) in_body_mode(ENDTAG, "p");
        insertHTMLElement(value, arg3);
        tokenizer = plaintext_state;
        return;

      case "button":
        if (stack.inScope("button")) {
          in_body_mode(ENDTAG, "button");
          parser(t, value, arg3, arg4);
        }
        else {
          afereconstruct();
          insertHTMLElement(value, arg3);
          frameset_ok = false;
        }
        return;

      case "a":
        var activeElement = afe.findElementByTag("a");
        if (activeElement) {
          in_body_mode(ENDTAG, value);
          afe.remove(activeElement);
          stack.removeElement(activeElement);
        }
        /* falls through */

      case "b":
      case "big":
      case "code":
      case "em":
      case "font":
      case "i":
      case "s":
      case "small":
      case "strike":
      case "strong":
      case "tt":
      case "u":
        afereconstruct();
        afe.push(insertHTMLElement(value,arg3), arg3);
        return;

      case "nobr":
        afereconstruct();

        if (stack.inScope(value)) {
          in_body_mode(ENDTAG, value);
          afereconstruct();
        }
        afe.push(insertHTMLElement(value,arg3), arg3);
        return;

      case "applet":
      case "marquee":
      case "object":
        afereconstruct();
        insertHTMLElement(value,arg3);
        afe.insertMarker();
        frameset_ok = false;
        return;

      case "table":
        if (!doc._quirks && stack.inButtonScope("p")) {
          in_body_mode(ENDTAG, "p");
        }
        insertHTMLElement(value,arg3);
        frameset_ok = false;
        parser = in_table_mode;
        return;

      case "area":
      case "br":
      case "embed":
      case "img":
      case "keygen":
      case "wbr":
        afereconstruct();
        insertHTMLElement(value,arg3);
        stack.pop();
        frameset_ok = false;
        return;

      case "input":
        afereconstruct();
        var elt = insertHTMLElement(value,arg3);
        stack.pop();
        var type = elt.getAttribute("type");
        if (!type || type.toLowerCase() !== "hidden")
          frameset_ok = false;
        return;

      case "param":
      case "source":
      case "track":
        insertHTMLElement(value,arg3);
        stack.pop();
        return;

      case "hr":
        if (stack.inButtonScope("p")) in_body_mode(ENDTAG, "p");
        insertHTMLElement(value,arg3);
        stack.pop();
        frameset_ok = false;
        return;

      case "image":
        in_body_mode(TAG, "img", arg3, arg4);
        return;

      case "isindex":
        if (form_element_pointer) return;
        (function handleIsIndexTag(attrs) {
          var prompt = null;
          var formattrs = [];
          var newattrs = [["name", "isindex"]];
          for(var i = 0; i < attrs.length; i++) {
            var a = attrs[i];
            if (a[0] === "action") {
              formattrs.push(a);
            }
            else if (a[0] === "prompt") {
              prompt = a[1];
            }
            else if (a[0] !== "name") {
              newattrs.push(a);
            }
          }

          // This default prompt presumably needs localization.
          // The space after the colon in this prompt is required
          // by the html5lib test cases
          if (!prompt)
            prompt = "This is a searchable index. " +
            "Enter search keywords: ";

          parser(TAG, "form", formattrs);
          parser(TAG, "hr", null);
          parser(TAG, "label", null);
          parser(TEXT, prompt);
          parser(TAG, "input", newattrs);
          parser(ENDTAG, "label");
          parser(TAG, "hr", null);
          parser(ENDTAG, "form");
        }(arg3));
        return;

      case "textarea":
        insertHTMLElement(value,arg3);
        ignore_linefeed = true;
        frameset_ok = false;
        tokenizer = rcdata_state;
        originalInsertionMode = parser;
        parser = text_mode;
        return;

      case "xmp":
        if (stack.inButtonScope("p")) in_body_mode(ENDTAG, "p");
        afereconstruct();
        frameset_ok = false;
        parseRawText(value, arg3);
        return;

      case "iframe":
        frameset_ok = false;
        parseRawText(value, arg3);
        return;

      case "noembed":
        parseRawText(value,arg3);
        return;

      case "noscript":
        if (scripting_enabled) {
          parseRawText(value,arg3);
          return;
        }
        break;  // XXX Otherwise treat it as any other open tag?

      case "select":
        afereconstruct();
        insertHTMLElement(value,arg3);
        frameset_ok = false;
        if (parser === in_table_mode ||
          parser === in_caption_mode ||
          parser === in_table_body_mode ||
          parser === in_row_mode ||
          parser === in_cell_mode)
          parser = in_select_in_table_mode;
        else
          parser = in_select_mode;
        return;

      case "optgroup":
      case "option":
        if (stack.top instanceof impl.HTMLOptionElement) {
          in_body_mode(ENDTAG, "option");
        }
        afereconstruct();
        insertHTMLElement(value,arg3);
        return;

      case "rp":
      case "rt":
        if (stack.inScope("ruby")) {
          stack.generateImpliedEndTags();
        }
        insertHTMLElement(value,arg3);
        return;

      case "math":
        afereconstruct();
        adjustMathMLAttributes(arg3);
        adjustForeignAttributes(arg3);
        insertForeignElement(value, arg3, NAMESPACE.MATHML);
        if (arg4) // self-closing flag
          stack.pop();
        return;

      case "svg":
        afereconstruct();
        adjustSVGAttributes(arg3);
        adjustForeignAttributes(arg3);
        insertForeignElement(value, arg3, NAMESPACE.SVG);
        if (arg4) // self-closing flag
          stack.pop();
        return;

      case "caption":
      case "col":
      case "colgroup":
      case "frame":
      case "head":
      case "tbody":
      case "td":
      case "tfoot":
      case "th":
      case "thead":
      case "tr":
        // Ignore table tags if we're not in_table mode
        return;
      }

      // Handle any other start tag here
      // (and also noscript tags when scripting is disabled)
      afereconstruct();
      insertHTMLElement(value,arg3);
      return;

    case 3: // ENDTAG
      switch(value) {
      case "body":
        if (!stack.inScope("body")) return;
        parser = after_body_mode;
        return;
      case "html":
        if (!stack.inScope("body")) return;
        parser = after_body_mode;
        parser(t, value, arg3);
        return;

      case "address":
      case "article":
      case "aside":
      case "blockquote":
      case "button":
      case "center":
      case "details":
      case "dir":
      case "div":
      case "dl":
      case "fieldset":
      case "figcaption":
      case "figure":
      case "footer":
      case "header":
      case "hgroup":
      case "listing":
      case "menu":
      case "nav":
      case "ol":
      case "pre":
      case "section":
      case "summary":
      case "ul":
        // Ignore if there is not a matching open tag
        if (!stack.inScope(value)) return;
        stack.generateImpliedEndTags();
        stack.popTag(value);
        return;

      case "form":
        var openform = form_element_pointer;
        form_element_pointer = null;
        if (!openform || !stack.elementInScope(openform)) return;
        stack.generateImpliedEndTags();
        stack.removeElement(openform);
        return;

      case "p":
        if (!stack.inButtonScope(value)) {
          in_body_mode(TAG, value, null);
          parser(t, value, arg3, arg4);
        }
        else {
          stack.generateImpliedEndTags(value);
          stack.popTag(value);
        }
        return;

      case "li":
        if (!stack.inListItemScope(value)) return;
        stack.generateImpliedEndTags(value);
        stack.popTag(value);
        return;

      case "dd":
      case "dt":
        if (!stack.inScope(value)) return;
        stack.generateImpliedEndTags(value);
        stack.popTag(value);
        return;

      case "h1":
      case "h2":
      case "h3":
      case "h4":
      case "h5":
      case "h6":
        if (!stack.elementTypeInScope(impl.HTMLHeadingElement)) return;
        stack.generateImpliedEndTags();
        stack.popElementType(impl.HTMLHeadingElement);
        return;

      case "a":
      case "b":
      case "big":
      case "code":
      case "em":
      case "font":
      case "i":
      case "nobr":
      case "s":
      case "small":
      case "strike":
      case "strong":
      case "tt":
      case "u":
        var result = adoptionAgency(value);
        if (result) return;  // If we did something we're done
        break;         // Go to the "any other end tag" case

      case "applet":
      case "marquee":
      case "object":
        if (!stack.inScope(value)) return;
        stack.generateImpliedEndTags();
        stack.popTag(value);
        afe.clearToMarker();
        return;

      case "br":
        in_body_mode(TAG, value, null);  // Turn </br> into <br>
        return;
      }

      // Any other end tag goes here
      for(i = stack.elements.length-1; i >= 0; i--) {
        node = stack.elements[i];
        if (node.localName === value) {
          stack.generateImpliedEndTags(value);
          stack.popElement(node);
          break;
        }
        else if (isA(node, specialSet)) {
          return;
        }
      }

      return;
    }
  }

  function text_mode(t, value, arg3, arg4) {
    switch(t) {
    case 1: // TEXT
      insertText(value);
      return;
    case -1: // EOF
      if (stack.top instanceof impl.HTMLScriptElement)
        stack.top._already_started = true;
      stack.pop();
      parser = originalInsertionMode;
      parser(t);
      return;
    case 3: // ENDTAG
      if (value === "script") {
        handleScriptEnd();
      }
      else {
        stack.pop();
        parser = originalInsertionMode;
      }
      return;
    default:
      // We should never get any other token types
      return;
    }
  }

  function in_table_mode(t, value, arg3, arg4) {
    function getTypeAttr(attrs) {
      for(var i = 0, n = attrs.length; i < n; i++) {
        if (attrs[i][0] === "type")
          return attrs[i][1].toLowerCase();
      }
      return null;
    }

    switch(t) {
    case 1: // TEXT
      // XXX the text_integration_mode stuff is
      // just a hack I made up
      if (text_integration_mode) {
        in_body_mode(t, value, arg3, arg4);
      }
      else {
        pending_table_text = [];
        originalInsertionMode = parser;
        parser = in_table_text_mode;
        parser(t, value, arg3, arg4);
      }
      return;
    case 4: // COMMENT
      insertComment(value);
      return;
    case 5: // DOCTYPE
      return;
    case 2: // TAG
      switch(value) {
      case "caption":
        stack.clearToContext(impl.HTMLTableElement);
        afe.insertMarker();
        insertHTMLElement(value,arg3);
        parser = in_caption_mode;
        return;
      case "colgroup":
        stack.clearToContext(impl.HTMLTableElement);
        insertHTMLElement(value,arg3);
        parser = in_column_group_mode;
        return;
      case "col":
        in_table_mode(TAG, "colgroup", null);
        parser(t, value, arg3, arg4);
        return;
      case "tbody":
      case "tfoot":
      case "thead":
        stack.clearToContext(impl.HTMLTableElement);
        insertHTMLElement(value,arg3);
        parser = in_table_body_mode;
        return;
      case "td":
      case "th":
      case "tr":
        in_table_mode(TAG, "tbody", null);
        parser(t, value, arg3, arg4);
        return;

      case "table":
        var repro = stack.inTableScope(value);
        in_table_mode(ENDTAG, value);
        if (repro) parser(t, value, arg3, arg4);
        return;

      case "style":
      case "script":
        in_head_mode(t, value, arg3, arg4);
        return;

      case "input":
        var type = getTypeAttr(arg3);
        if (type !== "hidden") break;  // to the anything else case
        insertHTMLElement(value,arg3);
        stack.pop();
        return;

      case "form":
        if (form_element_pointer) return;
        form_element_pointer = insertHTMLElement(value, arg3);
        stack.pop();
        return;
      }
      break;
    case 3: // ENDTAG
      switch(value) {
      case "table":
        if (!stack.inTableScope(value)) return;
        stack.popTag(value);
        resetInsertionMode();
        return;
      case "body":
      case "caption":
      case "col":
      case "colgroup":
      case "html":
      case "tbody":
      case "td":
      case "tfoot":
      case "th":
      case "thead":
      case "tr":
        return;
      }

      break;
    case -1: // EOF
      stopParsing();
      return;
    }

    // This is the anything else case
    foster_parent_mode = true;
    in_body_mode(t, value, arg3, arg4);
    foster_parent_mode = false;
  }

  function in_table_text_mode(t, value, arg3, arg4) {
    if (t === TEXT) {
      if (textIncludesNUL) {
        value = value.replace(NULCHARS, "");
        if (value.length === 0) return;
      }
      pending_table_text.push(value);
    }
    else {
      var s = pending_table_text.join("");
      pending_table_text.length = 0;
      if (NONWS.test(s)) { // If any non-whitespace characters
        // This must be the same code as the "anything else"
        // case of the in_table mode above.
        foster_parent_mode = true;
        in_body_mode(TEXT, s);
        foster_parent_mode = false;
      }
      else {
        insertText(s);
      }
      parser = originalInsertionMode;
      parser(t, value, arg3, arg4);
    }
  }


  function in_caption_mode(t, value, arg3, arg4) {
    function end_caption() {
      if (!stack.inTableScope("caption")) return false;
      stack.generateImpliedEndTags();
      stack.popTag("caption");
      afe.clearToMarker();
      parser = in_table_mode;
      return true;
    }

    switch(t) {
    case 2: // TAG
      switch(value) {
      case "caption":
      case "col":
      case "colgroup":
      case "tbody":
      case "td":
      case "tfoot":
      case "th":
      case "thead":
      case "tr":
        if (end_caption()) parser(t, value, arg3, arg4);
        return;
      }
      break;
    case 3: // ENDTAG
      switch(value) {
      case "caption":
        end_caption();
        return;
      case "table":
        if (end_caption()) parser(t, value, arg3, arg4);
        return;
      case "body":
      case "col":
      case "colgroup":
      case "html":
      case "tbody":
      case "td":
      case "tfoot":
      case "th":
      case "thead":
      case "tr":
        return;
      }
      break;
    }

    // The Anything Else case
    in_body_mode(t, value, arg3, arg4);
  }

  function in_column_group_mode(t, value, arg3, arg4) {
    switch(t) {
    case 1: // TEXT
      var ws = value.match(LEADINGWS);
      if (ws) {
        insertText(ws[0]);
        value = value.substring(ws[0].length);
      }
      if (value.length === 0) return;
      break; // Handle non-whitespace below

    case 4: // COMMENT
      insertComment(value);
      return;
    case 5: // DOCTYPE
      return;
    case 2: // TAG
      switch(value) {
      case "html":
        in_body_mode(t, value, arg3, arg4);
        return;
      case "col":
        insertHTMLElement(value, arg3);
        stack.pop();
        return;
      }
      break;
    case 3: // ENDTAG
      switch(value) {
      case "colgroup":
        if (stack.top instanceof impl.HTMLHtmlElement) return;
        stack.pop();
        parser = in_table_mode;
        return;
      case "col":
        return;
      }
      break;
    case -1: // EOF
      if (stack.top instanceof impl.HTMLHtmlElement) {
        stopParsing();
        return;
      }
      break;
    }

    // Anything else
    if (!(stack.top instanceof impl.HTMLHtmlElement)) {
      in_column_group_mode(ENDTAG, "colgroup");
      parser(t, value, arg3, arg4);
    }
  }

  function in_table_body_mode(t, value, arg3, arg4) {
    function endsect() {
      if (!stack.inTableScope("tbody") &&
        !stack.inTableScope("thead") &&
        !stack.inTableScope("tfoot"))
        return;
      stack.clearToContext(impl.HTMLTableSectionElement);
      in_table_body_mode(ENDTAG, stack.top.localName, null);
      parser(t, value, arg3, arg4);
    }

    switch(t) {
    case 2: // TAG
      switch(value) {
      case "tr":
        stack.clearToContext(impl.HTMLTableSectionElement);
        insertHTMLElement(value, arg3);
        parser = in_row_mode;
        return;
      case "th":
      case "td":
        in_table_body_mode(TAG, "tr", null);
        parser(t, value, arg3, arg4);
        return;
      case "caption":
      case "col":
      case "colgroup":
      case "tbody":
      case "tfoot":
      case "thead":
        endsect();
        return;
      }
      break;
    case 3: // ENDTAG
      switch(value) {
      case "table":
        endsect();
        return;
      case "tbody":
      case "tfoot":
      case "thead":
        if (stack.inTableScope(value)) {
          stack.clearToContext(impl.HTMLTableSectionElement);
          stack.pop();
          parser = in_table_mode;
        }
        return;
      case "body":
      case "caption":
      case "col":
      case "colgroup":
      case "html":
      case "td":
      case "th":
      case "tr":
        return;
      }
      break;
    }

    // Anything else:
    in_table_mode(t, value, arg3, arg4);
  }

  function in_row_mode(t, value, arg3, arg4) {
    function endrow() {
      if (!stack.inTableScope("tr")) return false;
      stack.clearToContext(impl.HTMLTableRowElement);
      stack.pop();
      parser = in_table_body_mode;
      return true;
    }

    switch(t) {
    case 2: // TAG
      switch(value) {
      case "th":
      case "td":
        stack.clearToContext(impl.HTMLTableRowElement);
        insertHTMLElement(value, arg3);
        parser = in_cell_mode;
        afe.insertMarker();
        return;
      case "caption":
      case "col":
      case "colgroup":
      case "tbody":
      case "tfoot":
      case "thead":
      case "tr":
        if (endrow()) parser(t, value, arg3, arg4);
        return;
      }
      break;
    case 3: // ENDTAG
      switch(value) {
      case "tr":
        endrow();
        return;
      case "table":
        if (endrow()) parser(t, value, arg3, arg4);
        return;
      case "tbody":
      case "tfoot":
      case "thead":
        if (stack.inTableScope(value)) {
          in_row_mode(ENDTAG, "tr");
          parser(t, value, arg3, arg4);
        }
        return;
      case "body":
      case "caption":
      case "col":
      case "colgroup":
      case "html":
      case "td":
      case "th":
        return;
      }
      break;
    }

    // anything else
    in_table_mode(t, value, arg3, arg4);
  }

  function in_cell_mode(t, value, arg3, arg4) {
    switch(t) {
    case 2: // TAG
      switch(value) {
      case "caption":
      case "col":
      case "colgroup":
      case "tbody":
      case "td":
      case "tfoot":
      case "th":
      case "thead":
      case "tr":
        if (stack.inTableScope("td")) {
          in_cell_mode(ENDTAG, "td");
          parser(t, value, arg3, arg4);
        }
        else if (stack.inTableScope("th")) {
          in_cell_mode(ENDTAG, "th");
          parser(t, value, arg3, arg4);
        }
        return;
      }
      break;
    case 3: // ENDTAG
      switch(value) {
      case "td":
      case "th":
        if (!stack.inTableScope(value)) return;
        stack.generateImpliedEndTags();
        stack.popTag(value);
        afe.clearToMarker();
        parser = in_row_mode;
        return;

      case "body":
      case "caption":
      case "col":
      case "colgroup":
      case "html":
        return;

      case "table":
      case "tbody":
      case "tfoot":
      case "thead":
      case "tr":
        if (!stack.inTableScope(value)) return;
        in_cell_mode(ENDTAG, stack.inTableScope("td") ? "td" : "th");
        parser(t, value, arg3, arg4);
        return;
      }
      break;
    }

    // anything else
    in_body_mode(t, value, arg3, arg4);
  }

  function in_select_mode(t, value, arg3, arg4) {
    switch(t) {
    case 1: // TEXT
      if (textIncludesNUL) {
        value = value.replace(NULCHARS, "");
        if (value.length === 0) return;
      }
      insertText(value);
      return;
    case 4: // COMMENT
      insertComment(value);
      return;
    case 5: // DOCTYPE
      return;
    case -1: // EOF
      stopParsing();
      return;
    case 2: // TAG
      switch(value) {
      case "html":
        in_body_mode(t, value, arg3, arg4);
        return;
      case "option":
        if (stack.top instanceof impl.HTMLOptionElement)
          in_select_mode(ENDTAG, value);
        insertHTMLElement(value, arg3);
        return;
      case "optgroup":
        if (stack.top instanceof impl.HTMLOptionElement)
          in_select_mode(ENDTAG, "option");
        if (stack.top instanceof impl.HTMLOptGroupElement)
          in_select_mode(ENDTAG, value);
        insertHTMLElement(value, arg3);
        return;
      case "select":
        in_select_mode(ENDTAG, value); // treat it as a close tag
        return;

      case "input":
      case "keygen":
      case "textarea":
        if (!stack.inSelectScope("select")) return;
        in_select_mode(ENDTAG, "select");
        parser(t, value, arg3, arg4);
        return;

      case "script":
        in_head_mode(t, value, arg3, arg4);
        return;
      }
      break;
    case 3: // ENDTAG
      switch(value) {
      case "optgroup":
        if (stack.top instanceof impl.HTMLOptionElement &&
          stack.elements[stack.elements.length-2] instanceof
          impl.HTMLOptGroupElement) {
          in_select_mode(ENDTAG, "option");
        }
        if (stack.top instanceof impl.HTMLOptGroupElement)
          stack.pop();

        return;

      case "option":
        if (stack.top instanceof impl.HTMLOptionElement)
          stack.pop();
        return;

      case "select":
        if (!stack.inSelectScope(value)) return;
        stack.popTag(value);
        resetInsertionMode();
        return;
      }

      break;
    }

    // anything else: just ignore the token
  }

  function in_select_in_table_mode(t, value, arg3, arg4) {
    switch(value) {
    case "caption":
    case "table":
    case "tbody":
    case "tfoot":
    case "thead":
    case "tr":
    case "td":
    case "th":
      switch(t) {
      case 2: // TAG
        in_select_in_table_mode(ENDTAG, "select");
        parser(t, value, arg3, arg4);
        return;
      case 3: // ENDTAG
        if (stack.inTableScope(value)) {
          in_select_in_table_mode(ENDTAG, "select");
          parser(t, value, arg3, arg4);
        }
        return;
      }
    }

    // anything else
    in_select_mode(t, value, arg3, arg4);
  }

  function after_body_mode(t, value, arg3, arg4) {
    switch(t) {
    case 1: // TEXT
      // If any non-space chars, handle below
      if (NONWS.test(value)) break;
      in_body_mode(t, value);
      return;
    case 4: // COMMENT
      // Append it to the <html> element
      stack.elements[0]._appendChild(doc.createComment(value));
      return;
    case 5: // DOCTYPE
      return;
    case -1: // EOF
      stopParsing();
      return;
    case 2: // TAG
      if (value === "html") {
        in_body_mode(t, value, arg3, arg4);
        return;
      }
      break; // for any other tags
    case 3: // ENDTAG
      if (value === "html") {
        if (fragment) return;
        parser = after_after_body_mode;
        return;
      }
      break; // for any other tags
    }

    // anything else
    parser = in_body_mode;
    parser(t, value, arg3, arg4);
  }

  function in_frameset_mode(t, value, arg3, arg4) {
    switch(t) {
    case 1: // TEXT
      // Ignore any non-space characters
      value = value.replace(ALLNONWS, "");
      if (value.length > 0) insertText(value);
      return;
    case 4: // COMMENT
      insertComment(value);
      return;
    case 5: // DOCTYPE
      return;
    case -1: // EOF
      stopParsing();
      return;
    case 2: // TAG
      switch(value) {
      case "html":
        in_body_mode(t, value, arg3, arg4);
        return;
      case "frameset":
        insertHTMLElement(value, arg3);
        return;
      case "frame":
        insertHTMLElement(value, arg3);
        stack.pop();
        return;
      case "noframes":
        in_head_mode(t, value, arg3, arg4);
        return;
      }
      break;
    case 3: // ENDTAG
      if (value === "frameset") {
        if (fragment && stack.top instanceof impl.HTMLHtmlElement)
          return;
        stack.pop();
        if (!fragment &&
          !(stack.top instanceof impl.HTMLFrameSetElement))
          parser = after_frameset_mode;
        return;
      }
      break;
    }

    // ignore anything else
  }

  function after_frameset_mode(t, value, arg3, arg4) {
    switch(t) {
    case 1: // TEXT
      // Ignore any non-space characters
      value = value.replace(ALLNONWS, "");
      if (value.length > 0) insertText(value);
      return;
    case 4: // COMMENT
      insertComment(value);
      return;
    case 5: // DOCTYPE
      return;
    case -1: // EOF
      stopParsing();
      return;
    case 2: // TAG
      switch(value) {
      case "html":
        in_body_mode(t, value, arg3, arg4);
        return;
      case "noframes":
        in_head_mode(t, value, arg3, arg4);
        return;
      }
      break;
    case 3: // ENDTAG
      if (value === "html") {
        parser = after_after_frameset_mode;
        return;
      }
      break;
    }

    // ignore anything else
  }

  function after_after_body_mode(t, value, arg3, arg4) {
    switch(t) {
    case 1: // TEXT
      // If any non-space chars, handle below
      if (NONWS.test(value)) break;
      in_body_mode(t, value, arg3, arg4);
      return;
    case 4: // COMMENT
      doc._appendChild(doc.createComment(value));
      return;
    case 5: // DOCTYPE
      in_body_mode(t, value, arg3, arg4);
      return;
    case -1: // EOF
      stopParsing();
      return;
    case 2: // TAG
      if (value === "html") {
        in_body_mode(t, value, arg3, arg4);
        return;
      }
      break;
    }

    // anything else
    parser = in_body_mode;
    parser(t, value, arg3, arg4);
  }

  function after_after_frameset_mode(t, value, arg3, arg4) {
    switch(t) {
    case 1: // TEXT
      // Ignore any non-space characters
      value = value.replace(ALLNONWS, "");
      if (value.length > 0)
        in_body_mode(t, value, arg3, arg4);
      return;
    case 4: // COMMENT
      doc._appendChild(doc.createComment(value));
      return;
    case 5: // DOCTYPE
      in_body_mode(t, value, arg3, arg4);
      return;
    case -1: // EOF
      stopParsing();
      return;
    case 2: // TAG
      switch(value) {
      case "html":
        in_body_mode(t, value, arg3, arg4);
        return;
      case "noframes":
        in_head_mode(t, value, arg3, arg4);
        return;
      }
      break;
    }

    // ignore anything else
  }


  // 13.2.5.5 The rules for parsing tokens in foreign content
  //
  // This is like one of the insertion modes above, but is
  // invoked somewhat differently when the current token is not HTML.
  // See the insertToken() function.
  function insertForeignToken(t, value, arg3, arg4) {
    // A <font> tag is an HTML font tag if it has a color, font, or size
    // attribute.  Otherwise we assume it is foreign content
    function isHTMLFont(attrs) {
      for(var i = 0, n = attrs.length; i < n; i++) {
        switch(attrs[i][0]) {
        case "color":
        case "font":
        case "size":
          return true;
        }
      }
      return false;
    }

    var current;

    switch(t) {
    case 1: // TEXT
      // If any non-space, non-nul characters
      if (frameset_ok && NONWSNONNUL.test(value))
        frameset_ok = false;
      if (textIncludesNUL) {
        value = value.replace(NULCHARS, "\uFFFD");
      }
      insertText(value);
      return;
    case 4: // COMMENT
      insertComment(value);
      return;
    case 5: // DOCTYPE
      // ignore it
      return;
    case 2: // TAG
      switch(value) {
      case "font":
        if (!isHTMLFont(arg3)) break;
        /* falls through */
      case "b":
      case "big":
      case "blockquote":
      case "body":
      case "br":
      case "center":
      case "code":
      case "dd":
      case "div":
      case "dl":
      case "dt":
      case "em":
      case "embed":
      case "h1":
      case "h2":
      case "h3":
      case "h4":
      case "h5":
      case "h6":
      case "head":
      case "hr":
      case "i":
      case "img":
      case "li":
      case "listing":
      case "menu":
      case "meta":
      case "nobr":
      case "ol":
      case "p":
      case "pre":
      case "ruby":
      case "s":
      case "small":
      case "span":
      case "strong":
      case "strike":
      case "sub":
      case "sup":
      case "table":
      case "tt":
      case "u":
      case "ul":
      case "var":
        do {
          stack.pop();
          current = stack.top;
        } while(current.namespaceURI !== NAMESPACE.HTML &&
            !isMathmlTextIntegrationPoint(current) &&
            !isHTMLIntegrationPoint(current));

        insertToken(t, value, arg3, arg4);  // reprocess
        return;
      }

      // Any other start tag case goes here
      current = stack.top;
      if (current.namespaceURI === NAMESPACE.MATHML) {
        adjustMathMLAttributes(arg3);
      }
      else if (current.namespaceURI === NAMESPACE.SVG) {
        value = adjustSVGTagName(value);
        adjustSVGAttributes(arg3);
      }
      adjustForeignAttributes(arg3);

      insertForeignElement(value, arg3, current.namespaceURI);
      if (arg4) // the self-closing flag
        stack.pop();
      return;

    case 3: // ENDTAG
      current = stack.top;
      if (value === "script" &&
        current.namespaceURI === NAMESPACE.SVG &&
        current.localName === "script") {

        stack.pop();

        // XXX
        // Deal with SVG scripts here
      }
      else {
        // The any other end tag case
        var i = stack.elements.length-1;
        var node = stack.elements[i];
        for(;;) {
          if (node.localName.toLowerCase() === value) {
            stack.popElement(node);
            break;
          }
          node = stack.elements[--i];
          // If non-html, keep looping
          if (node.namespaceURI !== NAMESPACE.HTML)
            continue;
          // Otherwise process the end tag as html
          parser(t, value, arg3, arg4);
          break;
        }
      }
      return;
    }
  }


  /***
   * parsing code for character references
   */

  // Parse a character reference from s and return a codepoint or an
  // array of codepoints or null if there is no valid char ref in s.
  function parseCharRef(s, isattr) {
    var len = s.length;
    var rv;
    if (len === 0) return null; // No character reference matched

    if (s[0] === "#") {         // Numeric character reference
      var codepoint;

      if (s[1] === "x" || s[1] === "X") {
        // Hex
        codepoint = parseInt(s.substring(2), 16);
      }
      else {
        // Decimal
        codepoint = parseInt(s.substring(1), 10);
      }

      if (s[len-1] === ";") // If the string ends with a semicolon
        nextchar += len;    // Consume all the chars
      else
        nextchar += len-1;  // Otherwise, all but the last character

      if (codepoint in numericCharRefReplacements) {
        codepoint = numericCharRefReplacements[codepoint];
      }
      else if (codepoint > 0x10FFFF || (codepoint >= 0xD800 && codepoint < 0xE000)) {
        codepoint = 0xFFFD;
      }

      if (codepoint <= 0xFFFF) return codepoint;

      codepoint = codepoint - 0x10000;
      return [0xD800 + (codepoint >> 10),
          0xDC00 + (codepoint & 0x03FF)];
    }
    else {
      // Named character reference
      // We have to be able to parse some named char refs even when
      // the semicolon is omitted, but have to match the longest one
      // possible.  So if the lookahead doesn't end with semicolon
      // then we have to loop backward looking for longest to shortest
      // matches.  Fortunately, the names that don't require semis
      // are all between 2 and 6 characters long.

      if (s[len-1] === ";") {
        rv = namedCharRefs[s];
        if (rv !== undefined) {
          nextchar += len;  // consume all the characters
          return rv;
        }
      }

      // If it didn't end with a semicolon, see if we can match
      // everything but the terminating character
      len--; // Ignore whatever the terminating character is
      rv = namedCharRefsNoSemi[s.substring(0, len)];
      if (rv !== undefined) {
        nextchar += len;
        return rv;
      }

      // If it still didn't match, and we're not parsing a
      // character reference in an attribute value, then try
      // matching shorter substrings.
      if (!isattr) {
        len--;
        if (len > 6) len = 6; // Maximum possible match length
        while(len >= 2) {
          rv = namedCharRefsNoSemi[s.substring(0, len)];
          if (rv !== undefined) {
            nextchar += len;
            return rv;
          }
          len--;
        }
      }

      // Couldn't find any match
      return null;
    }
  }


  /***
   * Finally, this is the end of the HTMLParser() factory function.
   * It returns the htmlparser object with the append() and end() methods.
   */

  // Sneak another method into the htmlparser object to allow us to run
  // tokenizer tests.  This can be commented out in production code.
  // This is a hook for testing the tokenizer. It has to be here
  // because the tokenizer details are all hidden away within the closure.
  // It should return an array of tokens generated while parsing the
  // input string.
  htmlparser.testTokenizer = function(input, initialState, lastStartTag, charbychar) {
    var tokens = [];

    switch(initialState) {
    case "PCDATA state":
      tokenizer = data_state;
      break;
    case "RCDATA state":
      tokenizer = rcdata_state;
      break;
    case "RAWTEXT state":
      tokenizer = rawtext_state;
      break;
    case "PLAINTEXT state":
      tokenizer = plaintext_state;
      break;
    }

    if (lastStartTag) {
      lasttagname = lastStartTag;
    }

    insertToken = function(t, value, arg3, arg4) {
      flushText();
      switch(t) {
      case 1: // TEXT
        if (tokens.length > 0 &&
          tokens[tokens.length-1][0] === "Character") {
          tokens[tokens.length-1][1] += value;
        }
        else push(tokens, ["Character", value]);
        break;
      case 4: // COMMENT
        push(tokens,["Comment", value]);
        break;
      case 5: // DOCTYPE
        push(tokens,["DOCTYPE", value,
               arg3 === undefined ? null : arg3,
               arg4 === undefined ? null : arg4,
               !force_quirks]);
        break;
      case 2: // TAG
        var attrs = {};
        for(var i = 0; i < arg3.length; i++) {
          // XXX: does attribute order matter?
          var a = arg3[i];
          if (a.length === 1) {
            attrs[a[0]] = "";
          }
          else {
            attrs[a[0]] = a[1];
          }
        }
        var token = ["StartTag", value, attrs];
        if (arg4) token.push(true);
        tokens.push(token);
        break;
      case 3: // ENDTAG
        tokens.push(["EndTag", value]);
        break;
      case -1: // EOF
        break;
      }
    };

    if (!charbychar) {
      this.parse(input, true);
    }
    else {
      for(var i = 0; i < input.length; i++) {
        this.parse(input[i]);
      }
      this.parse("", true);
    }
    return tokens;
  };

  // Return the parser object from the HTMLParser() factory function
  return htmlparser;
}

},{"./Document":9,"./DocumentType":11,"./Node":21,"./htmlelts":34,"./utils":38}],17:[function(require,module,exports){
module.exports = Leaf;

var HierarchyRequestError = require('./utils').HierarchyRequestError;
var Node = require('./Node');
var NodeList = require('./NodeList');

// This class defines common functionality for node subtypes that
// can never have children
function Leaf() {
}

Leaf.prototype = Object.create(Node.prototype, {
  hasChildNodes: { value: function() { return false; }},
  firstChild: { value: null },
  lastChild: { value: null },
  insertBefore: { value: HierarchyRequestError },
  replaceChild: { value: HierarchyRequestError },
  removeChild: { value: HierarchyRequestError },
  appendChild: { value: HierarchyRequestError },
  childNodes: { get: function() {
    if (!this._childNodes) this._childNodes = [];
    return this._childNodes;
  }}
});

},{"./Node":21,"./NodeList":23,"./utils":38}],18:[function(require,module,exports){
var URL = require('./URL');
var URLDecompositionAttributes = require('./URLDecompositionAttributes');

module.exports = Location;

function Location(window, href) {
  this._window = window;
  this._href = href;
}

Location.prototype = Object.create(URLDecompositionAttributes.prototype, {
  constructor: { value: Location },
  // The concrete methods that the superclass needs
  getInput: { value: function() { return this.href; }},
  setOutput: { value: function(v) { this.href = v; }},

  // Special behavior when href is set
  href: {
    get: function() { return this._href; },
    set: function(v) { this.assign(v); }
  },

  assign: { value: function(url) {
    // Resolve the new url against the current one
    // XXX:
    // This is not actually correct. It should be resolved against
    // the URL of the document of the script. For now, though, I only
    // support a single window and there is only one base url.
    // So this is good enough for now.
    var current = new URL(this._href);
    var newurl = current.resolve(url);

    // Save the new url
    this._href = newurl;

    // Start loading the new document!
    // XXX
    // This is just something hacked together.
    // The real algorithm is: http://www.whatwg.org/specs/web-apps/current-work/multipage/history.html#navigate
  }},

  replace: { value: function(url) {
    // XXX
    // Since we aren't tracking history yet, replace is the same as assign
    this.assign(url);
  }},

  reload: { value: function() {
    // XXX:
    // Actually, the spec is a lot more complicated than this
    this.assign(this.href);
  }},

  toString: { value: function() {
    return this.href;
  }}

});

},{"./URL":28,"./URLDecompositionAttributes":29}],19:[function(require,module,exports){
var UIEvent = require('./UIEvent');

module.exports = MouseEvent;

function MouseEvent() {
  // Just use the superclass constructor to initialize
  UIEvent.call(this);

  this.screenX = this.screenY = this.clientX = this.clientY = 0;
  this.ctrlKey = this.altKey = this.shiftKey = this.metaKey = false;
  this.button = 0;
  this.buttons = 1;
  this.relatedTarget = null;
}
MouseEvent.prototype = Object.create(UIEvent.prototype, {
  constructor: { value: MouseEvent },
  initMouseEvent: { value: function(type, bubbles, cancelable,
    view, detail,
    screenX, screenY, clientX, clientY,
    ctrlKey, altKey, shiftKey, metaKey,
    button, relatedTarget) {

    this.initEvent(type, bubbles, cancelable, view, detail);
    this.screenX = screenX;
    this.screenY = screenY;
    this.clientX = clientX;
    this.clientY = clientY;
    this.ctrlKey = ctrlKey;
    this.altKey = altKey;
    this.shiftKey = shiftKey;
    this.metaKey = metaKey;
    this.button = button;
    switch(button) {
    case 0: this.buttons = 1; break;
    case 1: this.buttons = 4; break;
    case 2: this.buttons = 2; break;
    default: this.buttons = 0; break;
    }
    this.relatedTarget = relatedTarget;
  }},

  getModifierState: { value: function(key) {
    switch(key) {
    case "Alt": return this.altKey;
    case "Control": return this.ctrlKey;
    case "Shift": return this.shiftKey;
    case "Meta": return this.metaKey;
    default: return false;
    }
  }}
});

},{"./UIEvent":27}],20:[function(require,module,exports){
module.exports = {
  VALUE: 1, // The value of a Text, Comment or PI node changed
  ATTR: 2, // A new attribute was added or an attribute value and/or prefix changed
  REMOVE_ATTR: 3, // An attribute was removed
  REMOVE: 4, // A node was removed
  MOVE: 5, // A node was moved
  INSERT: 6 // A node (or a subtree of nodes) was inserted
};
},{}],21:[function(require,module,exports){
module.exports = Node;

var EventTarget = require('./EventTarget');
var utils = require('./utils');
var NAMESPACE = utils.NAMESPACE;

// All nodes have a nodeType and an ownerDocument.
// Once inserted, they also have a parentNode.
// This is an abstract class; all nodes in a document are instances
// of a subtype, so all the properties are defined by more specific
// constructors.
function Node() {
}

var ELEMENT_NODE                = Node.ELEMENT_NODE = 1;
var ATTRIBUTE_NODE              = Node.ATTRIBUTE_NODE = 2;
var TEXT_NODE                   = Node.TEXT_NODE = 3;
var CDATA_SECTION_NODE          = Node.CDATA_SECTION_NODE = 4;
var ENTITY_REFERENCE_NODE       = Node.ENTITY_REFERENCE_NODE = 5;
var ENTITY_NODE                 = Node.ENTITY_NODE = 6;
var PROCESSING_INSTRUCTION_NODE = Node.PROCESSING_INSTRUCTION_NODE = 7;
var COMMENT_NODE                = Node.COMMENT_NODE = 8;
var DOCUMENT_NODE               = Node.DOCUMENT_NODE = 9;
var DOCUMENT_TYPE_NODE          = Node.DOCUMENT_TYPE_NODE = 10;
var DOCUMENT_FRAGMENT_NODE      = Node.DOCUMENT_FRAGMENT_NODE = 11;
var NOTATION_NODE               = Node.NOTATION_NODE = 12;

var DOCUMENT_POSITION_DISCONNECTED            = Node.DOCUMENT_POSITION_DISCONNECTED = 0x01;
var DOCUMENT_POSITION_PRECEDING               = Node.DOCUMENT_POSITION_PRECEDING = 0x02;
var DOCUMENT_POSITION_FOLLOWING               = Node.DOCUMENT_POSITION_FOLLOWING = 0x04;
var DOCUMENT_POSITION_CONTAINS                = Node.DOCUMENT_POSITION_CONTAINS = 0x08;
var DOCUMENT_POSITION_CONTAINED_BY            = Node.DOCUMENT_POSITION_CONTAINED_BY = 0x10;
var DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = Node.DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = 0x20;

var hasRawContent = {
  STYLE: true,
  SCRIPT: true,
  XMP: true,
  IFRAME: true,
  NOEMBED: true,
  NOFRAMES: true,
  PLAINTEXT: true,
  NOSCRIPT: true
};

var emptyElements = {
  area: true,
  base: true,
  basefont: true,
  bgsound: true,
  br: true,
  col: true,
  command: true,
  embed: true,
  frame: true,
  hr: true,
  img: true,
  input: true,
  keygen: true,
  link: true,
  meta: true,
  param: true,
  source: true,
  track: true,
  wbr: true
};

var extraNewLine = {
  pre: true,
  textarea: true,
  listing: true
};

Node.prototype = Object.create(EventTarget.prototype, {

  // Node that are not inserted into the tree inherit a null parent
  parentNode: { value: null, writable: true },

  // XXX: the baseURI attribute is defined by dom core, but
  // a correct implementation of it requires HTML features, so
  // we'll come back to this later.
  baseURI: { get: utils.nyi },

  parentElement: { get: function() {
    return (this.parentNode && this.parentNode.nodeType===ELEMENT_NODE) ? this.parentNode : null;
  }},

  hasChildNodes: { value: function() {  // Overridden in leaf.js
    return this.childNodes.length > 0;
  }},

  firstChild: { get: function() {
    return this.childNodes.length === 0 ? null : this.childNodes[0];
  }},

  lastChild: { get: function() {
    return this.childNodes.length === 0 ? null : this.childNodes[this.childNodes.length-1];
  }},

  previousSibling: { get: function() {
    if (!this.parentNode) return null;
    var sibs = this.parentNode.childNodes, i = this.index;
    return i === 0 ? null : sibs[i-1];
  }},

  nextSibling: { get: function() {
    if (!this.parentNode) return null;
    var sibs = this.parentNode.childNodes, i = this.index;
    return i+1 === sibs.length ? null : sibs[i+1];
  }},

  insertBefore: { value: function insertBefore(child, refChild) {
    var parent = this;
    if (refChild === null) return this.appendChild(child);
    if (refChild.parentNode !== parent) utils.NotFoundError();
    if (child.isAncestor(parent)) utils.HierarchyRequestError();
    if (child.nodeType === DOCUMENT_NODE) utils.HierarchyRequestError();
    parent.ensureSameDoc(child);
    child.insert(parent, refChild.index);
    return child;
  }},


  appendChild: { value: function(child) {
    var parent = this;
    if (child.isAncestor(parent)) {
      utils.HierarchyRequestError();
    }
    if (child.nodeType === DOCUMENT_NODE) utils.HierarchyRequestError();
    parent.ensureSameDoc(child);
    return parent._appendChild(child);
  }},

  _appendChild: { value: function(child) {
    child.insert(this, this.childNodes.length);
    return child;
  }},

  removeChild: { value: function removeChild(child) {
    var parent = this;
    if (child.parentNode !== parent) utils.NotFoundError();
    child.remove();
    return child;
  }},

  replaceChild: { value: function replaceChild(newChild, oldChild) {
    var parent = this;
    if (oldChild.parentNode !== parent) utils.NotFoundError();
    if (newChild.isAncestor(parent)) utils.HierarchyRequestError();
    parent.ensureSameDoc(newChild);

    var refChild = oldChild.nextSibling;
    oldChild.remove();
    parent.insertBefore(newChild, refChild);
    return oldChild;
  }},

  compareDocumentPosition: { value: function compareDocumentPosition(that){
    // Basic algorithm for finding the relative position of two nodes.
    // Make a list the ancestors of each node, starting with the
    // document element and proceeding down to the nodes themselves.
    // Then, loop through the lists, looking for the first element
    // that differs.  The order of those two elements give the
    // order of their descendant nodes.  Or, if one list is a prefix
    // of the other one, then that node contains the other.

    if (this === that) return 0;

    // If they're not owned by the same document or if one is rooted
    // and one is not, then they're disconnected.
    if (this.doc != that.doc ||
      this.rooted !== that.rooted)
      return (DOCUMENT_POSITION_DISCONNECTED +
          DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC);

    // Get arrays of ancestors for this and that
    var these = [], those = [];
    for(var n = this; n !== null; n = n.parentNode) these.push(n);
    for(n = that; n !== null; n = n.parentNode) those.push(n);
    these.reverse();  // So we start with the outermost
    those.reverse();

    if (these[0] !== those[0]) // No common ancestor
      return (DOCUMENT_POSITION_DISCONNECTED +
          DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC);

    n = Math.min(these.length, those.length);
    for(var i = 1; i < n; i++) {
      if (these[i] !== those[i]) {
        // We found two different ancestors, so compare
        // their positions
        if (these[i].index < those[i].index)
          return DOCUMENT_POSITION_FOLLOWING;
        else
          return DOCUMENT_POSITION_PRECEDING;
      }
    }

    // If we get to here, then one of the nodes (the one with the
    // shorter list of ancestors) contains the other one.
    if (these.length < those.length)
      return (DOCUMENT_POSITION_FOLLOWING +
          DOCUMENT_POSITION_CONTAINED_BY);
    else
      return (DOCUMENT_POSITION_PRECEDING +
          DOCUMENT_POSITION_CONTAINS);
  }},

  isSameNode: {value : function isSameNode(node) {
    return this === node;
  }},


  // This method implements the generic parts of node equality testing
  // and defers to the (non-recursive) type-specific isEqual() method
  // defined by subclasses
  isEqualNode: { value: function isEqualNode(node) {
    if (!node) return false;
    if (node.nodeType !== this.nodeType) return false;

    // Check for same number of children
    // Check for children this way because it is more efficient
    // for childless leaf nodes.
    var n; // number of child nodes
    if (!this.firstChild) {
      n = 0;
      if (node.firstChild) return false;
    }
    else {
      n = this.childNodes.length;
      if (node.childNodes.length != n) return false;
    }

    // Check type-specific properties for equality
    if (!this.isEqual(node)) return false;

    // Now check children for equality
    for(var i = 0; i < n; i++) {
      var c1 = this.childNodes[i], c2 = node.childNodes[i];
      if (!c1.isEqualNode(c2)) return false;
    }

    return true;
  }},

  // This method delegates shallow cloning to a clone() method
  // that each concrete subclass must implement
  cloneNode: { value: function(deep) {
    // Clone this node
    var clone = this.clone();

    // Handle the recursive case if necessary
    if (deep && this.firstChild) {
      for(var i = 0, n = this.childNodes.length; i < n; i++) {
        clone._appendChild(this.childNodes[i].cloneNode(true));
      }
    }

    return clone;
  }},

  lookupPrefix: { value: function lookupPrefix(ns) {
    var e;
    if (ns === '') return null;
    switch(this.nodeType) {
    case ELEMENT_NODE:
      return this.locateNamespacePrefix(ns);
    case DOCUMENT_NODE:
      e = this.documentElement;
      return e ? e.locateNamespacePrefix(ns) : null;
    case DOCUMENT_TYPE_NODE:
    case DOCUMENT_FRAGMENT_NODE:
      return null;
    default:
      e = this.parentElement;
      return e ? e.locateNamespacePrefix(ns) : null;
    }
  }},


  lookupNamespaceURI: {value: function lookupNamespaceURI(prefix) {
    var e;
    switch(this.nodeType) {
    case ELEMENT_NODE:
      return this.locateNamespace(prefix);
    case DOCUMENT_NODE:
      e = this.documentElement;
      return e ? e.locateNamespace(prefix) : null;
    case DOCUMENT_TYPE_NODE:
    case DOCUMENT_FRAGMENT_NODE:
      return null;
    default:
      e = this.parentElement;
      return e ? e.locateNamespace(prefix) : null;
    }
  }},

  isDefaultNamespace: { value: function isDefaultNamespace(ns) {
    var defaultns = this.lookupNamespaceURI(null);
    if (defaultns == null) defaultns = '';
    return ns === defaultns;
  }},

  // Utility methods for nodes.  Not part of the DOM

  // Return the index of this node in its parent.
  // Throw if no parent, or if this node is not a child of its parent
  index: { get: function() {
    utils.assert(this.parentNode);
    var kids = this.parentNode.childNodes;
    if (this._index == undefined || kids[this._index] != this) {
      this._index = kids.indexOf(this);
      utils.assert(this._index != -1);
    }
    return this._index;
  }},

  // Return true if this node is equal to or is an ancestor of that node
  // Note that nodes are considered to be ancestors of themselves
  isAncestor: { value: function(that) {
    // If they belong to different documents, then they're unrelated.
    if (this.doc != that.doc) return false;
    // If one is rooted and one isn't then they're not related
    if (this.rooted !== that.rooted) return false;

    // Otherwise check by traversing the parentNode chain
    for(var e = that; e; e = e.parentNode) {
      if (e === this) return true;
    }
    return false;
  }},

  // DOMINO Changed the behavior to conform with the specs. See:
  // https://groups.google.com/d/topic/mozilla.dev.platform/77sIYcpdDmc/discussion
  ensureSameDoc: { value: function(that) {
    if (that.ownerDocument === null) {
      that.ownerDocument = this.doc;
    }
    else if(that.ownerDocument !== this.doc) {
      utils.WrongDocumentError();
    }
  }},

  // Remove this node from its parent
  remove: { value: function remove() {
    // Send mutation events if necessary
    if (this.rooted) this.doc.mutateRemove(this);

    // Remove this node from its parents array of children
    this.parentNode.childNodes.splice(this.index, 1);

    // Update the structure id for all ancestors
    this.parentNode.modify();

    // Forget this node's parent
    this.parentNode = undefined;
  }},

  // Remove all of this node's children.  This is a minor
  // optimization that only calls modify() once.
  removeChildren: { value: function removeChildren() {
    var n = this.childNodes.length;
    if (n) {
      var root = this.rooted ? this.ownerDocument : null;
      for(var i = 0; i < n; i++) {
        if (root) root.mutateRemove(this.childNodes[i]);
        this.childNodes[i].parentNode = undefined;
      }
      this.childNodes.length = 0; // Forget all children
      this.modify();              // Update last modified type once only
    }
  }},

  // Insert this node as a child of parent at the specified index,
  // firing mutation events as necessary
  insert: { value: function insert(parent, index) {
    var child = this, kids = parent.childNodes;

    // If we are already a child of the specified parent, then t
    // the index may have to be adjusted.
    if (child.parentNode === parent) {
      var currentIndex = child.index;
      // If we're not moving the node, we're done now
      // XXX: or do DOM mutation events still have to be fired?
      if (currentIndex === index) return;

      // If the child is before the spot it is to be inserted at,
      // then when it is removed, the index of that spot will be
      // reduced.
      if (currentIndex < index) index--;
    }

    // Special case for document fragments
    // XXX: it is not at all clear that I'm handling this correctly.
    // Scripts should never get to see partially
    // inserted fragments, I think.  See:
    // http://lists.w3.org/Archives/Public/www-dom/2011OctDec/0130.html
    if (child.nodeType === DOCUMENT_FRAGMENT_NODE) {
      var  c;
      while((c = child.firstChild))
        c.insert(parent, index++);
      return;
    }

    // If both the child and the parent are rooted, then we want to
    // transplant the child without uprooting and rerooting it.
    if (child.rooted && parent.rooted) {
      // Remove the child from its current position in the tree
      // without calling remove(), since we don't want to uproot it.
      var curpar = child.parentNode, curidx = child.index;
      child.parentNode.childNodes.splice(child.index, 1);
      curpar.modify();

      // And insert it as a child of its new parent
      child.parentNode = parent;
      kids.splice(index, 0, child);
      child._index = index; // Optimization
      parent.modify();

      // Generate a move mutation event
      parent.doc.mutateMove(child);
    }
    else {
      // If the child already has a parent, it needs to be
      // removed from that parent, which may also uproot it
      if (child.parentNode) child.remove();

      // Now insert the child into the parent's array of children
      child.parentNode = parent;
      kids.splice(index, 0, child);

      child._index = index; // Optimization

      // And root the child if necessary
      if (parent.rooted) {
        parent.modify();
        parent.doc.mutateInsert(child);
      }
    }
  }},


  // Return the lastModTime value for this node. (For use as a
  // cache invalidation mechanism. If the node does not already
  // have one, initialize it from the owner document's modclock
  // property. (Note that modclock does not return the actual
  // time; it is simply a counter incremented on each document
  // modification)
  lastModTime: { get: function() {
    if (!this._lastModTime) {
      this._lastModTime = this.doc.modclock;
    }
    return this._lastModTime;
  }},

  // Increment the owner document's modclock and use the new
  // value to update the lastModTime value for this node and
  // all of its ancestors. Nodes that have never had their
  // lastModTime value queried do not need to have a
  // lastModTime property set on them since there is no
  // previously queried value to ever compare the new value
  // against, so only update nodes that already have a
  // _lastModTime property.
  modify: { value: function() {
    if (this.doc.modclock) { // Skip while doc.modclock == 0
      var time = ++this.doc.modclock;
      for(var n = this; n; n = n.parentElement) {
        if (n._lastModTime) {
          n._lastModTime = time;
        }
      }
    }
  }},

  // This attribute is not part of the DOM but is quite helpful.
  // It returns the document with which a node is associated.  Usually
  // this is the ownerDocument. But ownerDocument is null for the
  // document object itself, so this is a handy way to get the document
  // regardless of the node type
  doc: { get: function() {
    return this.ownerDocument || this;
  }},


  // If the node has a nid (node id), then it is rooted in a document
  rooted: { get: function() {
    return !!this._nid;
  }},

  normalize: { value: function() {
    for (var i=0; i < this.childNodes.length; i++) {
      var child = this.childNodes[i];

      if (child.normalize) {
        child.normalize();
      }

      if (child.nodeValue === "") {
        this.removeChild(child);
        i--;
        continue;
      }

      if (i) {
        var prevChild = this.childNodes[i-1];

        if (child.nodeType === Node.TEXT_NODE &&
          prevChild.nodeType === Node.TEXT_NODE) {

          // remove the child and decrement i
          prevChild.appendData(child.nodeValue);

          this.removeChild(child);
          i--;
        }
      }
    }
  }},

  // Convert the children of a node to an HTML string.
  // This is used by the innerHTML getter
  // The serialization spec is at:
  // http://www.whatwg.org/specs/web-apps/current-work/multipage/the-end.html#serializing-html-fragments
  serialize: { value: function() {
    var s = '';
    for(var i = 0, n = this.childNodes.length; i < n; i++) {
      var kid = this.childNodes[i];
      switch(kid.nodeType) {
      case 1: //ELEMENT_NODE
        var ns = kid.namespaceURI;
        var html = ns == NAMESPACE.HTML;
        var tagname = (html || ns == NAMESPACE.SVG || ns == NAMESPACE.MATHML) ? kid.localName : kid.tagName;

        s += '<' + tagname;

        for(var j = 0, k = kid._numattrs; j < k; j++) {
          var a = kid._attr(j);
          s += ' ' + attrname(a);
          if (a.value !== undefined) s += '="' + escapeAttr(a.value) + '"';
        }
        s += '>';

        if (!(html && emptyElements[tagname])) {
          var ss = kid.serialize();
          if (html && extraNewLine[tagname] && ss.charAt(0)==='\n') s += '\n';
          // Serialize children and add end tag for all others
          s += ss;
          s += '</' + tagname + '>';
        }
        break;
      case 3: //TEXT_NODE
      case 4: //CDATA_SECTION_NODE
        var parenttag;
        if (this.nodeType === ELEMENT_NODE &&
          this.namespaceURI === NAMESPACE.HTML)
          parenttag = this.tagName;
        else
          parenttag = '';

        s += hasRawContent[parenttag] ? kid.data : escape(kid.data);
        break;
      case 8: //COMMENT_NODE
        s += '<!--' + kid.data + '-->';
        break;
      case 7: //PROCESSING_INSTRUCTION_NODE
        s += '<?' + kid.target + ' ' + kid.data + '?>';
        break;
      case 10: //DOCUMENT_TYPE_NODE
        s += '<!DOCTYPE ' + kid.name;

        if (kid.publicID) {
          s += ' PUBLIC "' + kid.publicId + '"';
        }

        if (kid.systemId) {
          s += ' "' + kid.systemId + '"';
        }

        s += '>';
        break;
      default:
        utils.InvalidState();
      }
    }

    return s;
  }},

  // mirror node type properties in the prototype, so they are present
  // in instances of Node (and subclasses)
  ELEMENT_NODE:                { value: ELEMENT_NODE },
  ATTRIBUTE_NODE:              { value: ATTRIBUTE_NODE },
  TEXT_NODE:                   { value: TEXT_NODE },
  CDATA_SECTION_NODE:          { value: CDATA_SECTION_NODE },
  ENTITY_REFERENCE_NODE:       { value: ENTITY_REFERENCE_NODE },
  ENTITY_NODE:                 { value: ENTITY_NODE },
  PROCESSING_INSTRUCTION_NODE: { value: PROCESSING_INSTRUCTION_NODE },
  COMMENT_NODE:                { value: COMMENT_NODE },
  DOCUMENT_NODE:               { value: DOCUMENT_NODE },
  DOCUMENT_TYPE_NODE:          { value: DOCUMENT_TYPE_NODE },
  DOCUMENT_FRAGMENT_NODE:      { value: DOCUMENT_FRAGMENT_NODE },
  NOTATION_NODE:               { value: NOTATION_NODE }
});

function escape(s) {
  return s.replace(/[&<>\u00A0]/g, function(c) {
    switch(c) {
    case '&': return '&amp;';
    case '<': return '&lt;';
    case '>': return '&gt;';
    case '\u00A0': return '&nbsp;';
    }
  });
}

function escapeAttr(s) {
  return s.replace(/[&"\u00A0]/g, function(c) {
    switch(c) {
    case '&': return '&amp;';
    case '"': return '&quot;';
    case '\u00A0': return '&nbsp;';
    }
  });
}

function attrname(a) {
  var ns = a.namespaceURI;
  if (!ns)
    return a.localName;
  if (ns == NAMESPACE.XML)
    return 'xml:' + a.localName;
  if (ns == NAMESPACE.XLINK)
    return 'xlink:' + a.localName;

  if (ns == NAMESPACE.XMLNS) {
    if (a.localName === 'xmlns') return 'xmlns';
    else return 'xmlns:' + a.localName;
  }
  return a.name;
}


},{"./EventTarget":14,"./utils":38}],22:[function(require,module,exports){
var NodeFilter = {
  // Constants for acceptNode()
  FILTER_ACCEPT: 1,
  FILTER_REJECT: 2,
  FILTER_SKIP: 3,

  // Constants for whatToShow
  SHOW_ALL: 0xFFFFFFFF,
  SHOW_ELEMENT: 0x1,
  SHOW_ATTRIBUTE: 0x2, // historical
  SHOW_TEXT: 0x4,
  SHOW_CDATA_SECTION: 0x8, // historical
  SHOW_ENTITY_REFERENCE: 0x10, // historical
  SHOW_ENTITY: 0x20, // historical
  SHOW_PROCESSING_INSTRUCTION: 0x40,
  SHOW_COMMENT: 0x80,
  SHOW_DOCUMENT: 0x100,
  SHOW_DOCUMENT_TYPE: 0x200,
  SHOW_DOCUMENT_FRAGMENT: 0x400,
  SHOW_NOTATION: 0x800 // historical
};

module.exports = (NodeFilter.constructor = NodeFilter.prototype = NodeFilter);

},{}],23:[function(require,module,exports){
module.exports = NodeList;

function item(i) {
  return this[i];
}

function NodeList(a) {
  if (!a) a = [];
  a.item = item;
  return a;
}

},{}],24:[function(require,module,exports){
module.exports = ProcessingInstruction;

var Node = require('./Node');
var Leaf = require('./Leaf');

function ProcessingInstruction(doc, target, data) {
  this.nodeType = Node.PROCESSING_INSTRUCTION_NODE;
  this.ownerDocument = doc;
  this.target = target;
  this._data = data;
}

var nodeValue = {
  get: function() { return this._data; },
  set: function(v) {
    this._data = v;
    if (this.rooted) this.ownerDocument.mutateValue(this);
  }
};

ProcessingInstruction.prototype = Object.create(Leaf.prototype, {
  nodeName: { get: function() { return this.target; }},
  nodeValue: nodeValue,
  textContent: nodeValue,
  data: nodeValue,

  // Utility methods
  clone: { value: function clone() {
      return new ProcessingInstruction(this.ownerDocument, this.target, this._data);
  }},
  isEqual: { value: function isEqual(n) {
      return this.target === n.target && this._data === n._data;
  }}

});

},{"./Leaf":17,"./Node":21}],25:[function(require,module,exports){
module.exports = Text;

var utils = require('./utils');
var Node = require('./Node');
var CharacterData = require('./CharacterData');

function Text(doc, data) {
  this.nodeType = Node.TEXT_NODE;
  this.ownerDocument = doc;
  this._data = data;
  this._index = undefined;
}

var nodeValue = {
  get: function() { return this._data; },
  set: function(v) {
    if (v === this._data) return;
    this._data = v;
    if (this.rooted)
      this.ownerDocument.mutateValue(this);
    if (this.parentNode &&
      this.parentNode._textchangehook)
      this.parentNode._textchangehook(this);
  }
};

Text.prototype = Object.create(CharacterData.prototype, {
  nodeName: { value: "#text" },
  // These three attributes are all the same.
  // The data attribute has a [TreatNullAs=EmptyString] but we'll
  // implement that at the interface level
  nodeValue: nodeValue,
  textContent: nodeValue,
  data: nodeValue,

  splitText: { value: function splitText(offset) {
    if (offset > this._data.length || offset < 0) utils.IndexSizeError();

    var newdata = this._data.substring(offset),
      newnode = this.ownerDocument.createTextNode(newdata);
    this.data = this.data.substring(0, offset);

    var parent = this.parentNode;
    if (parent !== null)
      parent.insertBefore(newnode, this.nextSibling);

    return newnode;
  }},

  // XXX
  // wholeText and replaceWholeText() are not implemented yet because
  // the DOMCore specification is considering removing or altering them.
  wholeText: {get: utils.nyi },
  replaceWholeText: { value: utils.nyi },

  // Utility methods
  clone: { value: function clone() {
    return new Text(this.ownerDocument, this._data);
  }},

});

},{"./CharacterData":3,"./Node":21,"./utils":38}],26:[function(require,module,exports){
module.exports = TreeWalker;

var NodeFilter = require('./NodeFilter');

var mapChild = {
  first: 'firstChild',
  last: 'lastChild',
  next: 'firstChild',
  previous: 'lastChild'
};

var mapSibling = {
  next: 'nextSibling',
  previous: 'previousSibling'
};

/* Private methods and helpers */

/**
 * @spec http://www.w3.org/TR/dom/#concept-traverse-children
 * @method
 * @access private
 * @param {TreeWalker} tw
 * @param {string} type One of 'first' or 'last'.
 * @return {Node|null}
 */
function traverseChildren(tw, type) {
  var child, node, parent, result, sibling;
  node = tw.currentNode[mapChild[type]];
  while (node !== null) {
    result = tw.filter.acceptNode(node);
    if (result === NodeFilter.FILTER_ACCEPT) {
      tw.currentNode = node;
      return node;
    }
    if (result === NodeFilter.FILTER_SKIP) {
      child = node[mapChild[type]];
      if (child !== null) {
        node = child;
        continue;
      }
    }
    while (node !== null) {
      sibling = node[mapChild[type]];
      if (sibling !== null) {
        node = sibling;
        break;
      }
      parent = node.parentNode;
      if (parent === null || parent === tw.root || parent === tw.currentNode) {
        return null;
      }
      else {
        node = parent;
      }
    }
  }
  return null;
};

/**
 * @spec http://www.w3.org/TR/dom/#concept-traverse-siblings
 * @method
 * @access private
 * @param {TreeWalker} tw
 * @param {TreeWalker} type One of 'next' or 'previous'.
 * @return {Node|nul}
 */
function traverseSiblings(tw, type) {
  var node, result, sibling;
  node = tw.currentNode;
  if (node === tw.root) {
    return null;
  }
  while (true) {
    sibling = node[mapSibling[type]];
    while (sibling !== null) {
      node = sibling;
      result = tw.filter.acceptNode(node);
      if (result === NodeFilter.FILTER_ACCEPT) {
        tw.currentNode = node;
        return node;
      }
      sibling = node[mapChild[type]];
      if (result === NodeFilter.FILTER_REJECT) {
        sibling = node[mapSibling[type]];
      }
    }
    node = node.parentNode;
    if (node === null || node === tw.root) {
      return null;
    }
    if (tw.filter.acceptNode(node) === NodeFilter.FILTER_ACCEPT) {
      return null;
    }
  }
};

/**
 * @based on WebKit's NodeTraversal::nextSkippingChildren
 * https://trac.webkit.org/browser/trunk/Source/WebCore/dom/NodeTraversal.h?rev=137221#L103
 */
function nextSkippingChildren(node, stayWithin) {
  if (node === stayWithin) {
    return null;
  }
  if (node.nextSibling !== null) {
    return node.nextSibling;
  }

  /**
   * @based on WebKit's NodeTraversal::nextAncestorSibling
   * https://trac.webkit.org/browser/trunk/Source/WebCore/dom/NodeTraversal.cpp?rev=137221#L43
   */
  while (node.parentNode !== null) {
    node = node.parentNode;
    if (node === stayWithin) {
      return null;
    }
    if (node.nextSibling !== null) {
      return node.nextSibling;
    }
  }
  return null;
};

/* Public API */

/**
 * Implemented version: http://www.w3.org/TR/DOM-Level-2-Traversal-Range/traversal.html#Traversal-TreeWalker
 * Latest version: http://www.w3.org/TR/dom/#interface-treewalker
 *
 * @constructor
 * @param {Node} root
 * @param {number} whatToShow [optional]
 * @param {Function} filter [optional]
 * @throws Error
 */
function TreeWalker(root, whatToShow, filter) {
  var tw = this, active = false;

  if (!root || !root.nodeType) {
    throw new Error('DOMException: NOT_SUPPORTED_ERR');
  }

  tw.root = root;
  tw.whatToShow = Number(whatToShow) || 0;

  tw.currentNode = root;

  if (typeof filter == 'function') {
    filter = null;
  }

  tw.filter = Object.create(NodeFilter.prototype);

  /**
   * @method
   * @param {Node} node
   * @return {Number} Constant NodeFilter.FILTER_ACCEPT,
   *  NodeFilter.FILTER_REJECT or NodeFilter.FILTER_SKIP.
   */
  tw.filter.acceptNode = function (node) {
    var result;
    if (active) {
      throw new Error('DOMException: INVALID_STATE_ERR');
    }

    // Maps nodeType to whatToShow
    if (!(((1 << (node.nodeType - 1)) & tw.whatToShow))) {
      return NodeFilter.FILTER_SKIP;
    }

    if (filter === null) {
      return NodeFilter.FILTER_ACCEPT;
    }

    active = true;
    result = filter(node);
    active = false;

    return result;
  };
};

TreeWalker.prototype = {

  constructor: TreeWalker,

  /**
   * @spec http://www.w3.org/TR/dom/#dom-treewalker-parentnode
   * @method
   * @return {Node|null}
   */
  parentNode: function () {
    var node = this.currentNode;
    while (node !== null && node !== this.root) {
      node = node.parentNode;
      if (node !== null && this.filter.acceptNode(node) === NodeFilter.FILTER_ACCEPT) {
        this.currentNode = node;
        return node;
      }
    }
    return null;
  },

  /**
   * @spec http://www.w3.org/TR/dom/#dom-treewalker-firstchild
   * @method
   * @return {Node|null}
   */
  firstChild: function () {
    return traverseChildren(this, 'first');
  },

  /**
   * @spec http://www.w3.org/TR/dom/#dom-treewalker-lastchild
   * @method
   * @return {Node|null}
   */
  lastChild: function () {
    return traverseChildren(this, 'last');
  },

  /**
   * @spec http://www.w3.org/TR/dom/#dom-treewalker-previoussibling
   * @method
   * @return {Node|null}
   */
  previousSibling: function () {
    return traverseSiblings(this, 'previous');
  },

  /**
   * @spec http://www.w3.org/TR/dom/#dom-treewalker-nextsibling
   * @method
   * @return {Node|null}
   */
  nextSibling: function () {
    return traverseSiblings(this, 'next');
  },

  /**
   * @spec http://www.w3.org/TR/dom/#dom-treewalker-previousnode
   * @method
   * @return {Node|null}
   */
  previousNode: function () {
    var node, result, sibling;
    node = this.currentNode;
    while (node !== this.root) {
      sibling = node.previousSibling;
      while (sibling !== null) {
        node = sibling;
        result = this.filter.acceptNode(node);
        while (result !== NodeFilter.FILTER_REJECT && node.lastChild !== null) {
          node = node.lastChild;
          result = this.filter.acceptNode(node);
        }
        if (result === NodeFilter.FILTER_ACCEPT) {
          this.currentNode = node;
          return node;
        }
      }
      if (node === this.root || node.parentNode === null) {
        return null;
      }
      node = node.parentNode;
      if (this.filter.acceptNode(node) === NodeFilter.FILTER_ACCEPT) {
        this.currentNode = node;
        return node;
      }
    }
    return null;
  },

  /**
   * @spec http://www.w3.org/TR/dom/#dom-treewalker-nextnode
   * @method
   * @return {Node|null}
   */
  nextNode: function () {
    var node, result, following;
    node = this.currentNode;
    result = NodeFilter.FILTER_ACCEPT;

    while (true) {
      while (result !== NodeFilter.FILTER_REJECT && node.firstChild !== null) {
        node = node.firstChild;
        result = this.filter.acceptNode(node);
        if (result === NodeFilter.FILTER_ACCEPT) {
          this.currentNode = node;
          return node;
        }
      }
      following = nextSkippingChildren(node, this.root);
      if (following !== null) {
        node = following;
      }
      else {
        return null;
      }
      result = this.filter.acceptNode(node);
      if (result === NodeFilter.FILTER_ACCEPT) {
        this.currentNode = node;
        return node;
      }
    }
  }
};


},{"./NodeFilter":22}],27:[function(require,module,exports){
var Event = require('./Event');

module.exports = UIEvent;

function UIEvent() {
  // Just use the superclass constructor to initialize
  Event.call(this);
  this.view = null; // FF uses the current window
  this.detail = 0;
}
UIEvent.prototype = Object.create(Event.prototype, {
	constructor: { value: UIEvent },
  initUIEvent: { value: function(type, bubbles, cancelable, view, detail) {
    this.initEvent(type, bubbles, cancelable);
    this.view = view;
    this.detail = detail;
  }}
});

},{"./Event":13}],28:[function(require,module,exports){
module.exports = URL;

function URL(url) {
  if (!url) return Object.create(URL.prototype);
  // Can't use String.trim() since it defines whitespace differently than HTML
  this.url = url.replace(/^[ \t\n\r\f]+|[ \t\n\r\f]+$/g, "");

  // See http://tools.ietf.org/html/rfc3986#appendix-B
  var match = URL.pattern.exec(this.url);
  if (match) {
    if (match[2]) this.scheme = match[2];
    if (match[4]) {
      // XXX ignoring userinfo before the hostname
      if (match[4].match(URL.portPattern)) {
        var pos = match[4].lastIndexOf(':');
        this.host = match[4].substring(0, pos);
        this.port = match[4].substring(pos+1);
      }
      else {
        this.host = match[4];
      }
    }
    if (match[5]) this.path = match[5];
    if (match[6]) this.query = match[7];
    if (match[8]) this.fragment = match[9];
  }
}

URL.pattern = /^(([^:\/?#]+):)?(\/\/([^\/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?$/;
URL.portPattern = /:\d+$/;
URL.authorityPattern = /^[^:\/?#]+:\/\//;
URL.hierarchyPattern = /^[^:\/?#]+:\//;

// Return a percentEncoded version of s.
// S should be a single-character string
// XXX: needs to do utf-8 encoding?
URL.percentEncode = function percentEncode(s) {
  var c = charCodeAt(s, 0);
  if (c < 256) return "%" + c.toString(16);
  else throw Error("can't percent-encode codepoints > 255 yet");
};

URL.prototype = {
  constructor: URL,

  // XXX: not sure if this is the precise definition of absolute
  isAbsolute: function() { return !!this.scheme; },
  isAuthorityBased: function() {
    return URL.authorityPattern.test(this.url);
  },
  isHierarchical: function() {
    return URL.hierarchyPattern.test(this.url);
  },

  toString: function() {
    var s = "";
    if (this.scheme !== undefined) s += this.scheme + ":";
    if (this.host !== undefined) s += "//" + this.host;
    if (this.port !== undefined) s += ":" + this.port;
    if (this.path !== undefined) s += this.path;
    if (this.query !== undefined) s += "?" + this.query;
    if (this.fragment !== undefined) s += "#" + this.fragment;
    return s;
  },

  // See: http://tools.ietf.org/html/rfc3986#section-5.2
  resolve: function(relative) {
    var base = this;           // The base url we're resolving against
    var r = new URL(relative); // The relative reference url to resolve
    var t = new URL();         // The absolute target url we will return

    if (r.scheme !== undefined) {
      t.scheme = r.scheme;
      t.host = r.host;
      t.port = r.port;
      t.path = remove_dot_segments(r.path);
      t.query = r.query;
    }
    else {
      t.scheme = base.scheme;
      if (r.host !== undefined) {
        t.host = r.host;
        t.port = r.port;
        t.path = remove_dot_segments(r.path);
        t.query = r.query;
      }
      else {
        t.host = base.host;
        t.port = base.port;
        if (!r.path) { // undefined or empty
          t.path = base.path;
          if (r.query !== undefined)
            t.query = r.query;
          else
            t.query = base.query;
        }
        else {
          if (r.path.charAt(0) === "/") {
            t.path = remove_dot_segments(r.path);
          }
          else {
            t.path = merge(base.path, r.path);
            t.path = remove_dot_segments(t.path);
          }
          t.query = r.query;
        }
      }
    }
    t.fragment = r.fragment;

    return t.toString();


    function merge(basepath, refpath) {
      if (base.host !== undefined && !base.path)
        return "/" + refpath;

      var lastslash = basepath.lastIndexOf("/");
      if (lastslash === -1)
        return refpath;
      else
        return basepath.substring(0, lastslash+1) + refpath;
    }

    function remove_dot_segments(path) {
      if (!path) return path; // For "" or undefined

      var output = "";
      while(path.length > 0) {
        if (path === "." || path === "..") {
          path = "";
          break;
        }

        var twochars = path.substring(0,2);
        var threechars = path.substring(0,3);
        var fourchars = path.substring(0,4);
        if (threechars === "../") {
          path = path.substring(3);
        }
        else if (twochars === "./") {
          path = path.substring(2);
        }
        else if (threechars === "/./") {
          path = "/" + path.substring(3);
        }
        else if (twochars === "/." && path.length === 2) {
          path = "/";
        }
        else if (fourchars === "/../" ||
             (threechars === "/.." && path.length === 3)) {
          path = "/" + path.substring(4);

          output = output.replace(/\/?[^\/]*$/, "");
        }
        else {
          var segment = path.match(/(\/?([^\/]*))/)[0];
          output += segment;
          path = path.substring(segment.length);
        }
      }

      return output;
    }
  },
};

},{}],29:[function(require,module,exports){
var URL = require('./URL');

module.exports = URLDecompositionAttributes;

// This is an abstract superclass for Location, HTMLAnchorElement and
// other types that have the standard complement of "URL decomposition
// IDL attributes".
// Subclasses must define getInput() and setOutput() methods.
// The getter and setter methods parse and rebuild the URL on each
// invocation; there is no attempt to cache the value and be more efficient
function URLDecompositionAttributes() {}
URLDecompositionAttributes.prototype = {
  constructor: URLDecompositionAttributes,

  get protocol() {
    var url = new URL(this.getInput());
    if (url.isAbsolute()) return url.scheme + ":";
    else return "";
  },

  get host() {
    var url = new URL(this.getInput());
    if (url.isAbsolute() && url.isAuthorityBased())
      return url.host + (url.port ? (":" + url.port) : "");
    else
      return "";
  },

  get hostname() {
    var url = new URL(this.getInput());
    if (url.isAbsolute() && url.isAuthorityBased())
      return url.host;
    else
      return "";
  },

  get port() {
    var url = new URL(this.getInput());
    if (url.isAbsolute() && url.isAuthorityBased() && url.port!==undefined)
      return url.port;
    else
      return "";
  },

  get pathname() {
    var url = new URL(this.getInput());
    if (url.isAbsolute() && url.isHierarchical())
      return url.path;
    else
      return "";
  },

  get search() {
    var url = new URL(this.getInput());
    if (url.isAbsolute() && url.isHierarchical() && url.query!==undefined)
      return "?" + url.query;
    else
      return "";
  },

  get hash() {
    var url = new URL(this.getInput());
    if (url.isAbsolute() && url.fragment != undefined)
      return "#" + url.fragment;
    else
      return "";
  },


  set protocol(v) {
    var output = this.getInput();
    var url = new URL(output);
    if (url.isAbsolute()) {
      v = v.replace(/:+$/, "");
      v = v.replace(/[^-+\.a-zA-z0-9]/g, URL.percentEncode);
      if (v.length > 0) {
        url.scheme = v;
        output = url.toString();
      }
    }
    this.setOutput(output);
  },

  set host(v) {
    var output = this.getInput();
    var url = new URL(output);
    if (url.isAbsolute() && url.isAuthorityBased()) {
      v = v.replace(/[^-+\._~!$&'()*,;:=a-zA-z0-9]/g, URL.percentEncode);
      if (v.length > 0) {
        url.host = v;
        delete url.port;
        output = url.toString();
      }
    }
    this.setOutput(output);
  },

  set hostname(v) {
    var output = this.getInput();
    var url = new URL(output);
    if (url.isAbsolute() && url.isAuthorityBased()) {
      v = v.replace(/^\/+/, "");
      v = v.replace(/[^-+\._~!$&'()*,;:=a-zA-z0-9]/g, URL.percentEncode);
      if (v.length > 0) {
        url.host = v;
        output = url.toString();
      }
    }
    this.setOutput(output);
  },

  set port(v) {
    var output = this.getInput();
    var url = new URL(output);
    if (url.isAbsolute() && url.isAuthorityBased()) {
      v = v.replace(/[^0-9].*$/, "");
      v = v.replace(/^0+/, "");
      if (v.length === 0) v = "0";
      if (parseInt(v, 10) <= 65535) {
        url.port = v;
        output = url.toString();
      }
    }
    this.setOutput(output);
  },

  set pathname(v) {
    var output = this.getInput();
    var url = new URL(output);
    if (url.isAbsolute() && url.isHierarchical()) {
      if (v.charAt(0) !== "/")
        v = "/" + v;
      v = v.replace(/[^-+\._~!$&'()*,;:=@\/a-zA-z0-9]/g, URL.percentEncode);
      url.path = v;
      output = url.toString();
    }
    this.setOutput(output);
  },

  set search(v) {
    var output = this.getInput();
    var url = new URL(output);
    if (url.isAbsolute() && url.isHierarchical()) {
      if (v.charAt(0) !== "?") v = v.substring(1);
      v = v.replace(/[^-+\._~!$&'()*,;:=@\/?a-zA-z0-9]/g, URL.percentEncode);
      url.query = v;
      output = url.toString();
    }
    this.setOutput(output);
  },

  set hash(v) {
    var output = this.getInput();
    var url = new URL(output);
    if (url.isAbsolute()) {
      if (v.charAt(0) !== "#") v = v.substring(1);
      v = v.replace(/[^-+\._~!$&'()*,;:=@\/?a-zA-z0-9]/g, URL.percentEncode);
      url.fragment = v;
      output = url.toString();
    }
    this.setOutput(output);
  }
};

},{"./URL":28}],30:[function(require,module,exports){
var DOMImplementation = require('./DOMImplementation');
var Node = require('./Node');
var Document = require('./Document');
var DocumentFragment = require('./DocumentFragment');
var EventTarget = require('./EventTarget');
var Location = require('./Location');
var utils = require('./utils');

module.exports = Window;

function Window(document) {
  this.document = document || new DOMImplementation().createHTMLDocument("");
  this.document._scripting_enabled = true;
  this.document.defaultView = this;
  this.location = new Location(this, "about:blank");
}

Window.prototype = Object.create(EventTarget.prototype, {
  _run: { value: function(code, file) {
    if (file) code += '\n//@ sourceURL=' + file;
    with(this) eval(code);
  }},
  console: { value: console },
  history: { value: {
    back: utils.nyi,
    forward: utils.nyi,
    go: utils.nyi
  }},
  navigator: { value: {
    appName: "node",
    appVersion: "0.1",
    platform: "JavaScript",
    userAgent: "dom"
  }},

  // Self-referential properties
  window: { get: function() { return this; }},
  self: { get: function() { return this; }},
  frames: { get: function() { return this; }},

  // Self-referential properties for a top-level window
  parent: { get: function() { return this; }},
  top: { get: function() { return this; }},

  // We don't support any other windows for now
  length: { value: 0 },           // no frames
  frameElement: { value: null },  // not part of a frame
  opener: { value: null },        // not opened by another window

  // The onload event handler.
  // XXX: need to support a bunch of other event types, too,
  // and have them interoperate with document.body.

  onload: {
    get: function() {
      return this._getEventHandler("load");
    },
    set: function(v) {
      this._setEventHandler("load", v);
    }
  },

  // XXX This is a completely broken implementation
  getComputedStyle: { value: function getComputedStyle(elt) {
    return elt.style;
  }}

});

utils.expose(require('./impl'), Window);

},{"./DOMImplementation":7,"./Document":9,"./DocumentFragment":10,"./EventTarget":14,"./Location":18,"./Node":21,"./impl":35,"./utils":38}],31:[function(require,module,exports){
exports.property = function(attr) {
  if (Array.isArray(attr.type)) {
    var valid = {};
    attr.type.forEach(function(val) {
      valid[val.value || val] = val.alias || val;
    });
    var defaultValue = attr.implied ? '' : valid[0];
    return {
      get: function() {
        var v = this._getattr(attr.name);
        if (v === null) return defaultValue;

        v = valid[v.toLowerCase()];
        if (v !== undefined) return v;
        return defaultValue;
      },
      set: function(v) { 
        this._setattr(attr.name, v);
      }
    };
  }
  else if (attr.type == Boolean) {
    return {
      get: function() {
        return this.hasAttribute(attr.name);
      },
      set: function(v) {
        if (v) {
          this._setattr(attr.name, '');
        }
        else {
          this.removeAttribute(attr.name);
        }
      }
    };
  }
  else if (attr.type == Number) {
    return numberPropDesc(attr);
  }
  else if (!attr.type || attr.type == String) {
    return {
      get: function() { return this._getattr(attr.name) || ''; },
      set: function(v) { this._setattr(attr.name, v); }
    };
  }
  else if (typeof attr.type == 'function') {
    return attr.type(attr.name, attr);
  }
  throw new Error('Invalid attribute definition');
};

// See http://www.whatwg.org/specs/web-apps/current-work/#reflect
//
// defval is the default value. If it is a function, then that function
// will be invoked as a method of the element to obtain the default.
// If no default is specified for a given attribute, then the default
// depends on the type of the attribute, but since this function handles
// 4 integer cases, you must specify the default value in each call
//
// min and max define a valid range for getting the attribute.
//
// setmin defines a minimum value when setting.  If the value is less
// than that, then throw INDEX_SIZE_ERR.
//
// Conveniently, JavaScript's parseInt function appears to be
// compatible with HTML's 'rules for parsing integers'
function numberPropDesc(a) {
  var def;
  if(typeof a.default == 'function') {
    def = a.default;
  }
  else if(typeof a.default == 'number') {
    def = function() { return a.default; };
  }
  else {
    def = function() { utils.assert(false); };
  }

  return {
    get: function() {
      var v = this._getattr(a.name);
      var n = a.float ? parseFloat(v) : parseInt(v, 10);
      if (!isFinite(n) || (a.min !== undefined && n < a.min) || (a.max !== undefined && n > a.max)) {
        return def.call(this);
      }
      return n;
    },
    set: function(v) {
      if (a.setmin !== undefined && v < a.setmin) {
        utils.IndexSizeError(a.name + ' set to ' + v);
      }
      this._setattr(a.name, String(v));
    }
  };
}

// This is a utility function for setting up change handler functions
// for attributes like 'id' that require special handling when they change.
exports.registerChangeHandler = function(c, name, handler) {
  var p = c.prototype;

  // If p does not already have its own _attributeChangeHandlers
  // then create one for it, inheriting from the inherited
  // _attributeChangeHandlers. At the top (for the Element class) the
  // _attributeChangeHandlers object will be created with a null prototype.
  if (!Object.hasOwnProperty(p, '_attributeChangeHandlers')) {
    p._attributeChangeHandlers =
      Object.create(p._attributeChangeHandlers || null);
  }

  p._attributeChangeHandlers[name] = handler;
};
},{}],32:[function(require,module,exports){
/*!
Parser-Lib
Copyright (c) 2009-2011 Nicholas C. Zakas. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/
/* Build time: 12-January-2012 01:05:23 */
var parserlib = {};
(function(){

/**
 * A generic base to inherit from for any object
 * that needs event handling.
 * @class EventTarget
 * @constructor
 */
function EventTarget(){

    /**
     * The array of listeners for various events.
     * @type Object
     * @property _listeners
     * @private
     */
    this._listeners = {};    
}

EventTarget.prototype = {

    //restore constructor
    constructor: EventTarget,

    /**
     * Adds a listener for a given event type.
     * @param {String} type The type of event to add a listener for.
     * @param {Function} listener The function to call when the event occurs.
     * @return {void}
     * @method addListener
     */
    addListener: function(type, listener){
        if (!this._listeners[type]){
            this._listeners[type] = [];
        }

        this._listeners[type].push(listener);
    },
    
    /**
     * Fires an event based on the passed-in object.
     * @param {Object|String} event An object with at least a 'type' attribute
     *      or a string indicating the event name.
     * @return {void}
     * @method fire
     */    
    fire: function(event){
        if (typeof event == "string"){
            event = { type: event };
        }
        if (typeof event.target != "undefined"){
            event.target = this;
        }
        
        if (typeof event.type == "undefined"){
            throw new Error("Event object missing 'type' property.");
        }
        
        if (this._listeners[event.type]){
        
            //create a copy of the array and use that so listeners can't chane
            var listeners = this._listeners[event.type].concat();
            for (var i=0, len=listeners.length; i < len; i++){
                listeners[i].call(this, event);
            }
        }            
    },

    /**
     * Removes a listener for a given event type.
     * @param {String} type The type of event to remove a listener from.
     * @param {Function} listener The function to remove from the event.
     * @return {void}
     * @method removeListener
     */
    removeListener: function(type, listener){
        if (this._listeners[type]){
            var listeners = this._listeners[type];
            for (var i=0, len=listeners.length; i < len; i++){
                if (listeners[i] === listener){
                    listeners.splice(i, 1);
                    break;
                }
            }
            
            
        }            
    }
};
/**
 * Convenient way to read through strings.
 * @namespace parserlib.util
 * @class StringReader
 * @constructor
 * @param {String} text The text to read.
 */
function StringReader(text){

    /**
     * The input text with line endings normalized.
     * @property _input
     * @type String
     * @private
     */
    this._input = text.replace(/\n\r?/g, "\n");


    /**
     * The row for the character to be read next.
     * @property _line
     * @type int
     * @private
     */
    this._line = 1;


    /**
     * The column for the character to be read next.
     * @property _col
     * @type int
     * @private
     */
    this._col = 1;

    /**
     * The index of the character in the input to be read next.
     * @property _cursor
     * @type int
     * @private
     */
    this._cursor = 0;
}

StringReader.prototype = {

    //restore constructor
    constructor: StringReader,

    //-------------------------------------------------------------------------
    // Position info
    //-------------------------------------------------------------------------

    /**
     * Returns the column of the character to be read next.
     * @return {int} The column of the character to be read next.
     * @method getCol
     */
    getCol: function(){
        return this._col;
    },

    /**
     * Returns the row of the character to be read next.
     * @return {int} The row of the character to be read next.
     * @method getLine
     */
    getLine: function(){
        return this._line ;
    },

    /**
     * Determines if you're at the end of the input.
     * @return {Boolean} True if there's no more input, false otherwise.
     * @method eof
     */
    eof: function(){
        return (this._cursor == this._input.length);
    },

    //-------------------------------------------------------------------------
    // Basic reading
    //-------------------------------------------------------------------------

    /**
     * Reads the next character without advancing the cursor.
     * @param {int} count How many characters to look ahead (default is 1).
     * @return {String} The next character or null if there is no next character.
     * @method peek
     */
    peek: function(count){
        var c = null;
        count = (typeof count == "undefined" ? 1 : count);

        //if we're not at the end of the input...
        if (this._cursor < this._input.length){

            //get character and increment cursor and column
            c = this._input.charAt(this._cursor + count - 1);
        }

        return c;
    },

    /**
     * Reads the next character from the input and adjusts the row and column
     * accordingly.
     * @return {String} The next character or null if there is no next character.
     * @method read
     */
    read: function(){
        var c = null;

        //if we're not at the end of the input...
        if (this._cursor < this._input.length){

            //if the last character was a newline, increment row count
            //and reset column count
            if (this._input.charAt(this._cursor) == "\n"){
                this._line++;
                this._col=1;
            } else {
                this._col++;
            }

            //get character and increment cursor and column
            c = this._input.charAt(this._cursor++);
        }

        return c;
    },

    //-------------------------------------------------------------------------
    // Misc
    //-------------------------------------------------------------------------

    /**
     * Saves the current location so it can be returned to later.
     * @method mark
     * @return {void}
     */
    mark: function(){
        this._bookmark = {
            cursor: this._cursor,
            line:   this._line,
            col:    this._col
        };
    },

    reset: function(){
        if (this._bookmark){
            this._cursor = this._bookmark.cursor;
            this._line = this._bookmark.line;
            this._col = this._bookmark.col;
            delete this._bookmark;
        }
    },

    //-------------------------------------------------------------------------
    // Advanced reading
    //-------------------------------------------------------------------------

    /**
     * Reads up to and including the given string. Throws an error if that
     * string is not found.
     * @param {String} pattern The string to read.
     * @return {String} The string when it is found.
     * @throws Error when the string pattern is not found.
     * @method readTo
     */
    readTo: function(pattern){

        var buffer = "",
            c;

        /*
         * First, buffer must be the same length as the pattern.
         * Then, buffer must end with the pattern or else reach the
         * end of the input.
         */
        while (buffer.length < pattern.length || buffer.lastIndexOf(pattern) != buffer.length - pattern.length){
            c = this.read();
            if (c){
                buffer += c;
            } else {
                throw new Error("Expected \"" + pattern + "\" at line " + this._line  + ", col " + this._col + ".");
            }
        }

        return buffer;

    },

    /**
     * Reads characters while each character causes the given
     * filter function to return true. The function is passed
     * in each character and either returns true to continue
     * reading or false to stop.
     * @param {Function} filter The function to read on each character.
     * @return {String} The string made up of all characters that passed the
     *      filter check.
     * @method readWhile
     */
    readWhile: function(filter){

        var buffer = "",
            c = this.read();

        while(c !== null && filter(c)){
            buffer += c;
            c = this.read();
        }

        return buffer;

    },

    /**
     * Reads characters that match either text or a regular expression and
     * returns those characters. If a match is found, the row and column
     * are adjusted; if no match is found, the reader's state is unchanged.
     * reading or false to stop.
     * @param {String|RegExp} matchter If a string, then the literal string
     *      value is searched for. If a regular expression, then any string
     *      matching the pattern is search for.
     * @return {String} The string made up of all characters that matched or
     *      null if there was no match.
     * @method readMatch
     */
    readMatch: function(matcher){

        var source = this._input.substring(this._cursor),
            value = null;

        //if it's a string, just do a straight match
        if (typeof matcher == "string"){
            if (source.indexOf(matcher) === 0){
                value = this.readCount(matcher.length);
            }
        } else if (matcher instanceof RegExp){
            if (matcher.test(source)){
                value = this.readCount(RegExp.lastMatch.length);
            }
        }

        return value;
    },


    /**
     * Reads a given number of characters. If the end of the input is reached,
     * it reads only the remaining characters and does not throw an error.
     * @param {int} count The number of characters to read.
     * @return {String} The string made up the read characters.
     * @method readCount
     */
    readCount: function(count){
        var buffer = "";

        while(count--){
            buffer += this.read();
        }

        return buffer;
    }

};
/**
 * Type to use when a syntax error occurs.
 * @class SyntaxError
 * @namespace parserlib.util
 * @constructor
 * @param {String} message The error message.
 * @param {int} line The line at which the error occurred.
 * @param {int} col The column at which the error occurred.
 */
function SyntaxError(message, line, col){

    /**
     * The column at which the error occurred.
     * @type int
     * @property col
     */
    this.col = col;

    /**
     * The line at which the error occurred.
     * @type int
     * @property line
     */
    this.line = line;

    /**
     * The text representation of the unit.
     * @type String
     * @property text
     */
    this.message = message;

}

//inherit from Error
SyntaxError.prototype = new Error();
/**
 * Base type to represent a single syntactic unit.
 * @class SyntaxUnit
 * @namespace parserlib.util
 * @constructor
 * @param {String} text The text of the unit.
 * @param {int} line The line of text on which the unit resides.
 * @param {int} col The column of text on which the unit resides.
 */
function SyntaxUnit(text, line, col, type){


    /**
     * The column of text on which the unit resides.
     * @type int
     * @property col
     */
    this.col = col;

    /**
     * The line of text on which the unit resides.
     * @type int
     * @property line
     */
    this.line = line;

    /**
     * The text representation of the unit.
     * @type String
     * @property text
     */
    this.text = text;

    /**
     * The type of syntax unit.
     * @type int
     * @property type
     */
    this.type = type;
}

/**
 * Create a new syntax unit based solely on the given token.
 * Convenience method for creating a new syntax unit when
 * it represents a single token instead of multiple.
 * @param {Object} token The token object to represent.
 * @return {parserlib.util.SyntaxUnit} The object representing the token.
 * @static
 * @method fromToken
 */
SyntaxUnit.fromToken = function(token){
    return new SyntaxUnit(token.value, token.startLine, token.startCol);
};

SyntaxUnit.prototype = {

    //restore constructor
    constructor: SyntaxUnit,
    
    /**
     * Returns the text representation of the unit.
     * @return {String} The text representation of the unit.
     * @method valueOf
     */
    valueOf: function(){
        return this.toString();
    },
    
    /**
     * Returns the text representation of the unit.
     * @return {String} The text representation of the unit.
     * @method toString
     */
    toString: function(){
        return this.text;
    }

};
/**
 * Generic TokenStream providing base functionality.
 * @class TokenStreamBase
 * @namespace parserlib.util
 * @constructor
 * @param {String|StringReader} input The text to tokenize or a reader from 
 *      which to read the input.
 */
function TokenStreamBase(input, tokenData){

    /**
     * The string reader for easy access to the text.
     * @type StringReader
     * @property _reader
     * @private
     */
    //this._reader = (typeof input == "string") ? new StringReader(input) : input;
    this._reader = input ? new StringReader(input.toString()) : null;
    
    /**
     * Token object for the last consumed token.
     * @type Token
     * @property _token
     * @private
     */
    this._token = null;    
    
    /**
     * The array of token information.
     * @type Array
     * @property _tokenData
     * @private
     */
    this._tokenData = tokenData;
    
    /**
     * Lookahead token buffer.
     * @type Array
     * @property _lt
     * @private
     */
    this._lt = [];
    
    /**
     * Lookahead token buffer index.
     * @type int
     * @property _ltIndex
     * @private
     */
    this._ltIndex = 0;
    
    this._ltIndexCache = [];
}

/**
 * Accepts an array of token information and outputs
 * an array of token data containing key-value mappings
 * and matching functions that the TokenStream needs.
 * @param {Array} tokens An array of token descriptors.
 * @return {Array} An array of processed token data.
 * @method createTokenData
 * @static
 */
TokenStreamBase.createTokenData = function(tokens){

    var nameMap     = [],
        typeMap     = {},
        tokenData     = tokens.concat([]),
        i            = 0,
        len            = tokenData.length+1;
    
    tokenData.UNKNOWN = -1;
    tokenData.unshift({name:"EOF"});

    for (; i < len; i++){
        nameMap.push(tokenData[i].name);
        tokenData[tokenData[i].name] = i;
        if (tokenData[i].text){
            typeMap[tokenData[i].text] = i;
        }
    }
    
    tokenData.name = function(tt){
        return nameMap[tt];
    };
    
    tokenData.type = function(c){
        return typeMap[c];
    };
    
    return tokenData;
};

TokenStreamBase.prototype = {

    //restore constructor
    constructor: TokenStreamBase,    
    
    //-------------------------------------------------------------------------
    // Matching methods
    //-------------------------------------------------------------------------
    
    /**
     * Determines if the next token matches the given token type.
     * If so, that token is consumed; if not, the token is placed
     * back onto the token stream. You can pass in any number of
     * token types and this will return true if any of the token
     * types is found.
     * @param {int|int[]} tokenTypes Either a single token type or an array of
     *      token types that the next token might be. If an array is passed,
     *      it's assumed that the token can be any of these.
     * @param {variant} channel (Optional) The channel to read from. If not
     *      provided, reads from the default (unnamed) channel.
     * @return {Boolean} True if the token type matches, false if not.
     * @method match
     */
    match: function(tokenTypes, channel){
    
        //always convert to an array, makes things easier
        if (!(tokenTypes instanceof Array)){
            tokenTypes = [tokenTypes];
        }
                
        var tt  = this.get(channel),
            i   = 0,
            len = tokenTypes.length;
            
        while(i < len){
            if (tt == tokenTypes[i++]){
                return true;
            }
        }
        
        //no match found, put the token back
        this.unget();
        return false;
    },    
    
    /**
     * Determines if the next token matches the given token type.
     * If so, that token is consumed; if not, an error is thrown.
     * @param {int|int[]} tokenTypes Either a single token type or an array of
     *      token types that the next token should be. If an array is passed,
     *      it's assumed that the token must be one of these.
     * @param {variant} channel (Optional) The channel to read from. If not
     *      provided, reads from the default (unnamed) channel.
     * @return {void}
     * @method mustMatch
     */    
    mustMatch: function(tokenTypes, channel){

        var token;

        //always convert to an array, makes things easier
        if (!(tokenTypes instanceof Array)){
            tokenTypes = [tokenTypes];
        }

        if (!this.match.apply(this, arguments)){    
            token = this.LT(1);
            throw new SyntaxError("Expected " + this._tokenData[tokenTypes[0]].name + 
                " at line " + token.startLine + ", col " + token.startCol + ".", token.startLine, token.startCol);
        }
    },
    
    //-------------------------------------------------------------------------
    // Consuming methods
    //-------------------------------------------------------------------------
    
    /**
     * Keeps reading from the token stream until either one of the specified
     * token types is found or until the end of the input is reached.
     * @param {int|int[]} tokenTypes Either a single token type or an array of
     *      token types that the next token should be. If an array is passed,
     *      it's assumed that the token must be one of these.
     * @param {variant} channel (Optional) The channel to read from. If not
     *      provided, reads from the default (unnamed) channel.
     * @return {void}
     * @method advance
     */
    advance: function(tokenTypes, channel){
        
        while(this.LA(0) != 0 && !this.match(tokenTypes, channel)){
            this.get();
        }

        return this.LA(0);    
    },
    
    /**
     * Consumes the next token from the token stream. 
     * @return {int} The token type of the token that was just consumed.
     * @method get
     */      
    get: function(channel){
    
        var tokenInfo   = this._tokenData,
            reader      = this._reader,
            value,
            i           =0,
            len         = tokenInfo.length,
            found       = false,
            token,
            info;
            
        //check the lookahead buffer first
        if (this._lt.length && this._ltIndex >= 0 && this._ltIndex < this._lt.length){  
                           
            i++;
            this._token = this._lt[this._ltIndex++];
            info = tokenInfo[this._token.type];
            
            //obey channels logic
            while((info.channel !== undefined && channel !== info.channel) &&
                    this._ltIndex < this._lt.length){
                this._token = this._lt[this._ltIndex++];
                info = tokenInfo[this._token.type];
                i++;
            }
            
            //here be dragons
            if ((info.channel === undefined || channel === info.channel) &&
                    this._ltIndex <= this._lt.length){
                this._ltIndexCache.push(i);
                return this._token.type;
            }
        }
        
        //call token retriever method
        token = this._getToken();

        //if it should be hidden, don't save a token
        if (token.type > -1 && !tokenInfo[token.type].hide){
                     
            //apply token channel
            token.channel = tokenInfo[token.type].channel;
         
            //save for later
            this._token = token;
            this._lt.push(token);

            //save space that will be moved (must be done before array is truncated)
            this._ltIndexCache.push(this._lt.length - this._ltIndex + i);  
        
            //keep the buffer under 5 items
            if (this._lt.length > 5){
                this._lt.shift();                
            }
            
            //also keep the shift buffer under 5 items
            if (this._ltIndexCache.length > 5){
                this._ltIndexCache.shift();
            }
                
            //update lookahead index
            this._ltIndex = this._lt.length;
        }
            
        /*
         * Skip to the next token if:
         * 1. The token type is marked as hidden.
         * 2. The token type has a channel specified and it isn't the current channel.
         */
        info = tokenInfo[token.type];
        if (info && 
                (info.hide || 
                (info.channel !== undefined && channel !== info.channel))){
            return this.get(channel);
        } else {
            //return just the type
            return token.type;
        }
    },
    
    /**
     * Looks ahead a certain number of tokens and returns the token type at
     * that position. This will throw an error if you lookahead past the
     * end of input, past the size of the lookahead buffer, or back past
     * the first token in the lookahead buffer.
     * @param {int} The index of the token type to retrieve. 0 for the
     *      current token, 1 for the next, -1 for the previous, etc.
     * @return {int} The token type of the token in the given position.
     * @method LA
     */
    LA: function(index){
        var total = index,
            tt;
        if (index > 0){
            //TODO: Store 5 somewhere
            if (index > 5){
                throw new Error("Too much lookahead.");
            }
        
            //get all those tokens
            while(total){
                tt = this.get();   
                total--;                            
            }
            
            //unget all those tokens
            while(total < index){
                this.unget();
                total++;
            }
        } else if (index < 0){
        
            if(this._lt[this._ltIndex+index]){
                tt = this._lt[this._ltIndex+index].type;
            } else {
                throw new Error("Too much lookbehind.");
            }
        
        } else {
            tt = this._token.type;
        }
        
        return tt;
    
    },
    
    /**
     * Looks ahead a certain number of tokens and returns the token at
     * that position. This will throw an error if you lookahead past the
     * end of input, past the size of the lookahead buffer, or back past
     * the first token in the lookahead buffer.
     * @param {int} The index of the token type to retrieve. 0 for the
     *      current token, 1 for the next, -1 for the previous, etc.
     * @return {Object} The token of the token in the given position.
     * @method LA
     */    
    LT: function(index){
    
        //lookahead first to prime the token buffer
        this.LA(index);
        
        //now find the token, subtract one because _ltIndex is already at the next index
        return this._lt[this._ltIndex+index-1];    
    },
    
    /**
     * Returns the token type for the next token in the stream without 
     * consuming it.
     * @return {int} The token type of the next token in the stream.
     * @method peek
     */
    peek: function(){
        return this.LA(1);
    },
    
    /**
     * Returns the actual token object for the last consumed token.
     * @return {Token} The token object for the last consumed token.
     * @method token
     */
    token: function(){
        return this._token;
    },
    
    /**
     * Returns the name of the token for the given token type.
     * @param {int} tokenType The type of token to get the name of.
     * @return {String} The name of the token or "UNKNOWN_TOKEN" for any
     *      invalid token type.
     * @method tokenName
     */
    tokenName: function(tokenType){
        if (tokenType < 0 || tokenType > this._tokenData.length){
            return "UNKNOWN_TOKEN";
        } else {
            return this._tokenData[tokenType].name;
        }
    },
    
    /**
     * Returns the token type value for the given token name.
     * @param {String} tokenName The name of the token whose value should be returned.
     * @return {int} The token type value for the given token name or -1
     *      for an unknown token.
     * @method tokenName
     */    
    tokenType: function(tokenName){
        return this._tokenData[tokenName] || -1;
    },
    
    /**
     * Returns the last consumed token to the token stream.
     * @method unget
     */      
    unget: function(){
        //if (this._ltIndex > -1){
        if (this._ltIndexCache.length){
            this._ltIndex -= this._ltIndexCache.pop();//--;
            this._token = this._lt[this._ltIndex - 1];
        } else {
            throw new Error("Too much lookahead.");
        }
    }

};


parserlib.util = {
StringReader: StringReader,
SyntaxError : SyntaxError,
SyntaxUnit  : SyntaxUnit,
EventTarget : EventTarget,
TokenStreamBase : TokenStreamBase
};
})();
/* 
Parser-Lib
Copyright (c) 2009-2011 Nicholas C. Zakas. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/
/* Build time: 12-January-2012 01:05:23 */
(function(){
var EventTarget = parserlib.util.EventTarget,
TokenStreamBase = parserlib.util.TokenStreamBase,
StringReader = parserlib.util.StringReader,
SyntaxError = parserlib.util.SyntaxError,
SyntaxUnit  = parserlib.util.SyntaxUnit;

var Colors = {
    aliceblue       :"#f0f8ff",
    antiquewhite    :"#faebd7",
    aqua            :"#00ffff",
    aquamarine      :"#7fffd4",
    azure           :"#f0ffff",
    beige           :"#f5f5dc",
    bisque          :"#ffe4c4",
    black           :"#000000",
    blanchedalmond  :"#ffebcd",
    blue            :"#0000ff",
    blueviolet      :"#8a2be2",
    brown           :"#a52a2a",
    burlywood       :"#deb887",
    cadetblue       :"#5f9ea0",
    chartreuse      :"#7fff00",
    chocolate       :"#d2691e",
    coral           :"#ff7f50",
    cornflowerblue  :"#6495ed",
    cornsilk        :"#fff8dc",
    crimson         :"#dc143c",
    cyan            :"#00ffff",
    darkblue        :"#00008b",
    darkcyan        :"#008b8b",
    darkgoldenrod   :"#b8860b",
    darkgray        :"#a9a9a9",
    darkgreen       :"#006400",
    darkkhaki       :"#bdb76b",
    darkmagenta     :"#8b008b",
    darkolivegreen  :"#556b2f",
    darkorange      :"#ff8c00",
    darkorchid      :"#9932cc",
    darkred         :"#8b0000",
    darksalmon      :"#e9967a",
    darkseagreen    :"#8fbc8f",
    darkslateblue   :"#483d8b",
    darkslategray   :"#2f4f4f",
    darkturquoise   :"#00ced1",
    darkviolet      :"#9400d3",
    deeppink        :"#ff1493",
    deepskyblue     :"#00bfff",
    dimgray         :"#696969",
    dodgerblue      :"#1e90ff",
    firebrick       :"#b22222",
    floralwhite     :"#fffaf0",
    forestgreen     :"#228b22",
    fuchsia         :"#ff00ff",
    gainsboro       :"#dcdcdc",
    ghostwhite      :"#f8f8ff",
    gold            :"#ffd700",
    goldenrod       :"#daa520",
    gray            :"#808080",
    green           :"#008000",
    greenyellow     :"#adff2f",
    honeydew        :"#f0fff0",
    hotpink         :"#ff69b4",
    indianred       :"#cd5c5c",
    indigo          :"#4b0082",
    ivory           :"#fffff0",
    khaki           :"#f0e68c",
    lavender        :"#e6e6fa",
    lavenderblush   :"#fff0f5",
    lawngreen       :"#7cfc00",
    lemonchiffon    :"#fffacd",
    lightblue       :"#add8e6",
    lightcoral      :"#f08080",
    lightcyan       :"#e0ffff",
    lightgoldenrodyellow  :"#fafad2",
    lightgrey       :"#d3d3d3",
    lightgreen      :"#90ee90",
    lightpink       :"#ffb6c1",
    lightsalmon     :"#ffa07a",
    lightseagreen   :"#20b2aa",
    lightskyblue    :"#87cefa",
    lightslategray  :"#778899",
    lightsteelblue  :"#b0c4de",
    lightyellow     :"#ffffe0",
    lime            :"#00ff00",
    limegreen       :"#32cd32",
    linen           :"#faf0e6",
    magenta         :"#ff00ff",
    maroon          :"#800000",
    mediumaquamarine:"#66cdaa",
    mediumblue      :"#0000cd",
    mediumorchid    :"#ba55d3",
    mediumpurple    :"#9370d8",
    mediumseagreen  :"#3cb371",
    mediumslateblue :"#7b68ee",
    mediumspringgreen   :"#00fa9a",
    mediumturquoise :"#48d1cc",
    mediumvioletred :"#c71585",
    midnightblue    :"#191970",
    mintcream       :"#f5fffa",
    mistyrose       :"#ffe4e1",
    moccasin        :"#ffe4b5",
    navajowhite     :"#ffdead",
    navy            :"#000080",
    oldlace         :"#fdf5e6",
    olive           :"#808000",
    olivedrab       :"#6b8e23",
    orange          :"#ffa500",
    orangered       :"#ff4500",
    orchid          :"#da70d6",
    palegoldenrod   :"#eee8aa",
    palegreen       :"#98fb98",
    paleturquoise   :"#afeeee",
    palevioletred   :"#d87093",
    papayawhip      :"#ffefd5",
    peachpuff       :"#ffdab9",
    peru            :"#cd853f",
    pink            :"#ffc0cb",
    plum            :"#dda0dd",
    powderblue      :"#b0e0e6",
    purple          :"#800080",
    red             :"#ff0000",
    rosybrown       :"#bc8f8f",
    royalblue       :"#4169e1",
    saddlebrown     :"#8b4513",
    salmon          :"#fa8072",
    sandybrown      :"#f4a460",
    seagreen        :"#2e8b57",
    seashell        :"#fff5ee",
    sienna          :"#a0522d",
    silver          :"#c0c0c0",
    skyblue         :"#87ceeb",
    slateblue       :"#6a5acd",
    slategray       :"#708090",
    snow            :"#fffafa",
    springgreen     :"#00ff7f",
    steelblue       :"#4682b4",
    tan             :"#d2b48c",
    teal            :"#008080",
    thistle         :"#d8bfd8",
    tomato          :"#ff6347",
    turquoise       :"#40e0d0",
    violet          :"#ee82ee",
    wheat           :"#f5deb3",
    white           :"#ffffff",
    whitesmoke      :"#f5f5f5",
    yellow          :"#ffff00",
    yellowgreen     :"#9acd32"
};
/**
 * Represents a selector combinator (whitespace, +, >).
 * @namespace parserlib.css
 * @class Combinator
 * @extends parserlib.util.SyntaxUnit
 * @constructor
 * @param {String} text The text representation of the unit. 
 * @param {int} line The line of text on which the unit resides.
 * @param {int} col The column of text on which the unit resides.
 */
function Combinator(text, line, col){
    
    SyntaxUnit.call(this, text, line, col, Parser.COMBINATOR_TYPE);

    /**
     * The type of modifier.
     * @type String
     * @property type
     */
    this.type = "unknown";
    
    //pretty simple
    if (/^\s+$/.test(text)){
        this.type = "descendant";
    } else if (text == ">"){
        this.type = "child";
    } else if (text == "+"){
        this.type = "adjacent-sibling";
    } else if (text == "~"){
        this.type = "sibling";
    }

}

Combinator.prototype = new SyntaxUnit();
Combinator.prototype.constructor = Combinator;

/**
 * Represents a media feature, such as max-width:500.
 * @namespace parserlib.css
 * @class MediaFeature
 * @extends parserlib.util.SyntaxUnit
 * @constructor
 * @param {SyntaxUnit} name The name of the feature.
 * @param {SyntaxUnit} value The value of the feature or null if none.
 */
function MediaFeature(name, value){
    
    SyntaxUnit.call(this, "(" + name + (value !== null ? ":" + value : "") + ")", name.startLine, name.startCol, Parser.MEDIA_FEATURE_TYPE);

    /**
     * The name of the media feature
     * @type String
     * @property name
     */
    this.name = name;

    /**
     * The value for the feature or null if there is none.
     * @type SyntaxUnit
     * @property value
     */
    this.value = value;
}

MediaFeature.prototype = new SyntaxUnit();
MediaFeature.prototype.constructor = MediaFeature;

/**
 * Represents an individual media query.
 * @namespace parserlib.css
 * @class MediaQuery
 * @extends parserlib.util.SyntaxUnit
 * @constructor
 * @param {String} modifier The modifier "not" or "only" (or null).
 * @param {String} mediaType The type of media (i.e., "print").
 * @param {Array} parts Array of selectors parts making up this selector.
 * @param {int} line The line of text on which the unit resides.
 * @param {int} col The column of text on which the unit resides.
 */
function MediaQuery(modifier, mediaType, features, line, col){
    
    SyntaxUnit.call(this, (modifier ? modifier + " ": "") + (mediaType ? mediaType + " " : "") + features.join(" and "), line, col, Parser.MEDIA_QUERY_TYPE);

    /**
     * The media modifier ("not" or "only")
     * @type String
     * @property modifier
     */
    this.modifier = modifier;

    /**
     * The mediaType (i.e., "print")
     * @type String
     * @property mediaType
     */
    this.mediaType = mediaType;    
    
    /**
     * The parts that make up the selector.
     * @type Array
     * @property features
     */
    this.features = features;

}

MediaQuery.prototype = new SyntaxUnit();
MediaQuery.prototype.constructor = MediaQuery;

/**
 * A CSS3 parser.
 * @namespace parserlib.css
 * @class Parser
 * @constructor
 * @param {Object} options (Optional) Various options for the parser:
 *      starHack (true|false) to allow IE6 star hack as valid,
 *      underscoreHack (true|false) to interpret leading underscores
 *      as IE6-7 targeting for known properties, ieFilters (true|false)
 *      to indicate that IE < 8 filters should be accepted and not throw
 *      syntax errors.
 */
function Parser(options){

    //inherit event functionality
    EventTarget.call(this);


    this.options = options || {};

    this._tokenStream = null;
}

//Static constants
Parser.DEFAULT_TYPE = 0;
Parser.COMBINATOR_TYPE = 1;
Parser.MEDIA_FEATURE_TYPE = 2;
Parser.MEDIA_QUERY_TYPE = 3;
Parser.PROPERTY_NAME_TYPE = 4;
Parser.PROPERTY_VALUE_TYPE = 5;
Parser.PROPERTY_VALUE_PART_TYPE = 6;
Parser.SELECTOR_TYPE = 7;
Parser.SELECTOR_PART_TYPE = 8;
Parser.SELECTOR_SUB_PART_TYPE = 9;

Parser.prototype = function(){

    var proto = new EventTarget(),  //new prototype
        prop,
        additions =  {
        
            //restore constructor
            constructor: Parser,
                        
            //instance constants - yuck
            DEFAULT_TYPE : 0,
            COMBINATOR_TYPE : 1,
            MEDIA_FEATURE_TYPE : 2,
            MEDIA_QUERY_TYPE : 3,
            PROPERTY_NAME_TYPE : 4,
            PROPERTY_VALUE_TYPE : 5,
            PROPERTY_VALUE_PART_TYPE : 6,
            SELECTOR_TYPE : 7,
            SELECTOR_PART_TYPE : 8,
            SELECTOR_SUB_PART_TYPE : 9,            
        
            //-----------------------------------------------------------------
            // Grammar
            //-----------------------------------------------------------------
        
            _stylesheet: function(){
            
                /*
                 * stylesheet
                 *  : [ CHARSET_SYM S* STRING S* ';' ]?
                 *    [S|CDO|CDC]* [ import [S|CDO|CDC]* ]*
                 *    [ namespace [S|CDO|CDC]* ]*
                 *    [ [ ruleset | media | page | font_face | keyframes ] [S|CDO|CDC]* ]*
                 *  ;
                 */ 
               
                var tokenStream = this._tokenStream,
                    charset     = null,
                    token,
                    tt;
                    
                this.fire("startstylesheet");
            
                //try to read character set
                this._charset();
                
                this._skipCruft();

                //try to read imports - may be more than one
                while (tokenStream.peek() == Tokens.IMPORT_SYM){
                    this._import();
                    this._skipCruft();
                }
                
                //try to read namespaces - may be more than one
                while (tokenStream.peek() == Tokens.NAMESPACE_SYM){
                    this._namespace();
                    this._skipCruft();
                }
                
                //get the next token
                tt = tokenStream.peek();
                
                //try to read the rest
                while(tt > Tokens.EOF){
                
                    try {
                
                        switch(tt){
                            case Tokens.MEDIA_SYM:
                                this._media();
                                this._skipCruft();
                                break;
                            case Tokens.PAGE_SYM:
                                this._page(); 
                                this._skipCruft();
                                break;                   
                            case Tokens.FONT_FACE_SYM:
                                this._font_face(); 
                                this._skipCruft();
                                break;  
                            case Tokens.KEYFRAMES_SYM:
                                this._keyframes(); 
                                this._skipCruft();
                                break;  
                            case Tokens.S:
                                this._readWhitespace();
                                break;
                            default:                            
                                if(!this._ruleset()){
                                
                                    //error handling for known issues
                                    switch(tt){
                                        case Tokens.CHARSET_SYM:
                                            token = tokenStream.LT(1);
                                            this._charset(false);
                                            throw new SyntaxError("@charset not allowed here.", token.startLine, token.startCol);
                                        case Tokens.IMPORT_SYM:
                                            token = tokenStream.LT(1);
                                            this._import(false);
                                            throw new SyntaxError("@import not allowed here.", token.startLine, token.startCol);
                                        case Tokens.NAMESPACE_SYM:
                                            token = tokenStream.LT(1);
                                            this._namespace(false);
                                            throw new SyntaxError("@namespace not allowed here.", token.startLine, token.startCol);
                                        default:
                                            tokenStream.get();  //get the last token
                                            this._unexpectedToken(tokenStream.token());
                                    }
                                
                                }
                        }
                    } catch(ex) {
                        if (ex instanceof SyntaxError && !this.options.strict){
                            this.fire({
                                type:       "error",
                                error:      ex,
                                message:    ex.message,
                                line:       ex.line,
                                col:        ex.col
                            });                     
                        } else {
                            throw ex;
                        }
                    }
                    
                    tt = tokenStream.peek();
                }
                
                if (tt != Tokens.EOF){
                    this._unexpectedToken(tokenStream.token());
                }
            
                this.fire("endstylesheet");
            },
            
            _charset: function(emit){
                var tokenStream = this._tokenStream,
                    charset,
                    token,
                    line,
                    col;
                    
                if (tokenStream.match(Tokens.CHARSET_SYM)){
                    line = tokenStream.token().startLine;
                    col = tokenStream.token().startCol;
                
                    this._readWhitespace();
                    tokenStream.mustMatch(Tokens.STRING);
                    
                    token = tokenStream.token();
                    charset = token.value;
                    
                    this._readWhitespace();
                    tokenStream.mustMatch(Tokens.SEMICOLON);
                    
                    if (emit !== false){
                        this.fire({ 
                            type:   "charset",
                            charset:charset,
                            line:   line,
                            col:    col
                        });
                    }
                }            
            },
            
            _import: function(emit){
                /*
                 * import
                 *   : IMPORT_SYM S*
                 *    [STRING|URI] S* media_query_list? ';' S*
                 */    
            
                var tokenStream = this._tokenStream,
                    tt,
                    uri,
                    importToken,
                    mediaList   = [];
                
                //read import symbol
                tokenStream.mustMatch(Tokens.IMPORT_SYM);
                importToken = tokenStream.token();
                this._readWhitespace();
                
                tokenStream.mustMatch([Tokens.STRING, Tokens.URI]);
                
                //grab the URI value
                uri = tokenStream.token().value.replace(/(?:url\()?["']([^"']+)["']\)?/, "$1");                

                this._readWhitespace();
                
                mediaList = this._media_query_list();
                
                //must end with a semicolon
                tokenStream.mustMatch(Tokens.SEMICOLON);
                this._readWhitespace();
                
                if (emit !== false){
                    this.fire({
                        type:   "import",
                        uri:    uri,
                        media:  mediaList,
                        line:   importToken.startLine,
                        col:    importToken.startCol
                    });
                }
        
            },
            
            _namespace: function(emit){
                /*
                 * namespace
                 *   : NAMESPACE_SYM S* [namespace_prefix S*]? [STRING|URI] S* ';' S*
                 */    
            
                var tokenStream = this._tokenStream,
                    line,
                    col,
                    prefix,
                    uri;
                
                //read import symbol
                tokenStream.mustMatch(Tokens.NAMESPACE_SYM);
                line = tokenStream.token().startLine;
                col = tokenStream.token().startCol;
                this._readWhitespace();
                
                //it's a namespace prefix - no _namespace_prefix() method because it's just an IDENT
                if (tokenStream.match(Tokens.IDENT)){
                    prefix = tokenStream.token().value;
                    this._readWhitespace();
                }
                
                tokenStream.mustMatch([Tokens.STRING, Tokens.URI]);
                /*if (!tokenStream.match(Tokens.STRING)){
                    tokenStream.mustMatch(Tokens.URI);
                }*/
                
                //grab the URI value
                uri = tokenStream.token().value.replace(/(?:url\()?["']([^"']+)["']\)?/, "$1");                

                this._readWhitespace();

                //must end with a semicolon
                tokenStream.mustMatch(Tokens.SEMICOLON);
                this._readWhitespace();
                
                if (emit !== false){
                    this.fire({
                        type:   "namespace",
                        prefix: prefix,
                        uri:    uri,
                        line:   line,
                        col:    col
                    });
                }
        
            },            
                       
            _media: function(){
                /*
                 * media
                 *   : MEDIA_SYM S* media_query_list S* '{' S* ruleset* '}' S*
                 *   ;
                 */
                var tokenStream     = this._tokenStream,
                    line,
                    col,
                    mediaList;//       = [];
                
                //look for @media
                tokenStream.mustMatch(Tokens.MEDIA_SYM);
                line = tokenStream.token().startLine;
                col = tokenStream.token().startCol;
                
                this._readWhitespace();               

                mediaList = this._media_query_list();

                tokenStream.mustMatch(Tokens.LBRACE);
                this._readWhitespace();
                
                this.fire({
                    type:   "startmedia",
                    media:  mediaList,
                    line:   line,
                    col:    col
                });
                
                while(true) {
                    if (tokenStream.peek() == Tokens.PAGE_SYM){
                        this._page();
                    } else if (!this._ruleset()){
                        break;
                    }                
                }
                
                tokenStream.mustMatch(Tokens.RBRACE);
                this._readWhitespace();
        
                this.fire({
                    type:   "endmedia",
                    media:  mediaList,
                    line:   line,
                    col:    col
                });
            },                           
        

            //CSS3 Media Queries
            _media_query_list: function(){
                /*
                 * media_query_list
                 *   : S* [media_query [ ',' S* media_query ]* ]?
                 *   ;
                 */
                var tokenStream = this._tokenStream,
                    mediaList   = [];
                
                
                this._readWhitespace();
                
                if (tokenStream.peek() == Tokens.IDENT || tokenStream.peek() == Tokens.LPAREN){
                    mediaList.push(this._media_query());
                }
                
                while(tokenStream.match(Tokens.COMMA)){
                    this._readWhitespace();
                    mediaList.push(this._media_query());
                }
                
                return mediaList;
            },
            
            /*
             * Note: "expression" in the grammar maps to the _media_expression
             * method.
             
             */
            _media_query: function(){
                /*
                 * media_query
                 *   : [ONLY | NOT]? S* media_type S* [ AND S* expression ]*
                 *   | expression [ AND S* expression ]*
                 *   ;
                 */
                var tokenStream = this._tokenStream,
                    type        = null,
                    ident       = null,
                    token       = null,
                    expressions = [];
                    
                if (tokenStream.match(Tokens.IDENT)){
                    ident = tokenStream.token().value.toLowerCase();
                    
                    //since there's no custom tokens for these, need to manually check
                    if (ident != "only" && ident != "not"){
                        tokenStream.unget();
                        ident = null;
                    } else {
                        token = tokenStream.token();
                    }
                }
                                
                this._readWhitespace();
                
                if (tokenStream.peek() == Tokens.IDENT){
                    type = this._media_type();
                    if (token === null){
                        token = tokenStream.token();
                    }
                } else if (tokenStream.peek() == Tokens.LPAREN){
                    if (token === null){
                        token = tokenStream.LT(1);
                    }
                    expressions.push(this._media_expression());
                }                               
                
                if (type === null && expressions.length === 0){
                    return null;
                } else {                
                    this._readWhitespace();
                    while (tokenStream.match(Tokens.IDENT)){
                        if (tokenStream.token().value.toLowerCase() != "and"){
                            this._unexpectedToken(tokenStream.token());
                        }
                        
                        this._readWhitespace();
                        expressions.push(this._media_expression());
                    }
                }

                return new MediaQuery(ident, type, expressions, token.startLine, token.startCol);
            },

            //CSS3 Media Queries
            _media_type: function(){
                /*
                 * media_type
                 *   : IDENT
                 *   ;
                 */
                return this._media_feature();           
            },

            /**
             * Note: in CSS3 Media Queries, this is called "expression".
             * Renamed here to avoid conflict with CSS3 Selectors
             * definition of "expression". Also note that "expr" in the
             * grammar now maps to "expression" from CSS3 selectors.
             * @method _media_expression
             * @private
             */
            _media_expression: function(){
                /*
                 * expression
                 *  : '(' S* media_feature S* [ ':' S* expr ]? ')' S*
                 *  ;
                 */
                var tokenStream = this._tokenStream,
                    feature     = null,
                    token,
                    expression  = null;
                
                tokenStream.mustMatch(Tokens.LPAREN);
                
                feature = this._media_feature();
                this._readWhitespace();
                
                if (tokenStream.match(Tokens.COLON)){
                    this._readWhitespace();
                    token = tokenStream.LT(1);
                    expression = this._expression();
                }
                
                tokenStream.mustMatch(Tokens.RPAREN);
                this._readWhitespace();

                return new MediaFeature(feature, (expression ? new SyntaxUnit(expression, token.startLine, token.startCol) : null));            
            },

            //CSS3 Media Queries
            _media_feature: function(){
                /*
                 * media_feature
                 *   : IDENT
                 *   ;
                 */
                var tokenStream = this._tokenStream;
                    
                tokenStream.mustMatch(Tokens.IDENT);
                
                return SyntaxUnit.fromToken(tokenStream.token());            
            },
            
            //CSS3 Paged Media
            _page: function(){
                /*
                 * page:
                 *    PAGE_SYM S* IDENT? pseudo_page? S* 
                 *    '{' S* [ declaration | margin ]? [ ';' S* [ declaration | margin ]? ]* '}' S*
                 *    ;
                 */            
                var tokenStream = this._tokenStream,
                    line,
                    col,
                    identifier  = null,
                    pseudoPage  = null;
                
                //look for @page
                tokenStream.mustMatch(Tokens.PAGE_SYM);
                line = tokenStream.token().startLine;
                col = tokenStream.token().startCol;
                
                this._readWhitespace();
                
                if (tokenStream.match(Tokens.IDENT)){
                    identifier = tokenStream.token().value;

                    //The value 'auto' may not be used as a page name and MUST be treated as a syntax error.
                    if (identifier.toLowerCase() === "auto"){
                        this._unexpectedToken(tokenStream.token());
                    }
                }                
                
                //see if there's a colon upcoming
                if (tokenStream.peek() == Tokens.COLON){
                    pseudoPage = this._pseudo_page();
                }
            
                this._readWhitespace();
                
                this.fire({
                    type:   "startpage",
                    id:     identifier,
                    pseudo: pseudoPage,
                    line:   line,
                    col:    col
                });                   

                this._readDeclarations(true, true);                
                
                this.fire({
                    type:   "endpage",
                    id:     identifier,
                    pseudo: pseudoPage,
                    line:   line,
                    col:    col
                });             
            
            },
            
            //CSS3 Paged Media
            _margin: function(){
                /*
                 * margin :
                 *    margin_sym S* '{' declaration [ ';' S* declaration? ]* '}' S*
                 *    ;
                 */
                var tokenStream = this._tokenStream,
                    line,
                    col,
                    marginSym   = this._margin_sym();

                if (marginSym){
                    line = tokenStream.token().startLine;
                    col = tokenStream.token().startCol;
                
                    this.fire({
                        type: "startpagemargin",
                        margin: marginSym,
                        line:   line,
                        col:    col
                    });    
                    
                    this._readDeclarations(true);

                    this.fire({
                        type: "endpagemargin",
                        margin: marginSym,
                        line:   line,
                        col:    col
                    });    
                    return true;
                } else {
                    return false;
                }
            },

            //CSS3 Paged Media
            _margin_sym: function(){
            
                /*
                 * margin_sym :
                 *    TOPLEFTCORNER_SYM | 
                 *    TOPLEFT_SYM | 
                 *    TOPCENTER_SYM | 
                 *    TOPRIGHT_SYM | 
                 *    TOPRIGHTCORNER_SYM |
                 *    BOTTOMLEFTCORNER_SYM | 
                 *    BOTTOMLEFT_SYM | 
                 *    BOTTOMCENTER_SYM | 
                 *    BOTTOMRIGHT_SYM |
                 *    BOTTOMRIGHTCORNER_SYM |
                 *    LEFTTOP_SYM |
                 *    LEFTMIDDLE_SYM |
                 *    LEFTBOTTOM_SYM |
                 *    RIGHTTOP_SYM |
                 *    RIGHTMIDDLE_SYM |
                 *    RIGHTBOTTOM_SYM 
                 *    ;
                 */
            
                var tokenStream = this._tokenStream;
            
                if(tokenStream.match([Tokens.TOPLEFTCORNER_SYM, Tokens.TOPLEFT_SYM,
                        Tokens.TOPCENTER_SYM, Tokens.TOPRIGHT_SYM, Tokens.TOPRIGHTCORNER_SYM,
                        Tokens.BOTTOMLEFTCORNER_SYM, Tokens.BOTTOMLEFT_SYM, 
                        Tokens.BOTTOMCENTER_SYM, Tokens.BOTTOMRIGHT_SYM,
                        Tokens.BOTTOMRIGHTCORNER_SYM, Tokens.LEFTTOP_SYM, 
                        Tokens.LEFTMIDDLE_SYM, Tokens.LEFTBOTTOM_SYM, Tokens.RIGHTTOP_SYM,
                        Tokens.RIGHTMIDDLE_SYM, Tokens.RIGHTBOTTOM_SYM]))
                {
                    return SyntaxUnit.fromToken(tokenStream.token());                
                } else {
                    return null;
                }
            
            },
            
            _pseudo_page: function(){
                /*
                 * pseudo_page
                 *   : ':' IDENT
                 *   ;    
                 */
        
                var tokenStream = this._tokenStream;
                
                tokenStream.mustMatch(Tokens.COLON);
                tokenStream.mustMatch(Tokens.IDENT);
                
                //TODO: CSS3 Paged Media says only "left", "center", and "right" are allowed
                
                return tokenStream.token().value;
            },
            
            _font_face: function(){
                /*
                 * font_face
                 *   : FONT_FACE_SYM S* 
                 *     '{' S* declaration [ ';' S* declaration ]* '}' S*
                 *   ;
                 */     
                var tokenStream = this._tokenStream,
                    line,
                    col;
                
                //look for @page
                tokenStream.mustMatch(Tokens.FONT_FACE_SYM);
                line = tokenStream.token().startLine;
                col = tokenStream.token().startCol;
                
                this._readWhitespace();

                this.fire({
                    type:   "startfontface",
                    line:   line,
                    col:    col
                });                    
                
                this._readDeclarations(true);
                
                this.fire({
                    type:   "endfontface",
                    line:   line,
                    col:    col
                });              
            },

            _operator: function(){
            
                /*
                 * operator
                 *  : '/' S* | ',' S* | /( empty )/
                 *  ;
                 */    
                 
                var tokenStream = this._tokenStream,
                    token       = null;
                
                if (tokenStream.match([Tokens.SLASH, Tokens.COMMA])){
                    token =  tokenStream.token();
                    this._readWhitespace();
                } 
                return token ? PropertyValuePart.fromToken(token) : null;
                
            },
            
            _combinator: function(){
            
                /*
                 * combinator
                 *  : PLUS S* | GREATER S* | TILDE S* | S+
                 *  ;
                 */    
                 
                var tokenStream = this._tokenStream,
                    value       = null,
                    token;
                
                if(tokenStream.match([Tokens.PLUS, Tokens.GREATER, Tokens.TILDE])){                
                    token = tokenStream.token();
                    value = new Combinator(token.value, token.startLine, token.startCol);
                    this._readWhitespace();
                }
                
                return value;
            },
            
            _unary_operator: function(){
            
                /*
                 * unary_operator
                 *  : '-' | '+'
                 *  ;
                 */
                 
                var tokenStream = this._tokenStream;
                
                if (tokenStream.match([Tokens.MINUS, Tokens.PLUS])){
                    return tokenStream.token().value;
                } else {
                    return null;
                }         
            },
            
            _property: function(){
            
                /*
                 * property
                 *   : IDENT S*
                 *   ;        
                 */
                 
                var tokenStream = this._tokenStream,
                    value       = null,
                    hack        = null,
                    tokenValue,
                    token,
                    line,
                    col;
                    
                //check for star hack - throws error if not allowed
                if (tokenStream.peek() == Tokens.STAR && this.options.starHack){
                    tokenStream.get();
                    token = tokenStream.token();
                    hack = token.value;
                    line = token.startLine;
                    col = token.startCol;
                }
                
                if(tokenStream.match(Tokens.IDENT)){
                    token = tokenStream.token();
                    tokenValue = token.value;
                    
                    //check for underscore hack - no error if not allowed because it's valid CSS syntax
                    if (tokenValue.charAt(0) == "_" && this.options.underscoreHack){
                        hack = "_";
                        tokenValue = tokenValue.substring(1);
                    }
                    
                    value = new PropertyName(tokenValue, hack, (line||token.startLine), (col||token.startCol));
                    this._readWhitespace();
                }
                
                return value;
            },
        
            //Augmented with CSS3 Selectors
            _ruleset: function(){
                /*
                 * ruleset
                 *   : selectors_group
                 *     '{' S* declaration? [ ';' S* declaration? ]* '}' S*
                 *   ;    
                 */    
                 
                var tokenStream = this._tokenStream,
                    tt,
                    selectors;


                /*
                 * Error Recovery: If even a single selector fails to parse,
                 * then the entire ruleset should be thrown away.
                 */
                try {
                    selectors = this._selectors_group();
                } catch (ex){
                    if (ex instanceof SyntaxError && !this.options.strict){
                    
                        //fire error event
                        this.fire({
                            type:       "error",
                            error:      ex,
                            message:    ex.message,
                            line:       ex.line,
                            col:        ex.col
                        });                          
                        
                        //skip over everything until closing brace
                        tt = tokenStream.advance([Tokens.RBRACE]);
                        if (tt == Tokens.RBRACE){
                            //if there's a right brace, the rule is finished so don't do anything
                        } else {
                            //otherwise, rethrow the error because it wasn't handled properly
                            throw ex;
                        }                        
                        
                    } else {
                        //not a syntax error, rethrow it
                        throw ex;
                    }                
                
                    //trigger parser to continue
                    return true;
                }
                
                //if it got here, all selectors parsed
                if (selectors){ 
                                    
                    this.fire({
                        type:       "startrule",
                        selectors:  selectors,
                        line:       selectors[0].line,
                        col:        selectors[0].col
                    });                
                    
                    this._readDeclarations(true);                
                    
                    this.fire({
                        type:       "endrule",
                        selectors:  selectors,
                        line:       selectors[0].line,
                        col:        selectors[0].col
                    });  
                    
                }
                
                return selectors;
                
            },

            //CSS3 Selectors
            _selectors_group: function(){
            
                /*            
                 * selectors_group
                 *   : selector [ COMMA S* selector ]*
                 *   ;
                 */           
                var tokenStream = this._tokenStream,
                    selectors   = [],
                    selector;
                    
                selector = this._selector();
                if (selector !== null){
                
                    selectors.push(selector);
                    while(tokenStream.match(Tokens.COMMA)){
                        this._readWhitespace();
                        selector = this._selector();
                        if (selector !== null){
                            selectors.push(selector);
                        } else {
                            this._unexpectedToken(tokenStream.LT(1));
                        }
                    }
                }

                return selectors.length ? selectors : null;
            },
                
            //CSS3 Selectors
            _selector: function(){
                /*
                 * selector
                 *   : simple_selector_sequence [ combinator simple_selector_sequence ]*
                 *   ;    
                 */
                 
                var tokenStream = this._tokenStream,
                    selector    = [],
                    nextSelector = null,
                    combinator  = null,
                    ws          = null;
                
                //if there's no simple selector, then there's no selector
                nextSelector = this._simple_selector_sequence();
                if (nextSelector === null){
                    return null;
                }
                
                selector.push(nextSelector);
                
                do {
                    
                    //look for a combinator
                    combinator = this._combinator();
                    
                    if (combinator !== null){
                        selector.push(combinator);
                        nextSelector = this._simple_selector_sequence();
                        
                        //there must be a next selector
                        if (nextSelector === null){
                            this._unexpectedToken(this.LT(1));
                        } else {
                        
                            //nextSelector is an instance of SelectorPart
                            selector.push(nextSelector);
                        }
                    } else {
                        
                        //if there's not whitespace, we're done
                        if (this._readWhitespace()){           
        
                            //add whitespace separator
                            ws = new Combinator(tokenStream.token().value, tokenStream.token().startLine, tokenStream.token().startCol);
                            
                            //combinator is not required
                            combinator = this._combinator();
                            
                            //selector is required if there's a combinator
                            nextSelector = this._simple_selector_sequence();
                            if (nextSelector === null){                        
                                if (combinator !== null){
                                    this._unexpectedToken(tokenStream.LT(1));
                                }
                            } else {
                                
                                if (combinator !== null){
                                    selector.push(combinator);
                                } else {
                                    selector.push(ws);
                                }
                                
                                selector.push(nextSelector);
                            }     
                        } else {
                            break;
                        }               
                    
                    }
                } while(true);
                
                return new Selector(selector, selector[0].line, selector[0].col);
            },
            
            //CSS3 Selectors
            _simple_selector_sequence: function(){
                /*
                 * simple_selector_sequence
                 *   : [ type_selector | universal ]
                 *     [ HASH | class | attrib | pseudo | negation ]*
                 *   | [ HASH | class | attrib | pseudo | negation ]+
                 *   ;
                 */
                 
                var tokenStream = this._tokenStream,
                
                    //parts of a simple selector
                    elementName = null,
                    modifiers   = [],
                    
                    //complete selector text
                    selectorText= "",

                    //the different parts after the element name to search for
                    components  = [
                        //HASH
                        function(){
                            return tokenStream.match(Tokens.HASH) ?
                                    new SelectorSubPart(tokenStream.token().value, "id", tokenStream.token().startLine, tokenStream.token().startCol) :
                                    null;
                        },
                        this._class,
                        this._attrib,
                        this._pseudo,
                        this._negation
                    ],
                    i           = 0,
                    len         = components.length,
                    component   = null,
                    found       = false,
                    line,
                    col;
                    
                    
                //get starting line and column for the selector
                line = tokenStream.LT(1).startLine;
                col = tokenStream.LT(1).startCol;
                                        
                elementName = this._type_selector();
                if (!elementName){
                    elementName = this._universal();
                }
                
                if (elementName !== null){
                    selectorText += elementName;
                }                
                
                while(true){

                    //whitespace means we're done
                    if (tokenStream.peek() === Tokens.S){
                        break;
                    }
                
                    //check for each component
                    while(i < len && component === null){
                        component = components[i++].call(this);
                    }
        
                    if (component === null){
                    
                        //we don't have a selector
                        if (selectorText === ""){
                            return null;
                        } else {
                            break;
                        }
                    } else {
                        i = 0;
                        modifiers.push(component);
                        selectorText += component.toString(); 
                        component = null;
                    }
                }

                 
                return selectorText !== "" ?
                        new SelectorPart(elementName, modifiers, selectorText, line, col) :
                        null;
            },            
            
            //CSS3 Selectors
            _type_selector: function(){
                /*
                 * type_selector
                 *   : [ namespace_prefix ]? element_name
                 *   ;
                 */
                 
                var tokenStream = this._tokenStream,
                    ns          = this._namespace_prefix(),
                    elementName = this._element_name();
                    
                if (!elementName){                    
                    /*
                     * Need to back out the namespace that was read due to both
                     * type_selector and universal reading namespace_prefix
                     * first. Kind of hacky, but only way I can figure out
                     * right now how to not change the grammar.
                     */
                    if (ns){
                        tokenStream.unget();
                        if (ns.length > 1){
                            tokenStream.unget();
                        }
                    }
                
                    return null;
                } else {     
                    if (ns){
                        elementName.text = ns + elementName.text;
                        elementName.col -= ns.length;
                    }
                    return elementName;
                }
            },
            
            //CSS3 Selectors
            _class: function(){
                /*
                 * class
                 *   : '.' IDENT
                 *   ;
                 */    
                 
                var tokenStream = this._tokenStream,
                    token;
                
                if (tokenStream.match(Tokens.DOT)){
                    tokenStream.mustMatch(Tokens.IDENT);    
                    token = tokenStream.token();
                    return new SelectorSubPart("." + token.value, "class", token.startLine, token.startCol - 1);        
                } else {
                    return null;
                }
        
            },
            
            //CSS3 Selectors
            _element_name: function(){
                /*
                 * element_name
                 *   : IDENT
                 *   ;
                 */    
                
                var tokenStream = this._tokenStream,
                    token;
                
                if (tokenStream.match(Tokens.IDENT)){
                    token = tokenStream.token();
                    return new SelectorSubPart(token.value, "elementName", token.startLine, token.startCol);        
                
                } else {
                    return null;
                }
            },
            
            //CSS3 Selectors
            _namespace_prefix: function(){
                /*            
                 * namespace_prefix
                 *   : [ IDENT | '*' ]? '|'
                 *   ;
                 */
                var tokenStream = this._tokenStream,
                    value       = "";
                    
                //verify that this is a namespace prefix
                if (tokenStream.LA(1) === Tokens.PIPE || tokenStream.LA(2) === Tokens.PIPE){
                        
                    if(tokenStream.match([Tokens.IDENT, Tokens.STAR])){
                        value += tokenStream.token().value;
                    }
                    
                    tokenStream.mustMatch(Tokens.PIPE);
                    value += "|";
                    
                }
                
                return value.length ? value : null;                
            },
            
            //CSS3 Selectors
            _universal: function(){
                /*
                 * universal
                 *   : [ namespace_prefix ]? '*'
                 *   ;            
                 */
                var tokenStream = this._tokenStream,
                    value       = "",
                    ns;
                    
                ns = this._namespace_prefix();
                if(ns){
                    value += ns;
                }
                
                if(tokenStream.match(Tokens.STAR)){
                    value += "*";
                }
                
                return value.length ? value : null;
                
           },
            
            //CSS3 Selectors
            _attrib: function(){
                /*
                 * attrib
                 *   : '[' S* [ namespace_prefix ]? IDENT S*
                 *         [ [ PREFIXMATCH |
                 *             SUFFIXMATCH |
                 *             SUBSTRINGMATCH |
                 *             '=' |
                 *             INCLUDES |
                 *             DASHMATCH ] S* [ IDENT | STRING ] S*
                 *         ]? ']'
                 *   ;    
                 */
                 
                var tokenStream = this._tokenStream,
                    value       = null,
                    ns,
                    token;
                
                if (tokenStream.match(Tokens.LBRACKET)){
                    token = tokenStream.token();
                    value = token.value;
                    value += this._readWhitespace();
                    
                    ns = this._namespace_prefix();
                    
                    if (ns){
                        value += ns;
                    }
                                        
                    tokenStream.mustMatch(Tokens.IDENT);
                    value += tokenStream.token().value;                    
                    value += this._readWhitespace();
                    
                    if(tokenStream.match([Tokens.PREFIXMATCH, Tokens.SUFFIXMATCH, Tokens.SUBSTRINGMATCH,
                            Tokens.EQUALS, Tokens.INCLUDES, Tokens.DASHMATCH])){
                    
                        value += tokenStream.token().value;                    
                        value += this._readWhitespace();
                        
                        tokenStream.mustMatch([Tokens.IDENT, Tokens.STRING]);
                        value += tokenStream.token().value;                    
                        value += this._readWhitespace();
                    }
                    
                    tokenStream.mustMatch(Tokens.RBRACKET);
                                        
                    return new SelectorSubPart(value + "]", "attribute", token.startLine, token.startCol);
                } else {
                    return null;
                }
            },
            
            //CSS3 Selectors
            _pseudo: function(){
            
                /*
                 * pseudo
                 *   : ':' ':'? [ IDENT | functional_pseudo ]
                 *   ;    
                 */   
            
                var tokenStream = this._tokenStream,
                    pseudo      = null,
                    colons      = ":",
                    line,
                    col;
                
                if (tokenStream.match(Tokens.COLON)){
                
                    if (tokenStream.match(Tokens.COLON)){
                        colons += ":";
                    }
                
                    if (tokenStream.match(Tokens.IDENT)){
                        pseudo = tokenStream.token().value;
                        line = tokenStream.token().startLine;
                        col = tokenStream.token().startCol - colons.length;
                    } else if (tokenStream.peek() == Tokens.FUNCTION){
                        line = tokenStream.LT(1).startLine;
                        col = tokenStream.LT(1).startCol - colons.length;
                        pseudo = this._functional_pseudo();
                    }
                    
                    if (pseudo){
                        pseudo = new SelectorSubPart(colons + pseudo, "pseudo", line, col);
                    }
                }
        
                return pseudo;
            },
            
            //CSS3 Selectors
            _functional_pseudo: function(){
                /*
                 * functional_pseudo
                 *   : FUNCTION S* expression ')'
                 *   ;
                */            
                
                var tokenStream = this._tokenStream,
                    value = null;
                
                if(tokenStream.match(Tokens.FUNCTION)){
                    value = tokenStream.token().value;
                    value += this._readWhitespace();
                    value += this._expression();
                    tokenStream.mustMatch(Tokens.RPAREN);
                    value += ")";
                }
                
                return value;
            },
            
            //CSS3 Selectors
            _expression: function(){
                /*
                 * expression
                 *   : [ [ PLUS | '-' | DIMENSION | NUMBER | STRING | IDENT ] S* ]+
                 *   ;
                 */
                 
                var tokenStream = this._tokenStream,
                    value       = "";
                    
                while(tokenStream.match([Tokens.PLUS, Tokens.MINUS, Tokens.DIMENSION,
                        Tokens.NUMBER, Tokens.STRING, Tokens.IDENT, Tokens.LENGTH,
                        Tokens.FREQ, Tokens.ANGLE, Tokens.TIME,
                        Tokens.RESOLUTION])){
                    
                    value += tokenStream.token().value;
                    value += this._readWhitespace();                        
                }
                
                return value.length ? value : null;
                
            },

            //CSS3 Selectors
            _negation: function(){
                /*            
                 * negation
                 *   : NOT S* negation_arg S* ')'
                 *   ;
                 */

                var tokenStream = this._tokenStream,
                    line,
                    col,
                    value       = "",
                    arg,
                    subpart     = null;
                    
                if (tokenStream.match(Tokens.NOT)){
                    value = tokenStream.token().value;
                    line = tokenStream.token().startLine;
                    col = tokenStream.token().startCol;
                    value += this._readWhitespace();
                    arg = this._negation_arg();
                    value += arg;
                    value += this._readWhitespace();
                    tokenStream.match(Tokens.RPAREN);
                    value += tokenStream.token().value;
                    
                    subpart = new SelectorSubPart(value, "not", line, col);
                    subpart.args.push(arg);
                }
                
                return subpart;
            },
            
            //CSS3 Selectors
            _negation_arg: function(){            
                /*
                 * negation_arg
                 *   : type_selector | universal | HASH | class | attrib | pseudo
                 *   ;            
                 */           
                 
                var tokenStream = this._tokenStream,
                    args        = [
                        this._type_selector,
                        this._universal,
                        function(){
                            return tokenStream.match(Tokens.HASH) ?
                                    new SelectorSubPart(tokenStream.token().value, "id", tokenStream.token().startLine, tokenStream.token().startCol) :
                                    null;                        
                        },
                        this._class,
                        this._attrib,
                        this._pseudo                    
                    ],
                    arg         = null,
                    i           = 0,
                    len         = args.length,
                    elementName,
                    line,
                    col,
                    part;
                    
                line = tokenStream.LT(1).startLine;
                col = tokenStream.LT(1).startCol;
                
                while(i < len && arg === null){
                    
                    arg = args[i].call(this);
                    i++;
                }
                
                //must be a negation arg
                if (arg === null){
                    this._unexpectedToken(tokenStream.LT(1));
                }
 
                //it's an element name
                if (arg.type == "elementName"){
                    part = new SelectorPart(arg, [], arg.toString(), line, col);
                } else {
                    part = new SelectorPart(null, [arg], arg.toString(), line, col);
                }
                
                return part;                
            },
            
            _declaration: function(){
            
                /*
                 * declaration
                 *   : property ':' S* expr prio?
                 *   | /( empty )/
                 *   ;     
                 */    
            
                var tokenStream = this._tokenStream,
                    property    = null,
                    expr        = null,
                    prio        = null,
                    error       = null,
                    invalid     = null;
                
                property = this._property();
                if (property !== null){

                    tokenStream.mustMatch(Tokens.COLON);
                    this._readWhitespace();
                    
                    expr = this._expr();
                    
                    //if there's no parts for the value, it's an error
                    if (!expr || expr.length === 0){
                        this._unexpectedToken(tokenStream.LT(1));
                    }
                    
                    prio = this._prio();
                    
                    try {
                        this._validateProperty(property, expr);
                    } catch (ex) {
                        invalid = ex;
                    }
                    
                    this.fire({
                        type:       "property",
                        property:   property,
                        value:      expr,
                        important:  prio,
                        line:       property.line,
                        col:        property.col,
                        invalid:    invalid
                    });                      
                    
                    return true;
                } else {
                    return false;
                }
            },
            
            _prio: function(){
                /*
                 * prio
                 *   : IMPORTANT_SYM S*
                 *   ;    
                 */
                 
                var tokenStream = this._tokenStream,
                    result      = tokenStream.match(Tokens.IMPORTANT_SYM);
                    
                this._readWhitespace();
                return result;
            },
            
            _expr: function(){
                /*
                 * expr
                 *   : term [ operator term ]*
                 *   ;
                 */
        
                var tokenStream = this._tokenStream,
                    values      = [],
					//valueParts	= [],
                    value       = null,
                    operator    = null;
                    
                value = this._term();
                if (value !== null){
                
                    values.push(value);
                    
                    do {
                        operator = this._operator();
        
                        //if there's an operator, keep building up the value parts
                        if (operator){
                            values.push(operator);
                        } /*else {
                            //if there's not an operator, you have a full value
							values.push(new PropertyValue(valueParts, valueParts[0].line, valueParts[0].col));
							valueParts = [];
						}*/
                        
                        value = this._term();
                        
                        if (value === null){
                            break;
                        } else {
                            values.push(value);
                        }
                    } while(true);
                }
				
				//cleanup
                /*if (valueParts.length){
                    values.push(new PropertyValue(valueParts, valueParts[0].line, valueParts[0].col));
                }*/
        
                return values.length > 0 ? new PropertyValue(values, values[0].startLine, values[0].startCol) : null;
            },
            
            _term: function(){                       
            
                /*
                 * term
                 *   : unary_operator?
                 *     [ NUMBER S* | PERCENTAGE S* | LENGTH S* | ANGLE S* |
                 *       TIME S* | FREQ S* | function | ie_function ]
                 *   | STRING S* | IDENT S* | URI S* | UNICODERANGE S* | hexcolor
                 *   ;
                 */    
        
                var tokenStream = this._tokenStream,
                    unary       = null,
                    value       = null,
                    line,
                    col;
                    
                //returns the operator or null
                unary = this._unary_operator();
                if (unary !== null){
                    line = tokenStream.token().startLine;
                    col = tokenStream.token().startCol;
                }                
               
                //exception for IE filters
                if (tokenStream.peek() == Tokens.IE_FUNCTION && this.options.ieFilters){
                
                    value = this._ie_function();
                    if (unary === null){
                        line = tokenStream.token().startLine;
                        col = tokenStream.token().startCol;
                    }
                
                //see if there's a simple match
                } else if (tokenStream.match([Tokens.NUMBER, Tokens.PERCENTAGE, Tokens.LENGTH,
                        Tokens.ANGLE, Tokens.TIME,
                        Tokens.FREQ, Tokens.STRING, Tokens.IDENT, Tokens.URI, Tokens.UNICODE_RANGE])){
                 
                    value = tokenStream.token().value;
                    if (unary === null){
                        line = tokenStream.token().startLine;
                        col = tokenStream.token().startCol;
                    }
                    this._readWhitespace();
                } else {
                
                    //see if it's a color
                    value = this._hexcolor();
                    if (value === null){
                    
                        //if there's no unary, get the start of the next token for line/col info
                        if (unary === null){
                            line = tokenStream.LT(1).startLine;
                            col = tokenStream.LT(1).startCol;
                        }                    
                    
                        //has to be a function
                        if (value === null){
                            
                            /*
                             * This checks for alpha(opacity=0) style of IE
                             * functions. IE_FUNCTION only presents progid: style.
                             */
                            if (tokenStream.LA(3) == Tokens.EQUALS && this.options.ieFilters){
                                value = this._ie_function();
                            } else {
                                value = this._function();
                            }
                        }

                        /*if (value === null){
                            return null;
                            //throw new Error("Expected identifier at line " + tokenStream.token().startLine + ", character " +  tokenStream.token().startCol + ".");
                        }*/
                    
                    } else {
                        if (unary === null){
                            line = tokenStream.token().startLine;
                            col = tokenStream.token().startCol;
                        }                    
                    }
                
                }                
                
                return value !== null ?
                        new PropertyValuePart(unary !== null ? unary + value : value, line, col) :
                        null;
        
            },
            
            _function: function(){
            
                /*
                 * function
                 *   : FUNCTION S* expr ')' S*
                 *   ;
                 */
                 
                var tokenStream = this._tokenStream,
                    functionText = null,
                    expr        = null,
                    lt;
                    
                if (tokenStream.match(Tokens.FUNCTION)){
                    functionText = tokenStream.token().value;
                    this._readWhitespace();
                    expr = this._expr();
                    functionText += expr;
                    
                    //START: Horrible hack in case it's an IE filter
                    if (this.options.ieFilters && tokenStream.peek() == Tokens.EQUALS){
                        do {
                        
                            if (this._readWhitespace()){
                                functionText += tokenStream.token().value;
                            }
                            
                            //might be second time in the loop
                            if (tokenStream.LA(0) == Tokens.COMMA){
                                functionText += tokenStream.token().value;
                            }
                        
                            tokenStream.match(Tokens.IDENT);
                            functionText += tokenStream.token().value;
                            
                            tokenStream.match(Tokens.EQUALS);
                            functionText += tokenStream.token().value;
                            
                            //functionText += this._term();
                            lt = tokenStream.peek();
                            while(lt != Tokens.COMMA && lt != Tokens.S && lt != Tokens.RPAREN){
                                tokenStream.get();
                                functionText += tokenStream.token().value;
                                lt = tokenStream.peek();
                            }
                        } while(tokenStream.match([Tokens.COMMA, Tokens.S]));
                    }

                    //END: Horrible Hack
                    
                    tokenStream.match(Tokens.RPAREN);    
                    functionText += ")";
                    this._readWhitespace();
                }                
                
                return functionText;
            }, 
            
            _ie_function: function(){
            
                /* (My own extension)
                 * ie_function
                 *   : IE_FUNCTION S* IDENT '=' term [S* ','? IDENT '=' term]+ ')' S*
                 *   ;
                 */
                 
                var tokenStream = this._tokenStream,
                    functionText = null,
                    expr        = null,
                    lt;
                    
                //IE function can begin like a regular function, too
                if (tokenStream.match([Tokens.IE_FUNCTION, Tokens.FUNCTION])){
                    functionText = tokenStream.token().value;
                    
                    do {
                    
                        if (this._readWhitespace()){
                            functionText += tokenStream.token().value;
                        }
                        
                        //might be second time in the loop
                        if (tokenStream.LA(0) == Tokens.COMMA){
                            functionText += tokenStream.token().value;
                        }
                    
                        tokenStream.match(Tokens.IDENT);
                        functionText += tokenStream.token().value;
                        
                        tokenStream.match(Tokens.EQUALS);
                        functionText += tokenStream.token().value;
                        
                        //functionText += this._term();
                        lt = tokenStream.peek();
                        while(lt != Tokens.COMMA && lt != Tokens.S && lt != Tokens.RPAREN){
                            tokenStream.get();
                            functionText += tokenStream.token().value;
                            lt = tokenStream.peek();
                        }
                    } while(tokenStream.match([Tokens.COMMA, Tokens.S]));                    
                    
                    tokenStream.match(Tokens.RPAREN);    
                    functionText += ")";
                    this._readWhitespace();
                }                
                
                return functionText;
            }, 
            
            _hexcolor: function(){
                /*
                 * There is a constraint on the color that it must
                 * have either 3 or 6 hex-digits (i.e., [0-9a-fA-F])
                 * after the "#"; e.g., "#000" is OK, but "#abcd" is not.
                 *
                 * hexcolor
                 *   : HASH S*
                 *   ;
                 */
                 
                var tokenStream = this._tokenStream,
                    token,
                    color = null;
                
                if(tokenStream.match(Tokens.HASH)){
                
                    //need to do some validation here
                    
                    token = tokenStream.token();
                    color = token.value;
                    if (!/#[a-f0-9]{3,6}/i.test(color)){
                        throw new SyntaxError("Expected a hex color but found '" + color + "' at line " + token.startLine + ", col " + token.startCol + ".", token.startLine, token.startCol);
                    }
                    this._readWhitespace();
                }
                
                return color;
            },
            
            //-----------------------------------------------------------------
            // Animations methods
            //-----------------------------------------------------------------
            
            _keyframes: function(){
            
                /*
                 * keyframes:
                 *   : KEYFRAMES_SYM S* keyframe_name S* '{' S* keyframe_rule* '}' {
                 *   ;
                 */
                var tokenStream = this._tokenStream,
                    token,
                    tt,
                    name;            
                    
                tokenStream.mustMatch(Tokens.KEYFRAMES_SYM);
                this._readWhitespace();
                name = this._keyframe_name();
                
                this._readWhitespace();
                tokenStream.mustMatch(Tokens.LBRACE);
                    
                this.fire({
                    type:   "startkeyframes",
                    name:   name,
                    line:   name.line,
                    col:    name.col
                });                
                
                this._readWhitespace();
                tt = tokenStream.peek();
                
                //check for key
                while(tt == Tokens.IDENT || tt == Tokens.PERCENTAGE) {
                    this._keyframe_rule();
                    this._readWhitespace();
                    tt = tokenStream.peek();
                }           
                
                this.fire({
                    type:   "endkeyframes",
                    name:   name,
                    line:   name.line,
                    col:    name.col
                });                      
                    
                this._readWhitespace();
                tokenStream.mustMatch(Tokens.RBRACE);                    
                
            },
            
            _keyframe_name: function(){
            
                /*
                 * keyframe_name:
                 *   : IDENT
                 *   | STRING
                 *   ;
                 */
                var tokenStream = this._tokenStream,
                    token;

                tokenStream.mustMatch([Tokens.IDENT, Tokens.STRING]);
                return SyntaxUnit.fromToken(tokenStream.token());            
            },
            
            _keyframe_rule: function(){
            
                /*
                 * keyframe_rule:
                 *   : key_list S* 
                 *     '{' S* declaration [ ';' S* declaration ]* '}' S*
                 *   ;
                 */
                var tokenStream = this._tokenStream,
                    token,
                    keyList = this._key_list();
                                    
                this.fire({
                    type:   "startkeyframerule",
                    keys:   keyList,
                    line:   keyList[0].line,
                    col:    keyList[0].col
                });                
                
                this._readDeclarations(true);                
                
                this.fire({
                    type:   "endkeyframerule",
                    keys:   keyList,
                    line:   keyList[0].line,
                    col:    keyList[0].col
                });  
                
            },
            
            _key_list: function(){
            
                /*
                 * key_list:
                 *   : key [ S* ',' S* key]*
                 *   ;
                 */
                var tokenStream = this._tokenStream,
                    token,
                    key,
                    keyList = [];
                    
                //must be least one key
                keyList.push(this._key());
                    
                this._readWhitespace();
                    
                while(tokenStream.match(Tokens.COMMA)){
                    this._readWhitespace();
                    keyList.push(this._key());
                    this._readWhitespace();
                }

                return keyList;
            },
                        
            _key: function(){
                /*
                 * There is a restriction that IDENT can be only "from" or "to".
                 *
                 * key
                 *   : PERCENTAGE
                 *   | IDENT
                 *   ;
                 */
                 
                var tokenStream = this._tokenStream,
                    token;
                    
                if (tokenStream.match(Tokens.PERCENTAGE)){
                    return SyntaxUnit.fromToken(tokenStream.token());
                } else if (tokenStream.match(Tokens.IDENT)){
                    token = tokenStream.token();                    
                    
                    if (/from|to/i.test(token.value)){
                        return SyntaxUnit.fromToken(token);
                    }
                    
                    tokenStream.unget();
                }
                
                //if it gets here, there wasn't a valid token, so time to explode
                this._unexpectedToken(tokenStream.LT(1));
            },
            
            //-----------------------------------------------------------------
            // Helper methods
            //-----------------------------------------------------------------
            
            /**
             * Not part of CSS grammar, but useful for skipping over
             * combination of white space and HTML-style comments.
             * @return {void}
             * @method _skipCruft
             * @private
             */
            _skipCruft: function(){
                while(this._tokenStream.match([Tokens.S, Tokens.CDO, Tokens.CDC])){
                    //noop
                }
            },

            /**
             * Not part of CSS grammar, but this pattern occurs frequently
             * in the official CSS grammar. Split out here to eliminate
             * duplicate code.
             * @param {Boolean} checkStart Indicates if the rule should check
             *      for the left brace at the beginning.
             * @param {Boolean} readMargins Indicates if the rule should check
             *      for margin patterns.
             * @return {void}
             * @method _readDeclarations
             * @private
             */
            _readDeclarations: function(checkStart, readMargins){
                /*
                 * Reads the pattern
                 * S* '{' S* declaration [ ';' S* declaration ]* '}' S*
                 * or
                 * S* '{' S* [ declaration | margin ]? [ ';' S* [ declaration | margin ]? ]* '}' S*
                 * Note that this is how it is described in CSS3 Paged Media, but is actually incorrect.
                 * A semicolon is only necessary following a delcaration is there's another declaration
                 * or margin afterwards. 
                 */
                var tokenStream = this._tokenStream,
                    tt;
                       

                this._readWhitespace();
                
                if (checkStart){
                    tokenStream.mustMatch(Tokens.LBRACE);            
                }
                
                this._readWhitespace();

                try {
                    
                    while(true){
                    
                        if (readMargins && this._margin()){
                            //noop
                        } else if (this._declaration()){
                            if (!tokenStream.match(Tokens.SEMICOLON)){
                                break;
                            }
                        } else {
                            break;
                        }
                    
                        //if ((!this._margin() && !this._declaration()) || !tokenStream.match(Tokens.SEMICOLON)){
                        //    break;
                        //}
                        this._readWhitespace();
                    }
                    
                    tokenStream.mustMatch(Tokens.RBRACE);
                    this._readWhitespace();
                    
                } catch (ex) {
                    if (ex instanceof SyntaxError && !this.options.strict){
                    
                        //fire error event
                        this.fire({
                            type:       "error",
                            error:      ex,
                            message:    ex.message,
                            line:       ex.line,
                            col:        ex.col
                        });                          
                        
                        //see if there's another declaration
                        tt = tokenStream.advance([Tokens.SEMICOLON, Tokens.RBRACE]);
                        if (tt == Tokens.SEMICOLON){
                            //if there's a semicolon, then there might be another declaration
                            this._readDeclarations(false, readMargins);
                        } else if (tt == Tokens.RBRACE){
                            //if there's a right brace, the rule is finished so don't do anything
                        } else {
                            //otherwise, rethrow the error because it wasn't handled properly
                            throw ex;
                        }                        
                        
                    } else {
                        //not a syntax error, rethrow it
                        throw ex;
                    }
                }    
            
            },      
            
            /**
             * In some cases, you can end up with two white space tokens in a
             * row. Instead of making a change in every function that looks for
             * white space, this function is used to match as much white space
             * as necessary.
             * @method _readWhitespace
             * @return {String} The white space if found, empty string if not.
             * @private
             */
            _readWhitespace: function(){
            
                var tokenStream = this._tokenStream,
                    ws = "";
                    
                while(tokenStream.match(Tokens.S)){
                    ws += tokenStream.token().value;
                }
                
                return ws;
            },
          

            /**
             * Throws an error when an unexpected token is found.
             * @param {Object} token The token that was found.
             * @method _unexpectedToken
             * @return {void}
             * @private
             */
            _unexpectedToken: function(token){
                throw new SyntaxError("Unexpected token '" + token.value + "' at line " + token.startLine + ", col " + token.startCol + ".", token.startLine, token.startCol);
            },
            
            /**
             * Helper method used for parsing subparts of a style sheet.
             * @return {void}
             * @method _verifyEnd
             * @private
             */
            _verifyEnd: function(){
                if (this._tokenStream.LA(1) != Tokens.EOF){
                    this._unexpectedToken(this._tokenStream.LT(1));
                }            
            },
            
            //-----------------------------------------------------------------
            // Validation methods
            //-----------------------------------------------------------------
            _validateProperty: function(property, value){
                var name = property.text.toLowerCase(),
                    validation,
                    i, len;
                
                if (Properties[name]){
                
                    if (typeof Properties[name] == "function"){
                        Properties[name](value);                   
                    } 
                    
                    //otherwise, no validation available yet
                } else if (name.indexOf("-") !== 0){    //vendor prefixed are ok
                    throw new ValidationError("Unknown property '" + property + "'.", property.line, property.col);
                }
            },
            
            //-----------------------------------------------------------------
            // Parsing methods
            //-----------------------------------------------------------------
            
            parse: function(input){    
                this._tokenStream = new TokenStream(input, Tokens);
                this._stylesheet();
            },
            
            parseStyleSheet: function(input){
                //just passthrough
                return this.parse(input);
            },
            
            parseMediaQuery: function(input){
                this._tokenStream = new TokenStream(input, Tokens);
                var result = this._media_query();
                
                //if there's anything more, then it's an invalid selector
                this._verifyEnd();
                
                //otherwise return result
                return result;            
            },
            
            /**
             * Parses a property value (everything after the semicolon).
             * @return {parserlib.css.PropertyValue} The property value.
             * @throws parserlib.util.SyntaxError If an unexpected token is found.
             * @method parserPropertyValue
             */             
            parsePropertyValue: function(input){
            
                this._tokenStream = new TokenStream(input, Tokens);
                this._readWhitespace();
                
                var result = this._expr();
                
                //okay to have a trailing white space
                this._readWhitespace();
                
                //if there's anything more, then it's an invalid selector
                this._verifyEnd();
                
                //otherwise return result
                return result;
            },
            
            /**
             * Parses a complete CSS rule, including selectors and
             * properties.
             * @param {String} input The text to parser.
             * @return {Boolean} True if the parse completed successfully, false if not.
             * @method parseRule
             */
            parseRule: function(input){
                this._tokenStream = new TokenStream(input, Tokens);
                
                //skip any leading white space
                this._readWhitespace();
                
                var result = this._ruleset();
                
                //skip any trailing white space
                this._readWhitespace();

                //if there's anything more, then it's an invalid selector
                this._verifyEnd();
                
                //otherwise return result
                return result;            
            },
            
            /**
             * Parses a single CSS selector (no comma)
             * @param {String} input The text to parse as a CSS selector.
             * @return {Selector} An object representing the selector.
             * @throws parserlib.util.SyntaxError If an unexpected token is found.
             * @method parseSelector
             */
            parseSelector: function(input){
            
                this._tokenStream = new TokenStream(input, Tokens);
                
                //skip any leading white space
                this._readWhitespace();
                
                var result = this._selector();
                
                //skip any trailing white space
                this._readWhitespace();

                //if there's anything more, then it's an invalid selector
                this._verifyEnd();
                
                //otherwise return result
                return result;
            },

            /**
             * Parses an HTML style attribute: a set of CSS declarations 
             * separated by semicolons.
             * @param {String} input The text to parse as a style attribute
             * @return {void} 
             * @method parseStyleAttribute
             */
            parseStyleAttribute: function(input){
                input += "}"; // for error recovery in _readDeclarations()
                this._tokenStream = new TokenStream(input, Tokens);
                this._readDeclarations();
            }
        };
        
    //copy over onto prototype
    for (prop in additions){
        proto[prop] = additions[prop];
    }   
    
    return proto;
}();


/*
nth
  : S* [ ['-'|'+']? INTEGER? {N} [ S* ['-'|'+'] S* INTEGER ]? |
         ['-'|'+']? INTEGER | {O}{D}{D} | {E}{V}{E}{N} ] S*
  ;
*/
//This file will likely change a lot! Very experimental!

var ValidationType = {

    "absolute-size": function(part){
        return this.identifier(part, "xx-small | x-small | small | medium | large | x-large | xx-large");
    },
    
    "attachment": function(part){
        return this.identifier(part, "scroll | fixed | local");
    },
    
    "box": function(part){
        return this.identifier(part, "padding-box | border-box | content-box");
    },
    
    "relative-size": function(part){
        return this.identifier(part, "smaller | larger");
    },
    
    "identifier": function(part, options){
        var text = part.text.toString().toLowerCase(),
            args = options.split(" | "),
            i, len, found = false;

        
        for (i=0,len=args.length; i < len && !found; i++){
            if (text == args[i]){
                found = true;
            }
        }
        
        return found;
    },
    
    "length": function(part){
        return part.type == "length" || part.type == "number" || part.type == "integer" || part == "0";
    },
    
    "color": function(part){
        return part.type == "color" || part == "transparent";
    },
    
    "number": function(part){
        return part.type == "number" || this.integer(part);
    },
    
    "integer": function(part){
        return part.type == "integer";
    },
    
    "angle": function(part){
        return part.type == "angle";
    },        
    
    "uri": function(part){
        return part.type == "uri";
    },
    
    "image": function(part){
        return this.uri(part);
    },
    
    "bg-image": function(part){
        return this.image(part) || part == "none";
    },
    
    "percentage": function(part){
        return part.type == "percentage" || part == "0";
    },

    "border-width": function(part){
        return this.length(part) || this.identifier(part, "thin | medium | thick");
    },
    
    "border-style": function(part){
        return this.identifier(part, "none | hidden | dotted | dashed | solid | double | groove | ridge | inset | outset");
    },
    
    "margin-width": function(part){
        return this.length(part) || this.percentage(part) || this.identifier(part, "auto");
    },
    
    "padding-width": function(part){
        return this.length(part) || this.percentage(part);
    }
};

    
       




var Properties = {

    //A
    "alignment-adjust": 1,
    "alignment-baseline": 1,
    "animation": 1,
    "animation-delay": 1,
    "animation-direction":          { multi: [ "normal | alternate" ], separator: "," },
    "animation-duration": 1,
    "animation-fill-mode": 1,
    "animation-iteration-count":    { multi: [ "number", "infinite"], separator: "," },
    "animation-name": 1,
    "animation-play-state":         { multi: [ "running | paused" ], separator: "," },
    "animation-timing-function": 1,
    "appearance": 1,
    "azimuth": 1,
    
    //B
    "backface-visibility": 1,
    "background": 1,
    "background-attachment":        { multi: [ "attachment" ], separator: "," },
    "background-break": 1,
    "background-clip":              { multi: [ "box" ], separator: "," },
    "background-color":             [ "color", "inherit" ],
    "background-image":             { multi: [ "bg-image" ], separator: "," },
    "background-origin":            { multi: [ "box" ], separator: "," },
    "background-position": 1,
    "background-repeat":            [ "repeat | repeat-x | repeat-y | no-repeat | inherit" ],
    "background-size": 1,
    "baseline-shift": 1,
    "binding": 1,
    "bleed": 1,
    "bookmark-label": 1,
    "bookmark-level": 1,
    "bookmark-state": 1,
    "bookmark-target": 1,
    "border": 1,
    "border-bottom": 1,
    "border-bottom-color": 1,
    "border-bottom-left-radius":    1,
    "border-bottom-right-radius":   1,
    "border-bottom-style":          [ "border-style" ],
    "border-bottom-width":          [ "border-width" ],
    "border-collapse":              [ "collapse | separate | inherit" ],
    "border-color":                 { multi: [ "color", "inherit" ], max: 4 },
    "border-image": 1,
    "border-image-outset":          { multi: [ "length", "number" ], max: 4 },
    "border-image-repeat":          { multi: [ "stretch | repeat | round" ], max: 2 },
    "border-image-slice": 1,
    "border-image-source":          [ "image", "none" ],
    "border-image-width":           { multi: [ "length", "percentage", "number", "auto" ], max: 4 },
    "border-left": 1,
    "border-left-color":            [ "color", "inherit" ],
    "border-left-style":            [ "border-style" ],
    "border-left-width":            [ "border-width" ],
    "border-radius": 1,
    "border-right": 1,
    "border-right-color":           [ "color", "inherit" ],
    "border-right-style":           [ "border-style" ],
    "border-right-width":           [ "border-width" ],
    "border-spacing": 1,
    "border-style":                 { multi: [ "border-style" ], max: 4 },
    "border-top": 1,
    "border-top-color":             [ "color", "inherit" ],
    "border-top-left-radius": 1,
    "border-top-right-radius": 1,
    "border-top-style":             [ "border-style" ],
    "border-top-width":             [ "border-width" ],
    "border-width":                 { multi: [ "border-width" ], max: 4 },
    "bottom":                       [ "margin-width", "inherit" ], 
    "box-align":                    [ "start | end | center | baseline | stretch" ],        //http://www.w3.org/TR/2009/WD-css3-flexbox-20090723/
    "box-decoration-break":         [ "slice |clone" ],
    "box-direction":                [ "normal | reverse | inherit" ],
    "box-flex":                     [ "number" ],
    "box-flex-group":               [ "integer" ],
    "box-lines":                    [ "single | multiple" ],
    "box-ordinal-group":            [ "integer" ],
    "box-orient":                   [ "horizontal | vertical | inline-axis | block-axis | inherit" ],
    "box-pack":                     [ "start | end | center | justify" ],
    "box-shadow": 1,
    "box-sizing":                   [ "content-box | border-box | inherit" ],
    "break-after":                  [ "auto | always | avoid | left | right | page | column | avoid-page | avoid-column" ],
    "break-before":                 [ "auto | always | avoid | left | right | page | column | avoid-page | avoid-column" ],
    "break-inside":                 [ "auto | avoid | avoid-page | avoid-column" ],
    
    //C
    "caption-side":                 [ "top | bottom | inherit" ],
    "clear":                        [ "none | right | left | both | inherit" ],
    "clip": 1,
    "color":                        [ "color", "inherit" ],
    "color-profile": 1,
    "column-count":                 [ "integer", "auto" ],                      //http://www.w3.org/TR/css3-multicol/
    "column-fill":                  [ "auto | balance" ],
    "column-gap":                   [ "length", "normal" ],
    "column-rule": 1,
    "column-rule-color":            [ "color" ],
    "column-rule-style":            [ "border-style" ],
    "column-rule-width":            [ "border-width" ],
    "column-span":                  [ "none | all" ],
    "column-width":                 [ "length", "auto" ],
    "columns": 1,
    "content": 1,
    "counter-increment": 1,
    "counter-reset": 1,
    "crop": 1,
    "cue":                          [ "cue-after | cue-before | inherit" ],
    "cue-after": 1,
    "cue-before": 1,
    "cursor": 1,
    
    //D
    "direction":                    [ "ltr | rtl | inherit" ],
    "display":                      [ "inline | block | list-item | inline-block | table | inline-table | table-row-group | table-header-group | table-footer-group | table-row | table-column-group | table-column | table-cell | table-caption | box | inline-box | grid | inline-grid", "none | inherit" ],
    "dominant-baseline": 1,
    "drop-initial-after-adjust": 1,
    "drop-initial-after-align": 1,
    "drop-initial-before-adjust": 1,
    "drop-initial-before-align": 1,
    "drop-initial-size": 1,
    "drop-initial-value": 1,
    
    //E
    "elevation": 1,
    "empty-cells":                  [ "show | hide | inherit" ],
    
    //F
    "filter": 1,
    "fit":                          [ "fill | hidden | meet | slice" ],
    "fit-position": 1,
    "float":                        [ "left | right | none | inherit" ],    
    "float-offset": 1,
    "font": 1,
    "font-family": 1,
    "font-size":                    [ "absolute-size", "relative-size", "length", "percentage", "inherit" ],
    "font-size-adjust": 1,
    "font-stretch": 1,
    "font-style":                   [ "normal | italic | oblique | inherit" ],
    "font-variant":                 [ "normal | small-caps | inherit" ],
    "font-weight":                  [ "normal | bold | bolder | lighter | 100 | 200 | 300 | 400 | 500 | 600 | 700 | 800 | 900 | inherit" ],
    
    //G
    "grid-cell-stacking":           [ "columns | rows | layer" ],
    "grid-column": 1,
    "grid-columns": 1,
    "grid-column-align":            [ "start | end | center | stretch" ],
    "grid-column-sizing": 1,
    "grid-column-span":             [ "integer" ],
    "grid-flow":                    [ "none | rows | columns" ],
    "grid-layer":                   [ "integer" ],
    "grid-row": 1,
    "grid-rows": 1,
    "grid-row-align":               [ "start | end | center | stretch" ],
    "grid-row-span":                [ "integer" ],
    "grid-row-sizing": 1,
    
    //H
    "hanging-punctuation": 1,
    "height":                       [ "margin-width", "inherit" ],
    "hyphenate-after": 1,
    "hyphenate-before": 1,
    "hyphenate-character":          [ "string", "auto" ],
    "hyphenate-lines": 1,
    "hyphenate-resource": 1,
    "hyphens":                      [ "none | manual | auto" ],
    
    //I
    "icon": 1,
    "image-orientation":            [ "angle", "auto" ],
    "image-rendering": 1,
    "image-resolution": 1,
    "inline-box-align": 1,
    
    //L
    "left":                         [ "margin-width", "inherit" ],
    "letter-spacing":               [ "length", "normal | inherit" ],
    "line-height":                  [ "number", "length", "percentage", "normal | inherit"],
    "line-break":                   [ "auto | loose | normal | strict" ],
    "line-stacking": 1,
    "line-stacking-ruby": 1,
    "line-stacking-shift": 1,
    "line-stacking-strategy": 1,
    "list-style": 1,
    "list-style-image":             [ "uri", "none | inherit" ],
    "list-style-position":          [ "inside | outside | inherit" ],
    "list-style-type":              [ "disc | circle | square | decimal | decimal-leading-zero | lower-roman | upper-roman | lower-greek | lower-latin | upper-latin | armenian | georgian | lower-alpha | upper-alpha | none | inherit" ],
    
    //M
    "margin":                       { multi: [ "margin-width", "inherit" ], max: 4 },
    "margin-bottom":                [ "margin-width", "inherit" ],
    "margin-left":                  [ "margin-width", "inherit" ],
    "margin-right":                 [ "margin-width", "inherit" ],
    "margin-top":                   [ "margin-width", "inherit" ],
    "mark": 1,
    "mark-after": 1,
    "mark-before": 1,
    "marks": 1,
    "marquee-direction": 1,
    "marquee-play-count": 1,
    "marquee-speed": 1,
    "marquee-style": 1,
    "max-height":                   [ "length", "percentage", "none | inherit" ],
    "max-width":                    [ "length", "percentage", "none | inherit" ],
    "min-height":                   [ "length", "percentage", "inherit" ],
    "min-width":                    [ "length", "percentage", "inherit" ],
    "move-to": 1,
    
    //N
    "nav-down": 1,
    "nav-index": 1,
    "nav-left": 1,
    "nav-right": 1,
    "nav-up": 1,
    
    //O
    "opacity":                      [ "number", "inherit" ],
    "orphans":                      [ "integer", "inherit" ],
    "outline": 1,
    "outline-color":                [ "color", "invert | inherit" ],
    "outline-offset": 1,
    "outline-style":                [ "border-style", "inherit" ],
    "outline-width":                [ "border-width", "inherit" ],
    "overflow":                     [ "visible | hidden | scroll | auto | inherit" ],
    "overflow-style": 1,
    "overflow-x": 1,
    "overflow-y": 1,
    
    //P
    "padding":                      { multi: [ "padding-width", "inherit" ], max: 4 },
    "padding-bottom":               [ "padding-width", "inherit" ],
    "padding-left":                 [ "padding-width", "inherit" ],
    "padding-right":                [ "padding-width", "inherit" ],
    "padding-top":                  [ "padding-width", "inherit" ],
    "page": 1,
    "page-break-after":             [ "auto | always | avoid | left | right | inherit" ],
    "page-break-before":            [ "auto | always | avoid | left | right | inherit" ],
    "page-break-inside":            [ "auto | avoid | inherit" ],
    "page-policy": 1,
    "pause": 1,
    "pause-after": 1,
    "pause-before": 1,
    "perspective": 1,
    "perspective-origin": 1,
    "phonemes": 1,
    "pitch": 1,
    "pitch-range": 1,
    "play-during": 1,
    "position":                     [ "static | relative | absolute | fixed | inherit" ],
    "presentation-level": 1,
    "punctuation-trim": 1,
    
    //Q
    "quotes": 1,
    
    //R
    "rendering-intent": 1,
    "resize": 1,
    "rest": 1,
    "rest-after": 1,
    "rest-before": 1,
    "richness": 1,
    "right":                        [ "margin-width", "inherit" ],
    "rotation": 1,
    "rotation-point": 1,
    "ruby-align": 1,
    "ruby-overhang": 1,
    "ruby-position": 1,
    "ruby-span": 1,
    
    //S
    "size": 1,
    "speak":                        [ "normal | none | spell-out | inherit" ],
    "speak-header":                 [ "once | always | inherit" ],
    "speak-numeral":                [ "digits | continuous | inherit" ],
    "speak-punctuation":            [ "code | none | inherit" ],
    "speech-rate": 1,
    "src" : 1,
    "stress": 1,
    "string-set": 1,
    
    "table-layout":                 [ "auto | fixed | inherit" ],
    "tab-size":                     [ "integer", "length" ],
    "target": 1,
    "target-name": 1,
    "target-new": 1,
    "target-position": 1,
    "text-align":                   [ "left | right | center | justify | inherit" ],
    "text-align-last": 1,
    "text-decoration": 1,
    "text-emphasis": 1,
    "text-height": 1,
    "text-indent":                  [ "length", "percentage", "inherit" ],
    "text-justify":                 [ "auto | none | inter-word | inter-ideograph | inter-cluster | distribute | kashida" ],
    "text-outline": 1,
    "text-overflow": 1,
    "text-shadow": 1,
    "text-transform":               [ "capitalize | uppercase | lowercase | none | inherit" ],
    "text-wrap":                    [ "normal | none | avoid" ],
    "top":                          [ "margin-width", "inherit" ],
    "transform": 1,
    "transform-origin": 1,
    "transform-style": 1,
    "transition": 1,
    "transition-delay": 1,
    "transition-duration": 1,
    "transition-property": 1,
    "transition-timing-function": 1,
    
    //U
    "unicode-bidi":                 [ "normal | embed | bidi-override | inherit" ],
    "user-modify":                  [ "read-only | read-write | write-only | inherit" ],
    "user-select":                  [ "none | text | toggle | element | elements | all | inherit" ],
    
    //V
    "vertical-align":               [ "percentage", "length", "baseline | sub | super | top | text-top | middle | bottom | text-bottom | inherit" ],
    "visibility":                   [ "visible | hidden | collapse | inherit" ],
    "voice-balance": 1,
    "voice-duration": 1,
    "voice-family": 1,
    "voice-pitch": 1,
    "voice-pitch-range": 1,
    "voice-rate": 1,
    "voice-stress": 1,
    "voice-volume": 1,
    "volume": 1,
    
    //W
    "white-space":                  [ "normal | pre | nowrap | pre-wrap | pre-line | inherit" ],
    "white-space-collapse": 1,
    "widows":                       [ "integer", "inherit" ],
    "width":                        [ "length", "percentage", "auto", "inherit" ],
    "word-break":                   [ "normal | keep-all | break-all" ],
    "word-spacing":                 [ "length", "normal | inherit" ],
    "word-wrap": 1,
    
    //Z
    "z-index":                      [ "integer", "auto | inherit" ],
    "zoom":                         [ "number", "percentage", "normal" ]
};

//Create validation functions for strings
(function(){
    var prop;
    for (prop in Properties){
        if (Properties.hasOwnProperty(prop)){
            if (Properties[prop] instanceof Array){
                Properties[prop] = (function(values){
                    return function(value){
                        var valid   = false,
                            msg     = [],
                            part    = value.parts[0];
                        
                        if (value.parts.length != 1){
                            throw new ValidationError("Expected 1 value but found " + value.parts.length + ".", value.line, value.col);
                        }
                        
                        for (var i=0, len=values.length; i < len && !valid; i++){
                            if (typeof ValidationType[values[i]] == "undefined"){
                                valid = valid || ValidationType.identifier(part, values[i]);
                                msg.push("one of (" + values[i] + ")");
                            } else {
                                valid = valid || ValidationType[values[i]](part);
                                msg.push(values[i]);
                            }
                        }
                        
                        if (!valid){
                            throw new ValidationError("Expected " + msg.join(" or ") + " but found '" + value + "'.", value.line, value.col);
                        }
                    };
                })(Properties[prop]);
            } else if (typeof Properties[prop] == "object"){
                Properties[prop] = (function(spec){
                    return function(value){
                        var valid,
                            i, len, j, count,
                            msg,
                            values,
                            last,
                            parts   = value.parts;
                        
                        //if there's a maximum set, use it (max can't be 0)
                        if (spec.max) {
                            if (parts.length > spec.max){
                                throw new ValidationError("Expected a max of " + spec.max + " property values but found " + parts.length + ".", value.line, value.col);
                            }
                        }
                        
                        if (spec.multi){
                            values = spec.multi;                            
                        }
                        
                        for (i=0, len=parts.length; i < len; i++){
                            msg = [];
                            valid = false;
                            
                            if (spec.separator && parts[i].type == "operator"){
                                
                                //two operators in a row - not allowed?
                                if ((last && last.type == "operator")){
                                    msg = msg.concat(values);
                                } else if (i == len-1){
                                    msg = msg.concat("end of line");
                                } else if (parts[i] != spec.separator){
                                    msg.push("'" + spec.separator + "'");
                                } else {
                                    valid = true;
                                }
                            } else {

                                for (j=0, count=values.length; j < count; j++){
                                    if (typeof ValidationType[values[j]] == "undefined"){
                                        if(ValidationType.identifier(parts[i], values[j])){
                                            valid = true;
                                            break;
                                        }
                                        msg.push("one of (" + values[j] + ")");
                                    } else {
                                        if (ValidationType[values[j]](parts[i])){
                                            valid = true;
                                            break;
                                        }
                                        msg.push(values[j]);
                                    }                                   
                                }
                            }

                            
                            if (!valid) {
                                throw new ValidationError("Expected " + msg.join(" or ") + " but found '" + parts[i] + "'.", value.line, value.col);
                            }
                            
                            
                            last = parts[i];
                        }                

                    };
                })(Properties[prop]);                
            }
        }
    }
})();
/**
 * Represents a selector combinator (whitespace, +, >).
 * @namespace parserlib.css
 * @class PropertyName
 * @extends parserlib.util.SyntaxUnit
 * @constructor
 * @param {String} text The text representation of the unit. 
 * @param {String} hack The type of IE hack applied ("*", "_", or null).
 * @param {int} line The line of text on which the unit resides.
 * @param {int} col The column of text on which the unit resides.
 */
function PropertyName(text, hack, line, col){
    
    SyntaxUnit.call(this, text, line, col, Parser.PROPERTY_NAME_TYPE);

    /**
     * The type of IE hack applied ("*", "_", or null).
     * @type String
     * @property hack
     */
    this.hack = hack;

}

PropertyName.prototype = new SyntaxUnit();
PropertyName.prototype.constructor = PropertyName;
PropertyName.prototype.toString = function(){
    return (this.hack ? this.hack : "") + this.text;
};
/**
 * Represents a single part of a CSS property value, meaning that it represents
 * just everything single part between ":" and ";". If there are multiple values
 * separated by commas, this type represents just one of the values.
 * @param {String[]} parts An array of value parts making up this value.
 * @param {int} line The line of text on which the unit resides.
 * @param {int} col The column of text on which the unit resides.
 * @namespace parserlib.css
 * @class PropertyValue
 * @extends parserlib.util.SyntaxUnit
 * @constructor
 */
function PropertyValue(parts, line, col){

    SyntaxUnit.call(this, parts.join(" "), line, col, Parser.PROPERTY_VALUE_TYPE);
    
    /**
     * The parts that make up the selector.
     * @type Array
     * @property parts
     */
    this.parts = parts;
    
}

PropertyValue.prototype = new SyntaxUnit();
PropertyValue.prototype.constructor = PropertyValue;

/**
 * Represents a single part of a CSS property value, meaning that it represents
 * just one part of the data between ":" and ";".
 * @param {String} text The text representation of the unit.
 * @param {int} line The line of text on which the unit resides.
 * @param {int} col The column of text on which the unit resides.
 * @namespace parserlib.css
 * @class PropertyValuePart
 * @extends parserlib.util.SyntaxUnit
 * @constructor
 */
function PropertyValuePart(text, line, col){

    SyntaxUnit.call(this, text, line, col, Parser.PROPERTY_VALUE_PART_TYPE);
    
    /**
     * Indicates the type of value unit.
     * @type String
     * @property type
     */
    this.type = "unknown";

    //figure out what type of data it is
    
    var temp;
    
    //it is a measurement?
    if (/^([+\-]?[\d\.]+)([a-z]+)$/i.test(text)){  //dimension
        this.type = "dimension";
        this.value = +RegExp.$1;
        this.units = RegExp.$2;
        
        //try to narrow down
        switch(this.units.toLowerCase()){
        
            case "em":
            case "rem":
            case "ex":
            case "px":
            case "cm":
            case "mm":
            case "in":
            case "pt":
            case "pc":
                this.type = "length";
                break;
                
            case "deg":
            case "rad":
            case "grad":
                this.type = "angle";
                break;
            
            case "ms":
            case "s":
                this.type = "time";
                break;
            
            case "hz":
            case "khz":
                this.type = "frequency";
                break;
            
            case "dpi":
            case "dpcm":
                this.type = "resolution";
                break;
                
            //default
                
        }
        
    } else if (/^([+\-]?[\d\.]+)%$/i.test(text)){  //percentage
        this.type = "percentage";
        this.value = +RegExp.$1;
    } else if (/^([+\-]?[\d\.]+)%$/i.test(text)){  //percentage
        this.type = "percentage";
        this.value = +RegExp.$1;
    } else if (/^([+\-]?\d+)$/i.test(text)){  //integer
        this.type = "integer";
        this.value = +RegExp.$1;
    } else if (/^([+\-]?[\d\.]+)$/i.test(text)){  //number
        this.type = "number";
        this.value = +RegExp.$1;
    
    } else if (/^#([a-f0-9]{3,6})/i.test(text)){  //hexcolor
        this.type = "color";
        temp = RegExp.$1;
        if (temp.length == 3){
            this.red    = parseInt(temp.charAt(0)+temp.charAt(0),16);
            this.green  = parseInt(temp.charAt(1)+temp.charAt(1),16);
            this.blue   = parseInt(temp.charAt(2)+temp.charAt(2),16);            
        } else {
            this.red    = parseInt(temp.substring(0,2),16);
            this.green  = parseInt(temp.substring(2,4),16);
            this.blue   = parseInt(temp.substring(4,6),16);            
        }
    } else if (/^rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)/i.test(text)){ //rgb() color with absolute numbers
        this.type   = "color";
        this.red    = +RegExp.$1;
        this.green  = +RegExp.$2;
        this.blue   = +RegExp.$3;
    } else if (/^rgb\(\s*(\d+)%\s*,\s*(\d+)%\s*,\s*(\d+)%\s*\)/i.test(text)){ //rgb() color with percentages
        this.type   = "color";
        this.red    = +RegExp.$1 * 255 / 100;
        this.green  = +RegExp.$2 * 255 / 100;
        this.blue   = +RegExp.$3 * 255 / 100;
    } else if (/^rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([\d\.]+)\s*\)/i.test(text)){ //rgba() color with absolute numbers
        this.type   = "color";
        this.red    = +RegExp.$1;
        this.green  = +RegExp.$2;
        this.blue   = +RegExp.$3;
        this.alpha  = +RegExp.$4;
    } else if (/^rgba\(\s*(\d+)%\s*,\s*(\d+)%\s*,\s*(\d+)%\s*,\s*([\d\.]+)\s*\)/i.test(text)){ //rgba() color with percentages
        this.type   = "color";
        this.red    = +RegExp.$1 * 255 / 100;
        this.green  = +RegExp.$2 * 255 / 100;
        this.blue   = +RegExp.$3 * 255 / 100;
        this.alpha  = +RegExp.$4;        
    } else if (/^hsl\(\s*(\d+)\s*,\s*(\d+)%\s*,\s*(\d+)%\s*\)/i.test(text)){ //hsl()
        this.type   = "color";
        this.hue    = +RegExp.$1;
        this.saturation = +RegExp.$2 / 100;
        this.lightness  = +RegExp.$3 / 100;        
    } else if (/^hsla\(\s*(\d+)\s*,\s*(\d+)%\s*,\s*(\d+)%\s*,\s*([\d\.]+)\s*\)/i.test(text)){ //hsla() color with percentages
        this.type   = "color";
        this.hue    = +RegExp.$1;
        this.saturation = +RegExp.$2 / 100;
        this.lightness  = +RegExp.$3 / 100;        
        this.alpha  = +RegExp.$4;        
    } else if (/^url\(["']?([^\)"']+)["']?\)/i.test(text)){ //URI
        this.type   = "uri";
        this.uri    = RegExp.$1;
    } else if (/^["'][^"']*["']/.test(text)){    //string
        this.type   = "string";
        this.value  = eval(text);
    } else if (Colors[text.toLowerCase()]){  //named color
        this.type   = "color";
        temp        = Colors[text.toLowerCase()].substring(1);
        this.red    = parseInt(temp.substring(0,2),16);
        this.green  = parseInt(temp.substring(2,4),16);
        this.blue   = parseInt(temp.substring(4,6),16);         
    } else if (/^[\,\/]$/.test(text)){
        this.type   = "operator";
        this.value  = text;
    } else if (/^[a-z\-\u0080-\uFFFF][a-z0-9\-\u0080-\uFFFF]*$/i.test(text)){
        this.type   = "identifier";
        this.value  = text;
    }

}

PropertyValuePart.prototype = new SyntaxUnit();
PropertyValuePart.prototype.constructor = PropertyValue;

/**
 * Create a new syntax unit based solely on the given token.
 * Convenience method for creating a new syntax unit when
 * it represents a single token instead of multiple.
 * @param {Object} token The token object to represent.
 * @return {parserlib.css.PropertyValuePart} The object representing the token.
 * @static
 * @method fromToken
 */
PropertyValuePart.fromToken = function(token){
    return new PropertyValuePart(token.value, token.startLine, token.startCol);
};
var Pseudos = {
    ":first-letter": 1,
    ":first-line":   1,
    ":before":       1,
    ":after":        1
};

Pseudos.ELEMENT = 1;
Pseudos.CLASS = 2;

Pseudos.isElement = function(pseudo){
    return pseudo.indexOf("::") === 0 || Pseudos[pseudo.toLowerCase()] == Pseudos.ELEMENT;
};
/**
 * Represents an entire single selector, including all parts but not
 * including multiple selectors (those separated by commas).
 * @namespace parserlib.css
 * @class Selector
 * @extends parserlib.util.SyntaxUnit
 * @constructor
 * @param {Array} parts Array of selectors parts making up this selector.
 * @param {int} line The line of text on which the unit resides.
 * @param {int} col The column of text on which the unit resides.
 */
function Selector(parts, line, col){
    
    SyntaxUnit.call(this, parts.join(" "), line, col, Parser.SELECTOR_TYPE);
    
    /**
     * The parts that make up the selector.
     * @type Array
     * @property parts
     */
    this.parts = parts;
    
    /**
     * The specificity of the selector.
     * @type parserlib.css.Specificity
     * @property specificity
     */
    this.specificity = Specificity.calculate(this);

}

Selector.prototype = new SyntaxUnit();
Selector.prototype.constructor = Selector;

/**
 * Represents a single part of a selector string, meaning a single set of
 * element name and modifiers. This does not include combinators such as
 * spaces, +, >, etc.
 * @namespace parserlib.css
 * @class SelectorPart
 * @extends parserlib.util.SyntaxUnit
 * @constructor
 * @param {String} elementName The element name in the selector or null
 *      if there is no element name.
 * @param {Array} modifiers Array of individual modifiers for the element.
 *      May be empty if there are none.
 * @param {String} text The text representation of the unit. 
 * @param {int} line The line of text on which the unit resides.
 * @param {int} col The column of text on which the unit resides.
 */
function SelectorPart(elementName, modifiers, text, line, col){
    
    SyntaxUnit.call(this, text, line, col, Parser.SELECTOR_PART_TYPE);

    /**
     * The tag name of the element to which this part
     * of the selector affects.
     * @type String
     * @property elementName
     */
    this.elementName = elementName;
    
    /**
     * The parts that come after the element name, such as class names, IDs,
     * pseudo classes/elements, etc.
     * @type Array
     * @property modifiers
     */
    this.modifiers = modifiers;

}

SelectorPart.prototype = new SyntaxUnit();
SelectorPart.prototype.constructor = SelectorPart;

/**
 * Represents a selector modifier string, meaning a class name, element name,
 * element ID, pseudo rule, etc.
 * @namespace parserlib.css
 * @class SelectorSubPart
 * @extends parserlib.util.SyntaxUnit
 * @constructor
 * @param {String} text The text representation of the unit. 
 * @param {String} type The type of selector modifier.
 * @param {int} line The line of text on which the unit resides.
 * @param {int} col The column of text on which the unit resides.
 */
function SelectorSubPart(text, type, line, col){
    
    SyntaxUnit.call(this, text, line, col, Parser.SELECTOR_SUB_PART_TYPE);

    /**
     * The type of modifier.
     * @type String
     * @property type
     */
    this.type = type;
    
    /**
     * Some subparts have arguments, this represents them.
     * @type Array
     * @property args
     */
    this.args = [];

}

SelectorSubPart.prototype = new SyntaxUnit();
SelectorSubPart.prototype.constructor = SelectorSubPart;

/**
 * Represents a selector's specificity.
 * @namespace parserlib.css
 * @class Specificity
 * @constructor
 * @param {int} a Should be 1 for inline styles, zero for stylesheet styles
 * @param {int} b Number of ID selectors
 * @param {int} c Number of classes and pseudo classes
 * @param {int} d Number of element names and pseudo elements
 */
function Specificity(a, b, c, d){
    this.a = a;
    this.b = b;
    this.c = c;
    this.d = d;
}

Specificity.prototype = {
    constructor: Specificity,
    
    /**
     * Compare this specificity to another.
     * @param {Specificity} other The other specificity to compare to.
     * @return {int} -1 if the other specificity is larger, 1 if smaller, 0 if equal.
     * @method compare
     */
    compare: function(other){
        var comps = ["a", "b", "c", "d"],
            i, len;
            
        for (i=0, len=comps.length; i < len; i++){
            if (this[comps[i]] < other[comps[i]]){
                return -1;
            } else if (this[comps[i]] > other[comps[i]]){
                return 1;
            }
        }
        
        return 0;
    },
    
    /**
     * Creates a numeric value for the specificity.
     * @return {int} The numeric value for the specificity.
     * @method valueOf
     */
    valueOf: function(){
        return (this.a * 1000) + (this.b * 100) + (this.c * 10) + this.d;
    },
    
    /**
     * Returns a string representation for specificity.
     * @return {String} The string representation of specificity.
     * @method toString
     */
    toString: function(){
        return this.a + "," + this.b + "," + this.c + "," + this.d;
    }

};

/**
 * Calculates the specificity of the given selector.
 * @param {parserlib.css.Selector} The selector to calculate specificity for.
 * @return {parserlib.css.Specificity} The specificity of the selector.
 * @static
 * @method calculate
 */
Specificity.calculate = function(selector){

    var i, len,
        b=0, c=0, d=0;
        
    function updateValues(part){
    
        var i, j, len, num,
            modifier;
    
        if (part.elementName && part.text.charAt(part.text.length-1) != "*") {
            d++;
        }    
    
        for (i=0, len=part.modifiers.length; i < len; i++){
            modifier = part.modifiers[i];
            switch(modifier.type){
                case "class":
                case "attribute":
                    c++;
                    break;
                    
                case "id":
                    b++;
                    break;
                    
                case "pseudo":
                    if (Pseudos.isElement(modifier.text)){
                        d++;
                    } else {
                        c++;
                    }                    
                    break;
                    
                case "not":
                    for (j=0, num=modifier.args.length; j < num; j++){
                        updateValues(modifier.args[j]);
                    }
            }    
         }
    }
    
    for (i=0, len=selector.parts.length; i < len; i++){
        part = selector.parts[i];
        
        if (part instanceof SelectorPart){
            updateValues(part);                
        }
    }
    
    return new Specificity(0, b, c, d);
};


var h = /^[0-9a-fA-F]$/,
    nonascii = /^[\u0080-\uFFFF]$/,
    nl = /\n|\r\n|\r|\f/;

//-----------------------------------------------------------------------------
// Helper functions
//-----------------------------------------------------------------------------


function isHexDigit(c){
    return c != null && h.test(c);
}

function isDigit(c){
    return c != null && /\d/.test(c);
}

function isWhitespace(c){
    return c != null && /\s/.test(c);
}

function isNewLine(c){
    return c != null && nl.test(c);
}

function isNameStart(c){
    return c != null && (/[a-z_\u0080-\uFFFF\\]/i.test(c));
}

function isNameChar(c){
    return c != null && (isNameStart(c) || /[0-9\-\\]/.test(c));
}

function isIdentStart(c){
    return c != null && (isNameStart(c) || /\-\\/.test(c));
}

function mix(receiver, supplier){
	for (var prop in supplier){
		if (supplier.hasOwnProperty(prop)){
			receiver[prop] = supplier[prop];
		}
	}
	return receiver;
}

//-----------------------------------------------------------------------------
// CSS Token Stream
//-----------------------------------------------------------------------------


/**
 * A token stream that produces CSS tokens.
 * @param {String|Reader} input The source of text to tokenize.
 * @constructor
 * @class TokenStream
 * @namespace parserlib.css
 */
function TokenStream(input){
	TokenStreamBase.call(this, input, Tokens);
}

TokenStream.prototype = mix(new TokenStreamBase(), {

    /**
     * Overrides the TokenStreamBase method of the same name
     * to produce CSS tokens.
     * @param {variant} channel The name of the channel to use
     *      for the next token.
     * @return {Object} A token object representing the next token.
     * @method _getToken
     * @private
     */
    _getToken: function(channel){

        var c,
            reader = this._reader,
            token   = null,
            startLine   = reader.getLine(),
            startCol    = reader.getCol();

        c = reader.read();


        while(c){
            switch(c){

                /*
                 * Potential tokens:
                 * - COMMENT
                 * - SLASH
                 * - CHAR
                 */
                case "/":

                    if(reader.peek() == "*"){
                        token = this.commentToken(c, startLine, startCol);
                    } else {
                        token = this.charToken(c, startLine, startCol);
                    }
                    break;

                /*
                 * Potential tokens:
                 * - DASHMATCH
                 * - INCLUDES
                 * - PREFIXMATCH
                 * - SUFFIXMATCH
                 * - SUBSTRINGMATCH
                 * - CHAR
                 */
                case "|":
                case "~":
                case "^":
                case "$":
                case "*":
                    if(reader.peek() == "="){
                        token = this.comparisonToken(c, startLine, startCol);
                    } else {
                        token = this.charToken(c, startLine, startCol);
                    }
                    break;

                /*
                 * Potential tokens:
                 * - STRING
                 * - INVALID
                 */
                case "\"":
                case "'":
                    token = this.stringToken(c, startLine, startCol);
                    break;

                /*
                 * Potential tokens:
                 * - HASH
                 * - CHAR
                 */
                case "#":
                    if (isNameChar(reader.peek())){
                        token = this.hashToken(c, startLine, startCol);
                    } else {
                        token = this.charToken(c, startLine, startCol);
                    }
                    break;

                /*
                 * Potential tokens:
                 * - DOT
                 * - NUMBER
                 * - DIMENSION
                 * - PERCENTAGE
                 */
                case ".":
                    if (isDigit(reader.peek())){
                        token = this.numberToken(c, startLine, startCol);
                    } else {
                        token = this.charToken(c, startLine, startCol);
                    }
                    break;

                /*
                 * Potential tokens:
                 * - CDC
                 * - MINUS
                 * - NUMBER
                 * - DIMENSION
                 * - PERCENTAGE
                 */
                case "-":
                    if (reader.peek() == "-"){  //could be closing HTML-style comment
                        token = this.htmlCommentEndToken(c, startLine, startCol);
                    } else if (isNameStart(reader.peek())){
                        token = this.identOrFunctionToken(c, startLine, startCol);
                    } else {
                        token = this.charToken(c, startLine, startCol);
                    }
                    break;

                /*
                 * Potential tokens:
                 * - IMPORTANT_SYM
                 * - CHAR
                 */
                case "!":
                    token = this.importantToken(c, startLine, startCol);
                    break;

                /*
                 * Any at-keyword or CHAR
                 */
                case "@":
                    token = this.atRuleToken(c, startLine, startCol);
                    break;

                /*
                 * Potential tokens:
                 * - NOT
                 * - CHAR
                 */
                case ":":
                    token = this.notToken(c, startLine, startCol);
                    break;

                /*
                 * Potential tokens:
                 * - CDO
                 * - CHAR
                 */
                case "<":
                    token = this.htmlCommentStartToken(c, startLine, startCol);
                    break;

                /*
                 * Potential tokens:
                 * - UNICODE_RANGE
                 * - URL
                 * - CHAR
                 */
                case "U":
                case "u":
                    if (reader.peek() == "+"){
                        token = this.unicodeRangeToken(c, startLine, startCol);
                        break;
                    }
                    /*falls through*/

                default:

                    /*
                     * Potential tokens:
                     * - NUMBER
                     * - DIMENSION
                     * - LENGTH
                     * - FREQ
                     * - TIME
                     * - EMS
                     * - EXS
                     * - ANGLE
                     */
                    if (isDigit(c)){
                        token = this.numberToken(c, startLine, startCol);
                    } else

                    /*
                     * Potential tokens:
                     * - S
                     */
                    if (isWhitespace(c)){
                        token = this.whitespaceToken(c, startLine, startCol);
                    } else

                    /*
                     * Potential tokens:
                     * - IDENT
                     */
                    if (isIdentStart(c)){
                        token = this.identOrFunctionToken(c, startLine, startCol);
                    } else

                    /*
                     * Potential tokens:
                     * - CHAR
                     * - PLUS
                     */
                    {
                        token = this.charToken(c, startLine, startCol);
                    }






            }

            //make sure this token is wanted
            //TODO: check channel
            break;

            c = reader.read();
        }

        if (!token && c == null){
            token = this.createToken(Tokens.EOF,null,startLine,startCol);
        }

        return token;
    },

    //-------------------------------------------------------------------------
    // Methods to create tokens
    //-------------------------------------------------------------------------

    /**
     * Produces a token based on available data and the current
     * reader position information. This method is called by other
     * private methods to create tokens and is never called directly.
     * @param {int} tt The token type.
     * @param {String} value The text value of the token.
     * @param {int} startLine The beginning line for the character.
     * @param {int} startCol The beginning column for the character.
     * @param {Object} options (Optional) Specifies a channel property
     *      to indicate that a different channel should be scanned
     *      and/or a hide property indicating that the token should
     *      be hidden.
     * @return {Object} A token object.
     * @method createToken
     */
    createToken: function(tt, value, startLine, startCol, options){
        var reader = this._reader;
        options = options || {};

        return {
            value:      value,
            type:       tt,
            channel:    options.channel,
            hide:       options.hide || false,
            startLine:  startLine,
            startCol:   startCol,
            endLine:    reader.getLine(),
            endCol:     reader.getCol()
        };
    },

    //-------------------------------------------------------------------------
    // Methods to create specific tokens
    //-------------------------------------------------------------------------

    /**
     * Produces a token for any at-rule. If the at-rule is unknown, then
     * the token is for a single "@" character.
     * @param {String} first The first character for the token.
     * @param {int} startLine The beginning line for the character.
     * @param {int} startCol The beginning column for the character.
     * @return {Object} A token object.
     * @method atRuleToken
     */
    atRuleToken: function(first, startLine, startCol){
        var rule    = first,
            reader  = this._reader,
            tt      = Tokens.CHAR,
            valid   = false,
            ident,
            c;

        /*
         * First, mark where we are. There are only four @ rules,
         * so anything else is really just an invalid token.
         * Basically, if this doesn't match one of the known @
         * rules, just return '@' as an unknown token and allow
         * parsing to continue after that point.
         */
        reader.mark();

        //try to find the at-keyword
        ident = this.readName();
        rule = first + ident;
        tt = Tokens.type(rule.toLowerCase());

        //if it's not valid, use the first character only and reset the reader
        if (tt == Tokens.CHAR || tt == Tokens.UNKNOWN){
            tt = Tokens.CHAR;
            rule = first;
            reader.reset();
        }

        return this.createToken(tt, rule, startLine, startCol);
    },

    /**
     * Produces a character token based on the given character
     * and location in the stream. If there's a special (non-standard)
     * token name, this is used; otherwise CHAR is used.
     * @param {String} c The character for the token.
     * @param {int} startLine The beginning line for the character.
     * @param {int} startCol The beginning column for the character.
     * @return {Object} A token object.
     * @method charToken
     */
    charToken: function(c, startLine, startCol){
        var tt = Tokens.type(c);

        if (tt == -1){
            tt = Tokens.CHAR;
        }

        return this.createToken(tt, c, startLine, startCol);
    },

    /**
     * Produces a character token based on the given character
     * and location in the stream. If there's a special (non-standard)
     * token name, this is used; otherwise CHAR is used.
     * @param {String} first The first character for the token.
     * @param {int} startLine The beginning line for the character.
     * @param {int} startCol The beginning column for the character.
     * @return {Object} A token object.
     * @method commentToken
     */
    commentToken: function(first, startLine, startCol){
        var reader  = this._reader,
            comment = this.readComment(first);

        return this.createToken(Tokens.COMMENT, comment, startLine, startCol);
    },

    /**
     * Produces a comparison token based on the given character
     * and location in the stream. The next character must be
     * read and is already known to be an equals sign.
     * @param {String} c The character for the token.
     * @param {int} startLine The beginning line for the character.
     * @param {int} startCol The beginning column for the character.
     * @return {Object} A token object.
     * @method comparisonToken
     */
    comparisonToken: function(c, startLine, startCol){
        var reader  = this._reader,
            comparison  = c + reader.read(),
            tt      = Tokens.type(comparison) || Tokens.CHAR;

        return this.createToken(tt, comparison, startLine, startCol);
    },

    /**
     * Produces a hash token based on the specified information. The
     * first character provided is the pound sign (#) and then this
     * method reads a name afterward.
     * @param {String} first The first character (#) in the hash name.
     * @param {int} startLine The beginning line for the character.
     * @param {int} startCol The beginning column for the character.
     * @return {Object} A token object.
     * @method hashToken
     */
    hashToken: function(first, startLine, startCol){
        var reader  = this._reader,
            name    = this.readName(first);

        return this.createToken(Tokens.HASH, name, startLine, startCol);
    },

    /**
     * Produces a CDO or CHAR token based on the specified information. The
     * first character is provided and the rest is read by the function to determine
     * the correct token to create.
     * @param {String} first The first character in the token.
     * @param {int} startLine The beginning line for the character.
     * @param {int} startCol The beginning column for the character.
     * @return {Object} A token object.
     * @method htmlCommentStartToken
     */
    htmlCommentStartToken: function(first, startLine, startCol){
        var reader      = this._reader,
            text        = first;

        reader.mark();
        text += reader.readCount(3);

        if (text == "<!--"){
            return this.createToken(Tokens.CDO, text, startLine, startCol);
        } else {
            reader.reset();
            return this.charToken(first, startLine, startCol);
        }
    },

    /**
     * Produces a CDC or CHAR token based on the specified information. The
     * first character is provided and the rest is read by the function to determine
     * the correct token to create.
     * @param {String} first The first character in the token.
     * @param {int} startLine The beginning line for the character.
     * @param {int} startCol The beginning column for the character.
     * @return {Object} A token object.
     * @method htmlCommentEndToken
     */
    htmlCommentEndToken: function(first, startLine, startCol){
        var reader      = this._reader,
            text        = first;

        reader.mark();
        text += reader.readCount(2);

        if (text == "-->"){
            return this.createToken(Tokens.CDC, text, startLine, startCol);
        } else {
            reader.reset();
            return this.charToken(first, startLine, startCol);
        }
    },

    /**
     * Produces an IDENT or FUNCTION token based on the specified information. The
     * first character is provided and the rest is read by the function to determine
     * the correct token to create.
     * @param {String} first The first character in the identifier.
     * @param {int} startLine The beginning line for the character.
     * @param {int} startCol The beginning column for the character.
     * @return {Object} A token object.
     * @method identOrFunctionToken
     */
    identOrFunctionToken: function(first, startLine, startCol){
        var reader  = this._reader,
            ident   = this.readName(first),
            tt      = Tokens.IDENT;

        //if there's a left paren immediately after, it's a URI or function
        if (reader.peek() == "("){
            ident += reader.read();
            if (ident.toLowerCase() == "url("){
                tt = Tokens.URI;
                ident = this.readURI(ident);

                //didn't find a valid URL or there's no closing paren
                if (ident.toLowerCase() == "url("){
                    tt = Tokens.FUNCTION;
                }
            } else {
                tt = Tokens.FUNCTION;
            }
        } else if (reader.peek() == ":"){  //might be an IE function

            //IE-specific functions always being with progid:
            if (ident.toLowerCase() == "progid"){
                ident += reader.readTo("(");
                tt = Tokens.IE_FUNCTION;
            }
        }

        return this.createToken(tt, ident, startLine, startCol);
    },

    /**
     * Produces an IMPORTANT_SYM or CHAR token based on the specified information. The
     * first character is provided and the rest is read by the function to determine
     * the correct token to create.
     * @param {String} first The first character in the token.
     * @param {int} startLine The beginning line for the character.
     * @param {int} startCol The beginning column for the character.
     * @return {Object} A token object.
     * @method importantToken
     */
    importantToken: function(first, startLine, startCol){
        var reader      = this._reader,
            important   = first,
            tt          = Tokens.CHAR,
            temp,
            c;

        reader.mark();
        c = reader.read();

        while(c){

            //there can be a comment in here
            if (c == "/"){

                //if the next character isn't a star, then this isn't a valid !important token
                if (reader.peek() != "*"){
                    break;
                } else {
                    temp = this.readComment(c);
                    if (temp == ""){    //broken!
                        break;
                    }
                }
            } else if (isWhitespace(c)){
                important += c + this.readWhitespace();
            } else if (/i/i.test(c)){
                temp = reader.readCount(8);
                if (/mportant/i.test(temp)){
                    important += c + temp;
                    tt = Tokens.IMPORTANT_SYM;

                }
                break;  //we're done
            } else {
                break;
            }

            c = reader.read();
        }

        if (tt == Tokens.CHAR){
            reader.reset();
            return this.charToken(first, startLine, startCol);
        } else {
            return this.createToken(tt, important, startLine, startCol);
        }


    },

    /**
     * Produces a NOT or CHAR token based on the specified information. The
     * first character is provided and the rest is read by the function to determine
     * the correct token to create.
     * @param {String} first The first character in the token.
     * @param {int} startLine The beginning line for the character.
     * @param {int} startCol The beginning column for the character.
     * @return {Object} A token object.
     * @method notToken
     */
    notToken: function(first, startLine, startCol){
        var reader      = this._reader,
            text        = first;

        reader.mark();
        text += reader.readCount(4);

        if (text.toLowerCase() == ":not("){
            return this.createToken(Tokens.NOT, text, startLine, startCol);
        } else {
            reader.reset();
            return this.charToken(first, startLine, startCol);
        }
    },

    /**
     * Produces a number token based on the given character
     * and location in the stream. This may return a token of
     * NUMBER, EMS, EXS, LENGTH, ANGLE, TIME, FREQ, DIMENSION,
     * or PERCENTAGE.
     * @param {String} first The first character for the token.
     * @param {int} startLine The beginning line for the character.
     * @param {int} startCol The beginning column for the character.
     * @return {Object} A token object.
     * @method numberToken
     */
    numberToken: function(first, startLine, startCol){
        var reader  = this._reader,
            value   = this.readNumber(first),
            ident,
            tt      = Tokens.NUMBER,
            c       = reader.peek();

        if (isIdentStart(c)){
            ident = this.readName(reader.read());
            value += ident;

            if (/^em$|^ex$|^px$|^gd$|^rem$|^vw$|^vh$|^vm$|^ch$|^cm$|^mm$|^in$|^pt$|^pc$/i.test(ident)){
                tt = Tokens.LENGTH;
            } else if (/^deg|^rad$|^grad$/i.test(ident)){
                tt = Tokens.ANGLE;
            } else if (/^ms$|^s$/i.test(ident)){
                tt = Tokens.TIME;
            } else if (/^hz$|^khz$/i.test(ident)){
                tt = Tokens.FREQ;
            } else if (/^dpi$|^dpcm$/i.test(ident)){
                tt = Tokens.RESOLUTION;
            } else {
                tt = Tokens.DIMENSION;
            }

        } else if (c == "%"){
            value += reader.read();
            tt = Tokens.PERCENTAGE;
        }

        return this.createToken(tt, value, startLine, startCol);
    },

    /**
     * Produces a string token based on the given character
     * and location in the stream. Since strings may be indicated
     * by single or double quotes, a failure to match starting
     * and ending quotes results in an INVALID token being generated.
     * The first character in the string is passed in and then
     * the rest are read up to and including the final quotation mark.
     * @param {String} first The first character in the string.
     * @param {int} startLine The beginning line for the character.
     * @param {int} startCol The beginning column for the character.
     * @return {Object} A token object.
     * @method stringToken
     */
    stringToken: function(first, startLine, startCol){
        var delim   = first,
            string  = first,
            reader  = this._reader,
            prev    = first,
            tt      = Tokens.STRING,
            c       = reader.read();

        while(c){
            string += c;

            //if the delimiter is found with an escapement, we're done.
            if (c == delim && prev != "\\"){
                break;
            }

            //if there's a newline without an escapement, it's an invalid string
            if (isNewLine(reader.peek()) && c != "\\"){
                tt = Tokens.INVALID;
                break;
            }

            //save previous and get next
            prev = c;
            c = reader.read();
        }

        //if c is null, that means we're out of input and the string was never closed
        if (c == null){
            tt = Tokens.INVALID;
        }

        return this.createToken(tt, string, startLine, startCol);
    },

    unicodeRangeToken: function(first, startLine, startCol){
        var reader  = this._reader,
            value   = first,
            temp,
            tt      = Tokens.CHAR;

        //then it should be a unicode range
        if (reader.peek() == "+"){
            reader.mark();
            value += reader.read();
            value += this.readUnicodeRangePart(true);

            //ensure there's an actual unicode range here
            if (value.length == 2){
                reader.reset();
            } else {

                tt = Tokens.UNICODE_RANGE;

                //if there's a ? in the first part, there can't be a second part
                if (value.indexOf("?") == -1){

                    if (reader.peek() == "-"){
                        reader.mark();
                        temp = reader.read();
                        temp += this.readUnicodeRangePart(false);

                        //if there's not another value, back up and just take the first
                        if (temp.length == 1){
                            reader.reset();
                        } else {
                            value += temp;
                        }
                    }

                }
            }
        }

        return this.createToken(tt, value, startLine, startCol);
    },

    /**
     * Produces a S token based on the specified information. Since whitespace
     * may have multiple characters, this consumes all whitespace characters
     * into a single token.
     * @param {String} first The first character in the token.
     * @param {int} startLine The beginning line for the character.
     * @param {int} startCol The beginning column for the character.
     * @return {Object} A token object.
     * @method whitespaceToken
     */
    whitespaceToken: function(first, startLine, startCol){
        var reader  = this._reader,
            value   = first + this.readWhitespace();
        return this.createToken(Tokens.S, value, startLine, startCol);
    },




    //-------------------------------------------------------------------------
    // Methods to read values from the string stream
    //-------------------------------------------------------------------------

    readUnicodeRangePart: function(allowQuestionMark){
        var reader  = this._reader,
            part = "",
            c       = reader.peek();

        //first read hex digits
        while(isHexDigit(c) && part.length < 6){
            reader.read();
            part += c;
            c = reader.peek();
        }

        //then read question marks if allowed
        if (allowQuestionMark){
            while(c == "?" && part.length < 6){
                reader.read();
                part += c;
                c = reader.peek();
            }
        }

        //there can't be any other characters after this point

        return part;
    },

    readWhitespace: function(){
        var reader  = this._reader,
            whitespace = "",
            c       = reader.peek();

        while(isWhitespace(c)){
            reader.read();
            whitespace += c;
            c = reader.peek();
        }

        return whitespace;
    },
    readNumber: function(first){
        var reader  = this._reader,
            number  = first,
            hasDot  = (first == "."),
            c       = reader.peek();


        while(c){
            if (isDigit(c)){
                number += reader.read();
            } else if (c == "."){
                if (hasDot){
                    break;
                } else {
                    hasDot = true;
                    number += reader.read();
                }
            } else {
                break;
            }

            c = reader.peek();
        }

        return number;
    },
    readString: function(){
        var reader  = this._reader,
            delim   = reader.read(),
            string  = delim,
            prev    = delim,
            c       = reader.peek();

        while(c){
            c = reader.read();
            string += c;

            //if the delimiter is found with an escapement, we're done.
            if (c == delim && prev != "\\"){
                break;
            }

            //if there's a newline without an escapement, it's an invalid string
            if (isNewLine(reader.peek()) && c != "\\"){
                string = "";
                break;
            }

            //save previous and get next
            prev = c;
            c = reader.peek();
        }

        //if c is null, that means we're out of input and the string was never closed
        if (c == null){
            string = "";
        }

        return string;
    },
    readURI: function(first){
        var reader  = this._reader,
            uri     = first,
            inner   = "",
            c       = reader.peek();

        reader.mark();

        //skip whitespace before
        while(c && isWhitespace(c)){
            reader.read();
            c = reader.peek();
        }

        //it's a string
        if (c == "'" || c == "\""){
            inner = this.readString();
        } else {
            inner = this.readURL();
        }

        c = reader.peek();

        //skip whitespace after
        while(c && isWhitespace(c)){
            reader.read();
            c = reader.peek();
        }

        //if there was no inner value or the next character isn't closing paren, it's not a URI
        if (inner == "" || c != ")"){
            uri = first;
            reader.reset();
        } else {
            uri += inner + reader.read();
        }

        return uri;
    },
    readURL: function(){
        var reader  = this._reader,
            url     = "",
            c       = reader.peek();

        //TODO: Check for escape and nonascii
        while (/^[!#$%&\\*-~]$/.test(c)){
            url += reader.read();
            c = reader.peek();
        }

        return url;

    },
    readName: function(first){
        var reader  = this._reader,
            ident   = first || "",
            c       = reader.peek();

        while(true){
            if (c == "\\"){
                ident += this.readEscape(reader.read());
                c = reader.peek();
            } else if(c && isNameChar(c)){
                ident += reader.read();
                c = reader.peek();
            } else {
                break;
            }
        }

        return ident;
    },
    
    readEscape: function(first){
        var reader  = this._reader,
            cssEscape = first || "",
            i       = 0,
            c       = reader.peek();    
    
        if (isHexDigit(c)){
            do {
                cssEscape += reader.read();
                c = reader.peek();
            } while(c && isHexDigit(c) && ++i < 6);
        }
        
        if (cssEscape.length == 3 && /\s/.test(c) ||
            cssEscape.length == 7 || cssEscape.length == 1){
                reader.read();
        } else {
            c = "";
        }
        
        return cssEscape + c;
    },
    
    readComment: function(first){
        var reader  = this._reader,
            comment = first || "",
            c       = reader.read();

        if (c == "*"){
            while(c){
                comment += c;

                //look for end of comment
                if (comment.length > 2 && c == "*" && reader.peek() == "/"){
                    comment += reader.read();
                    break;
                }

                c = reader.read();
            }

            return comment;
        } else {
            return "";
        }

    }
});

var Tokens  = [

    /*
     * The following token names are defined in CSS3 Grammar: http://www.w3.org/TR/css3-syntax/#lexical
     */
     
    //HTML-style comments
    { name: "CDO"},
    { name: "CDC"},

    //ignorables
    { name: "S", whitespace: true/*, channel: "ws"*/},
    { name: "COMMENT", comment: true, hide: true, channel: "comment" },
        
    //attribute equality
    { name: "INCLUDES", text: "~="},
    { name: "DASHMATCH", text: "|="},
    { name: "PREFIXMATCH", text: "^="},
    { name: "SUFFIXMATCH", text: "$="},
    { name: "SUBSTRINGMATCH", text: "*="},
        
    //identifier types
    { name: "STRING"},     
    { name: "IDENT"},
    { name: "HASH"},

    //at-keywords
    { name: "IMPORT_SYM", text: "@import"},
    { name: "PAGE_SYM", text: "@page"},
    { name: "MEDIA_SYM", text: "@media"},
    { name: "FONT_FACE_SYM", text: "@font-face"},
    { name: "CHARSET_SYM", text: "@charset"},
    { name: "NAMESPACE_SYM", text: "@namespace"},
    //{ name: "ATKEYWORD"},
    
    //CSS3 animations
    { name: "KEYFRAMES_SYM", text: [ "@keyframes", "@-webkit-keyframes", "@-moz-keyframes" ] },

    //important symbol
    { name: "IMPORTANT_SYM"},

    //measurements
    { name: "LENGTH"},
    { name: "ANGLE"},
    { name: "TIME"},
    { name: "FREQ"},
    { name: "DIMENSION"},
    { name: "PERCENTAGE"},
    { name: "NUMBER"},
    
    //functions
    { name: "URI"},
    { name: "FUNCTION"},
    
    //Unicode ranges
    { name: "UNICODE_RANGE"},
    
    /*
     * The following token names are defined in CSS3 Selectors: http://www.w3.org/TR/css3-selectors/#selector-syntax
     */    
    
    //invalid string
    { name: "INVALID"},
    
    //combinators
    { name: "PLUS", text: "+" },
    { name: "GREATER", text: ">"},
    { name: "COMMA", text: ","},
    { name: "TILDE", text: "~"},
    
    //modifier
    { name: "NOT"},        
    
    /*
     * Defined in CSS3 Paged Media
     */
    { name: "TOPLEFTCORNER_SYM", text: "@top-left-corner"},
    { name: "TOPLEFT_SYM", text: "@top-left"},
    { name: "TOPCENTER_SYM", text: "@top-center"},
    { name: "TOPRIGHT_SYM", text: "@top-right"},
    { name: "TOPRIGHTCORNER_SYM", text: "@top-right-corner"},
    { name: "BOTTOMLEFTCORNER_SYM", text: "@bottom-left-corner"},
    { name: "BOTTOMLEFT_SYM", text: "@bottom-left"},
    { name: "BOTTOMCENTER_SYM", text: "@bottom-center"},
    { name: "BOTTOMRIGHT_SYM", text: "@bottom-right"},
    { name: "BOTTOMRIGHTCORNER_SYM", text: "@bottom-right-corner"},
    { name: "LEFTTOP_SYM", text: "@left-top"},
    { name: "LEFTMIDDLE_SYM", text: "@left-middle"},
    { name: "LEFTBOTTOM_SYM", text: "@left-bottom"},
    { name: "RIGHTTOP_SYM", text: "@right-top"},
    { name: "RIGHTMIDDLE_SYM", text: "@right-middle"},
    { name: "RIGHTBOTTOM_SYM", text: "@right-bottom"},

    /*
     * The following token names are defined in CSS3 Media Queries: http://www.w3.org/TR/css3-mediaqueries/#syntax
     */
    /*{ name: "MEDIA_ONLY", state: "media"},
    { name: "MEDIA_NOT", state: "media"},
    { name: "MEDIA_AND", state: "media"},*/
    { name: "RESOLUTION", state: "media"},

    /*
     * The following token names are not defined in any CSS specification but are used by the lexer.
     */
    
    //not a real token, but useful for stupid IE filters
    { name: "IE_FUNCTION" },

    //part of CSS3 grammar but not the Flex code
    { name: "CHAR" },
    
    //TODO: Needed?
    //Not defined as tokens, but might as well be
    {
        name: "PIPE",
        text: "|"
    },
    {
        name: "SLASH",
        text: "/"
    },
    {
        name: "MINUS",
        text: "-"
    },
    {
        name: "STAR",
        text: "*"
    },

    {
        name: "LBRACE",
        text: "{"
    },   
    {
        name: "RBRACE",
        text: "}"
    },      
    {
        name: "LBRACKET",
        text: "["
    },   
    {
        name: "RBRACKET",
        text: "]"
    },    
    {
        name: "EQUALS",
        text: "="
    },
    {
        name: "COLON",
        text: ":"
    },    
    {
        name: "SEMICOLON",
        text: ";"
    },    
 
    {
        name: "LPAREN",
        text: "("
    },   
    {
        name: "RPAREN",
        text: ")"
    },     
    {
        name: "DOT",
        text: "."
    }
];

(function(){

    var nameMap = [],
        typeMap = {};
    
    Tokens.UNKNOWN = -1;
    Tokens.unshift({name:"EOF"});
    for (var i=0, len = Tokens.length; i < len; i++){
        nameMap.push(Tokens[i].name);
        Tokens[Tokens[i].name] = i;
        if (Tokens[i].text){
            if (Tokens[i].text instanceof Array){
                for (var j=0; j < Tokens[i].text.length; j++){
                    typeMap[Tokens[i].text[j]] = i;
                }
            } else {
                typeMap[Tokens[i].text] = i;
            }
        }
    }
    
    Tokens.name = function(tt){
        return nameMap[tt];
    };
    
    Tokens.type = function(c){
        return typeMap[c] || -1;
    };

})();



/**
 * Type to use when a validation error occurs.
 * @class ValidationError
 * @namespace parserlib.util
 * @constructor
 * @param {String} message The error message.
 * @param {int} line The line at which the error occurred.
 * @param {int} col The column at which the error occurred.
 */
function ValidationError(message, line, col){

    /**
     * The column at which the error occurred.
     * @type int
     * @property col
     */
    this.col = col;

    /**
     * The line at which the error occurred.
     * @type int
     * @property line
     */
    this.line = line;

    /**
     * The text representation of the unit.
     * @type String
     * @property text
     */
    this.message = message;

}

//inherit from Error
ValidationError.prototype = new Error();

parserlib.css = {
Colors              :Colors,    
Combinator          :Combinator,                
Parser              :Parser,
PropertyName        :PropertyName,
PropertyValue       :PropertyValue,
PropertyValuePart   :PropertyValuePart,
MediaFeature        :MediaFeature,
MediaQuery          :MediaQuery,
Selector            :Selector,
SelectorPart        :SelectorPart,
SelectorSubPart     :SelectorSubPart,
Specificity         :Specificity,
TokenStream         :TokenStream,
Tokens              :Tokens,
ValidationError     :ValidationError
};
})();

(function(){
for(var prop in parserlib){
exports[prop] = parserlib[prop];                 
}
})();

},{}],33:[function(require,module,exports){
module.exports = {
  Event: require('./Event'),
  UIEvent: require('./UIEvent'),
  MouseEvent: require('./MouseEvent'),
  CustomEvent: require('./CustomEvent')
};

},{"./CustomEvent":5,"./Event":13,"./MouseEvent":19,"./UIEvent":27}],34:[function(require,module,exports){
var Node = require('./Node');
var Element = require('./Element');
var CSSStyleDeclaration = require('./CSSStyleDeclaration');
var NAMESPACE = require('./utils').NAMESPACE;
var attributes = require('./attributes');
var utils = require('./utils');

var impl = exports.elements = {};
var tagNameToImpl = {};

exports.createElement = function(doc, localName, prefix) {
  var impl = tagNameToImpl[localName] || HTMLUnknownElement;
  return new impl(doc, localName, prefix);
};

function define(spec) {
  var c = spec.ctor;
  if (c) {
    var props = spec.props || {};
    if (spec.attributes) {
      for (var n in spec.attributes) {
        var attr = spec.attributes[n];
        if (typeof attr != 'object' || Array.isArray(attr)) attr = {type: attr};
        if (!attr.name) attr.name = n.toLowerCase();
        props[n] = attributes.property(attr);
      }
    }
    props.constructor = { value : c };
    c.prototype = Object.create((spec.superclass || HTMLElement).prototype, props);
    if (spec.events) {
      addEventHandlers(c, spec.events);
    }
    impl[c.name] = c;
  }
  else {
    c = HTMLElement;
  }
  (spec.tags || spec.tag && [spec.tag] || []).forEach(function(tag) {
    tagNameToImpl[tag] = c;
  });
  return c;
}

function EventHandlerBuilder(body, document, form, element) {
  this.body = body;
  this.document = document;
  this.form = form;
  this.element = element;
}

EventHandlerBuilder.prototype.build = function build() {
  try {
    with(this.document.defaultView || {})
      with(this.document)
        with(this.form)
          with(this.element)
            return eval("(function(event){" + this.body + "})");
  }
  catch (err) {
    return function() { throw err }
  }
};

function EventHandlerChangeHandler(elt, name, oldval, newval) {
  var doc = elt.ownerDocument || {};
  var form = elt.form || {};
  elt[name] = new EventHandlerBuilder(newval, doc, form, elt).build();
}

function addEventHandlers(c, eventHandlerTypes) {
  var p = c.prototype;
  eventHandlerTypes.forEach(function(type) {
    // Define the event handler registration IDL attribute for this type
    Object.defineProperty(p, "on" + type, {
      get: function() {
        return this._getEventHandler(type);
      },
      set: function(v) {
        this._setEventHandler(type, v);
      },
    });

    // Define special behavior for the content attribute as well
    attributes.registerChangeHandler(c, "on" + type, EventHandlerChangeHandler);
  });
}

function URL(attr) {
  return {
    get: function() {
      var v = this._getattr(attr);
      return this.doc._resolve(v);
    },
    set: function(value) {
      this._setattr(attr, value);
    }
  };
}

// XXX: the default value for tabIndex should be 0 if the element is
// focusable and -1 if it is not.  But the full definition of focusable
// is actually hard to compute, so for now, I'll follow Firefox and
// just base the default value on the type of the element.
var focusableElements = {
  "A":true, "LINK":true, "BUTTON":true, "INPUT":true,
  "SELECT":true, "TEXTAREA":true, "COMMAND":true
};

var HTMLElement = exports.HTMLElement = define({
  superclass: Element,
  ctor: function HTMLElement(doc, localName, prefix) {
    Element.call(this, doc, localName, NAMESPACE.HTML, prefix);
  },
  props: {
    innerHTML: {
      get: function() {
        return this.serialize();
      },
      set: function(v) {
        var parser = this.ownerDocument.implementation.mozHTMLParser(
          this.ownerDocument._address,
          this);
        parser.parse(v, true);
        var tmpdoc = parser.document();
        var root = tmpdoc.firstChild;

        // Remove any existing children of this node
        while(this.hasChildNodes())
          this.removeChild(this.firstChild);

        // Now copy newly parsed children from the root to this node
        this.doc.adoptNode(root);
        while(root.hasChildNodes()) {
          this.appendChild(root.firstChild);
        }
      }
    },
    style: { get: function() {
      if (!this._style)
        this._style = new CSSStyleDeclaration(this);
      return this._style;
    }},

    click: { value: function() {
      if (this._click_in_progress) return;
      this._click_in_progress = true;
      try {
        if (this._pre_click_activation_steps)
          this._pre_click_activation_steps();

        var event = this.ownerDocument.createEvent("MouseEvent");
        event.initMouseEvent("click", true, true,
          this.ownerDocument.defaultView, 1,
          0, 0, 0, 0,
          // These 4 should be initialized with
          // the actually current keyboard state
          // somehow...
          false, false, false, false,
          0, null
        );

        // Dispatch this as an untrusted event since it is synthetic
        var success = this.dispatchEvent(event);

        if (success) {
          if (this._post_click_activation_steps)
            this._post_click_activation_steps(event);
        }
        else {
          if (this._cancelled_activation_steps)
            this._cancelled_activation_steps();
        }
      }
      finally {
        this._click_in_progress = false;
      }
    }}
  },
  attributes: {
    title: String,
    lang: String,
    dir: {type: ["ltr", "rtl", "auto"], implied: true},
    accessKey: String,
    hidden: Boolean,
    tabIndex: {type: Number, default: function() {
      if (this.tagName in focusableElements ||
        this.contentEditable)
        return 0;
      else
        return -1;
    }}
  },
  events: [
    "abort", "canplay", "canplaythrough", "change", "click", "contextmenu",
    "cuechange", "dblclick", "drag", "dragend", "dragenter", "dragleave",
    "dragover", "dragstart", "drop", "durationchange", "emptied", "ended",
    "input", "invalid", "keydown", "keypress", "keyup", "loadeddata",
    "loadedmetadata", "loadstart", "mousedown", "mousemove", "mouseout",
    "mouseover", "mouseup", "mousewheel", "pause", "play", "playing",
    "progress", "ratechange", "readystatechange", "reset", "seeked",
    "seeking", "select", "show", "stalled", "submit", "suspend",
    "timeupdate", "volumechange", "waiting",

    // These last 5 event types will be overriden by HTMLBodyElement
    "blur", "error", "focus", "load", "scroll"
  ]
});


// XXX: reflect contextmenu as contextMenu, with element type


// style: the spec doesn't call this a reflected attribute.
//   may want to handle it manually.

// contentEditable: enumerated, not clear if it is actually
// reflected or requires custom getter/setter. Not listed as
// "limited to known values".  Raises syntax_err on bad setting,
// so I think this is custom.

// contextmenu: content is element id, idl type is an element
// draggable: boolean, but not a reflected attribute
// dropzone: reflected SettableTokenList, experimental, so don't
//   implement it right away.

// data-* attributes: need special handling in setAttribute?
// Or maybe that isn't necessary. Can I just scan the attribute list
// when building the dataset?  Liveness and caching issues?

// microdata attributes: many are simple reflected attributes, but
// I'm not going to implement this now.


var HTMLUnknownElement = define({
  ctor: function HTMLUnknownElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  }
});


var formAssociatedProps = {
  // See http://www.w3.org/TR/html5/association-of-controls-and-forms.html#form-owner
  form: { get: function() {
    return this._form;
  }}
};

define({
  tag: 'a',
  ctor: function HTMLAnchorElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  props: {
    _post_click_activation_steps: { value: function(e) {
      if (this.href) {
        // Follow the link
        // XXX: this is just a quick hack
        // XXX: the HTML spec probably requires more than this
        this.ownerDocument.defaultView.location = this.href;
      }
    }},
    blur: { value: function() {}},
    focus: { value: function() {}}
  },
  attributes: {
    href: URL,
    ping: String,
    download: String,
    target: String,
    rel: String,
    media: String,
    hreflang: String,
    type: String
  }
});

define({
  tag: 'area',
  ctor: function HTMLAreaElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  attributes: {
    alt: String,
    target: String,
    download: String,
    rel: String,
    media: String,
    href: URL,
    hreflang: String,
    type: String,
    shape: String,
    coords: String
    // XXX: also reflect relList
  }
});

define({
  tag: 'br',
  ctor: function HTMLBRElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  }
});

define({
  tag: 'base',
  ctor: function HTMLBaseElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  attributes: {
    "target": String
  }
});


define({
  tag: 'body',
  ctor: function HTMLBodyElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  // Certain event handler attributes on a <body> tag actually set
  // handlers for the window rather than just that element.  Define
  // getters and setters for those here.  Note that some of these override
  // properties on HTMLElement.prototype.
  // XXX: If I add support for <frameset>, these have to go there, too
  // XXX
  // When the Window object is implemented, these attribute will have
  // to work with the same-named attributes on the Window.
  events: [
    "afterprint", "beforeprint", "beforeunload", "blur", "error",
    "focus","hashchange", "load", "message", "offline", "online",
    "pagehide", "pageshow","popstate","resize","scroll","storage","unload",
  ]
});

define({
  tag: 'button',
  ctor: function HTMLButtonElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  props: formAssociatedProps,
  attributes: {
    name: String,
    value: String,
    disabled: Boolean,
    autofocus: Boolean,
    type: ["submit", "reset", "button"],
    formTarget: String,
    formNoValidate: Boolean,
    formMethod: ["get", "post"],
    formEnctype: [
      "application/x-www-form-urlencoded", "multipart/form-data", "text/plain"
    ]
  }
});

define({
  tag: 'command',
  ctor: function HTMLCommandElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  attributes: {
    type: ["command", "checkbox", "radio"],
    label: String,
    disabled: Boolean,
    checked: Boolean,
    radiogroup: String,
    icon: String
  }
});

define({
  tag: 'dl',
  ctor: function HTMLDListElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  }
});

define({
  tag: 'datalist',
  ctor: function HTMLDataListElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  }
});

define({
  tag: 'details',
  ctor: function HTMLDetailsElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  attributes: {
    "open": Boolean
  }
});

define({
  tag: 'div',
  ctor: function HTMLDivElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  }
});

define({
  tag: 'embed',
  ctor: function HTMLEmbedElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  attributes: {
    src: URL,
    type: String,
    width: String,
    height: String
  }
});

define({
  tag: 'fieldset',
  ctor: function HTMLFieldSetElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  props: formAssociatedProps,
  attributes: {
    disabled: Boolean,
    name: String
  }
});

define({
  tag: 'form',
  ctor: function HTMLFormElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  attributes: {
    action: String,
    autocomplete: ['on', 'off'],
    name: String,
    acceptCharset: {name: "accept-charset"},
    target: String,
    noValidate: Boolean,
    method: ["get", "post"],
    // Both enctype and encoding reflect the enctype content attribute
    enctype: ["application/x-www-form-urlencoded", "multipart/form-data", "text/plain"],
    encoding: {name: 'enctype', type: ["application/x-www-form-urlencoded", "multipart/form-data", "text/plain"]}
  }
});

define({
  tag: 'hr',
  ctor: function HTMLHRElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  }
});

define({
  tag: 'head',
  ctor: function HTMLHeadElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  }
});

define({
  tags: ['h1','h2','h3','h4','h5','h6'],
  ctor: function HTMLHeadingElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  }
});

define({
  tag: 'html',
  ctor: function HTMLHtmlElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  }
});

define({
  tag: 'iframe',
  ctor: function HTMLIFrameElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  attributes: {
    src: URL,
    srcdoc: String,
    name: String,
    width: String,
    height: String,
    // XXX: sandbox is a reflected settable token list
    seamless: Boolean
  }
});

define({
  tag: 'img',
  ctor: function HTMLImageElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  attributes: {
    src: URL,
    alt: String,
    crossOrigin: String,
    useMap: String,
    isMap: Boolean,
    height: { type: Number, default: 0 },
    width: { type: Number, default: 0 }
  }
});

define({
  tag: 'input',
  ctor: function HTMLInputElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  props: {
    form: formAssociatedProps.form,
    _post_click_activation_steps: { value: function(e) {
      if (this.type == 'checkbox') {
        this.checked = !this.checked;
      }
      else if (this.type == 'radio') {
        var group = this.form.getElementsByName(this.name);
        for (var i=group.length-1; i >= 0; i--) {
          var el = group[i];
          el.checked = el == this;
        }
      }
    }},
  },
  attributes: {
    name: String,
    disabled: Boolean,
    autofocus: Boolean,
    accept: String,
    alt: String,
    max: String,
    min: String,
    pattern: String,
    placeholder: String,
    step: String,
    dirName: String,
    defaultValue: {name: 'value'},
    multiple: Boolean,
    required: Boolean,
    readOnly: Boolean,
    checked: Boolean,
    value: String,
    src: URL,
    defaultChecked: {name: 'checked', type: Boolean},
    size: {type: Number, default: 20, min: 1, setmin: 1},
    maxLength: {min: 0, setmin: 0},
    autocomplete: ["on", "off"],
    type: ["text", "hidden", "search", "tel", "url", "email", "password",
      "datetime", "date", "month", "week", "time", "datetime-local",
      "number", "range", "color", "checkbox", "radio", "file", "submit",
      "image", "reset", "button"
    ],
    formTarget: String,
    formNoValidate: Boolean,
    formMethod: ["get", "post"],
    formEnctype: ["application/x-www-form-urlencoded", "multipart/form-data", "text/plain"]
  }
});

define({
  tag: 'keygen',
  ctor: function HTMLKeygenElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  props: formAssociatedProps,
  attributes: {
    name: String,
    disabled: Boolean,
    autofocus: Boolean,
    challenge: String,
    keytype: ["rsa"]
  }
});

define({
  tag: 'li',
  ctor: function HTMLLIElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  attributes: {
    value: {type: Number, default: 0},
  }
});

define({
  tag: 'label',
  ctor: function HTMLLabelElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  props: formAssociatedProps,
  attributes: {
    htmlFor: {name: 'for'}
  }
});

define({
  tag: 'legend',
  ctor: function HTMLLegendElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  }
});

define({
  tag: 'link',
  ctor: function HTMLLinkElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  attributes: {
    // XXX Reflect DOMSettableTokenList sizes also DOMTokenList relList
    href: URL,
    rel: String,
    media: String,
    hreflang: String,
    type: String
  }
});

define({
  tag: 'map',
  ctor: function HTMLMapElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  attributes: {
    name: String
  }
});

define({
  tag: 'menu',
  ctor: function HTMLMenuElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  attributes: {
    type: String,
    label: String
  }
});

define({
  tag: 'meta',
  ctor: function HTMLMetaElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  attributes: {
    name: String,
    content: String,
    scheme: String,
    httpEquiv: {name: 'http-equiv', type: String}
  }
});

define({
  tag: 'meter',
  ctor: function HTMLMeterElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  props: formAssociatedProps
});

define({
  tags: ['ins', 'del'],
  ctor: function HTMLModElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  attributes: {
    cite: String,
    dateTime: String
  }
});

define({
  tag: 'ol',
  ctor: function HTMLOListElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  props: {
    // Utility function (see the start attribute default value). Returns
    // the number of <li> children of this element
    _numitems: { get: function() {
      var items = 0;
      this.childNodes.forEach(function(n) {
        if (n.nodeType === ELEMENT_NODE && n.tagName === "LI")
          items++;
      });
      return items;
    }}
  },
  attributes: {
    type: String,
    reversed: Boolean,
    start: {
      type: Number,
      default: function() {
       // The default value of the start attribute is 1 unless the list is
       // reversed. Then it is the # of li children
       if (this.reversed)
         return this._numitems;
       else
         return 1;
      }
    }
  }
});

define({
  tag: 'object',
  ctor: function HTMLObjectElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  props: formAssociatedProps,
  attributes: {
    data: String,
    type: String,
    name: String,
    useMap: String,
    typeMustMatch: Boolean,
    width: String,
    height: String
  }
});

define({
  tag: 'optgroup',
  ctor: function HTMLOptGroupElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  attributes: {
    disabled: Boolean,
    label: String
  }
});

define({
  tag: 'option',
  ctor: function HTMLOptionElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  props: {
    form: { get: function() {
      var p = this.parentNode;
      while (p && p.nodeType == Node.ELEMENT_NODE) {
        if (p.localName == 'select') return p.form;
        p = p.parentNode;
      }
    }}
  },
  attributes: {
    disabled: Boolean,
    defaultSelected: {name: 'selected', type: Boolean},
    label: String
  }
});

define({
  tag: 'output',
  ctor: function HTMLOutputElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  props: formAssociatedProps,
  attributes: {
    // XXX Reflect for/htmlFor as a settable token list
    name: String
  }
});

define({
  tag: 'p',
  ctor: function HTMLParagraphElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  }
});

define({
  tag: 'param',
  ctor: function HTMLParamElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  attributes: {
    name: String,
    value: String
  }
});

define({
  tag: 'pre',
  ctor: function HTMLPreElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  }
});

define({
  tag: 'progress',
  ctor: function HTMLProgressElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  props: formAssociatedProps,
  attributes: {
    max: {type: Number, float: true, default: 1.0, min: 0}
  }
});

define({
  tags: ['q', 'blockquote'],
  ctor: function HTMLQuoteElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  attributes: {
    cite: URL
  }
});

define({
  tag: 'script',
  ctor: function HTMLScriptElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  props: {
    text: {
      get: function() {
        var s = "";
        for(var i = 0, n = this.childNodes.length; i < n; i++) {
          var child = this.childNodes[i];
          if (child.nodeType === Node.TEXT_NODE)
            s += child._data;
        }
        return s;
      },
      set: function(value) {
        this.removeChildren();
        if (value !== null && value !== "") {
          this.appendChild(this.ownerDocument.createTextNode(value));
        }
      }
    }
  },
  attributes: {
    src: URL,
    type: String,
    charset: String,
    defer: Boolean,
    async: Boolean
  }
});

define({
  tag: 'select',
  ctor: function HTMLSelectElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  props: {
    form: formAssociatedProps.form,
    options: { get: function() {
      return this.getElementsByTagName('option');
    }}
  },
  attributes: {
    name: String,
    disabled: Boolean,
    autofocus: Boolean,
    multiple: Boolean,
    required: Boolean,
    size: {type: Number, default: 0}
  }
});

define({
  tag: 'source',
  ctor: function HTMLSourceElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  attributes: {
    src: URL,
    type: String,
    media: String
  }
});

define({
  tag: 'span',
  ctor: function HTMLSpanElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  }
});

define({
  tag: 'style',
  ctor: function HTMLStyleElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  attributes: {
    media: String,
    type: String,
    scoped: Boolean
  }
});

define({
  tag: 'caption',
  ctor: function HTMLTableCaptionElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  }
});


define({
  ctor: function HTMLTableCellElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  attributes: {
    colSpan: {type: Number, default: 1, min: 1, setmin: 1},
    rowSpan: {type: Number, default: 1}
    //XXX Also reflect settable token list headers
  }
});

define({
  tags: ['col', 'colgroup'],
  ctor: function HTMLTableColElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  attributes: {
    span: {type: Number, default: 1, min: 1, setmin: 1}
  }
});

define({
  tag: 'table',
  ctor: function HTMLTableElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  props: {
    rows: { get: function() {
      return this.getElementsByTagName('tr');
    }}
  },
  attributes: {
    border: String
  }
});

define({
  tag: 'tr',
  ctor: function HTMLTableRowElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  props: {
    cells: { get: function() {
      return this.querySelectorAll('td,th');
    }}
  }
});

define({
  tags: ['thead', 'tfoot', 'tbody'],
  ctor: function HTMLTableSectionElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  props: {
    rows: { get: function() {
      return this.getElementsByTagName('tr');
    }}
  }
});

define({
  tag: 'textarea',
  ctor: function HTMLTextAreaElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  props: formAssociatedProps,
  attributes: {
    name: String,
    disabled: Boolean,
    autofocus: Boolean,
    placeholder: String,
    wrap: String,
    dirName: String,
    required: Boolean,
    readOnly: Boolean,
    rows: {type: Number, default: 2, min: 1, setmin: 1},
    cols: {type: Number, default: 20, min: 1, setmin: 1},
    maxLength: {type: Number, min: 0, setmin: 0}
  }
});

define({
  tag: 'time',
  ctor: function HTMLTimeElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  attributes: {
    dateTime: String,
    pubDate: Boolean
  }
});

define({
  tag: 'title',
  ctor: function HTMLTitleElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  props: {
    text: { get: function() {
      return this.textContent;
    }}
  }
});

define({
  tag: 'track',
  ctor: function HTMLTrackElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  attributes: {
    src: URL,
    srclang: String,
    label: String,
    default: Boolean,
    kind: ["subtitles", "captions", "descriptions", "chapters", "metadata"]
  }
});

define({
  tag: 'ul',
  ctor: function HTMLUListElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  }
});

define({
  ctor: function HTMLMediaElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  },
  attributes: {
    src: URL,
    crossOrigin: String,
    preload: ["metadata", "none", "auto", {value: "", alias: "auto"}],
    loop: Boolean,
    autoplay: Boolean,
    mediaGroup: String,
    controls: Boolean,
    defaultMuted: {name: "muted", type: Boolean}
  }
});

define({
  tag: 'audio',
  superclass: impl.HTMLMediaElement,
  ctor: function HTMLAudioElement(doc, localName, prefix) {
    impl.HTMLMediaElement.call(this, doc, localName, prefix);
  }
});

define({
  tag: 'video',
  superclass: impl.HTMLMediaElement,
  ctor: function HTMLVideoElement(doc, localName, prefix) {
    impl.HTMLMediaElement.call(this, doc, localName, prefix);
  },
  attributes: {
    poster: String,
    width: {type: Number, min: 0, setmin: 0},
    height: {type: Number, min: 0, setmin: 0}
  }
});

define({
  tag: 'td',
  superclass: impl.HTMLTableCellElement,
  ctor: function HTMLTableDataCellElement(doc, localName, prefix) {
    impl.HTMLTableCellElement.call(this, doc, localName, prefix);
  }
});

define({
  tag: 'th',
  superclass: impl.HTMLTableCellElement,
  ctor: function HTMLTableHeaderCellElement(doc, localName, prefix) {
    impl.HTMLTableCellElement.call(this, doc, localName, prefix);
  },
  attributes: {
    scope: ["", "row", "col", "rowgroup", "colgroup"]
  }
});

define({
  tag: 'frameset',
  ctor: function HTMLFrameSetElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  }
});

define({
  tag: 'frame',
  ctor: function HTMLFrameElement(doc, localName, prefix) {
    HTMLElement.call(this, doc, localName, prefix);
  }
});

define({
  tags: [
    "abbr", "address", "article", "aside", "b", "bdi", "bdo", "canvas",
    "cite", "code", "dd", "dfn", "dt", "em", "figcaption", "figure",
    "footer", "header", "hgroup", "i", "kbd", "mark", "nav", "noscript",
    "rp", "rt", "ruby", "s", "samp", "section", "small", "strong", "sub",
    "summary", "sup", "u", "var", "wbr"
  ]
});

},{"./CSSStyleDeclaration":2,"./Element":12,"./Node":21,"./attributes":31,"./utils":38}],35:[function(require,module,exports){
var utils = require('./utils');

exports = module.exports = {
  CSSStyleDeclaration: require('./CSSStyleDeclaration'),
  CharacterData: require('./CharacterData'),
  Comment: require('./Comment'),
  DOMException: require('./DOMException'),
  DOMImplementation: require('./DOMImplementation'),
  DOMTokenList: require('./DOMTokenList'),
  Document: require('./Document'),
  DocumentFragment: require('./DocumentFragment'),
  DocumentType: require('./DocumentType'),
  Element: require('./Element'),
  Node: require('./Node'),
  NodeList: require('./NodeList'),
  NodeFilter: require('./NodeFilter'),
  ProcessingInstruction: require('./ProcessingInstruction'),
  Text: require('./Text'),
  Window: require('./Window')
};

utils.merge(exports, require('./events'));
utils.merge(exports, require('./htmlelts').elements);

},{"./CSSStyleDeclaration":2,"./CharacterData":3,"./Comment":4,"./DOMException":6,"./DOMImplementation":7,"./DOMTokenList":8,"./Document":9,"./DocumentFragment":10,"./DocumentType":11,"./Element":12,"./Node":21,"./NodeFilter":22,"./NodeList":23,"./ProcessingInstruction":24,"./Text":25,"./Window":30,"./events":33,"./htmlelts":34,"./utils":38}],36:[function(require,module,exports){
var DOMImplementation = require('./DOMImplementation');
var HTMLParser = require('./HTMLParser');
var Window = require('./Window');

exports.createDOMImplementation = function() {
  return new DOMImplementation();
};

exports.createDocument = function(html) {
  if (html) {
    var parser = new HTMLParser();
    parser.parse(html, true);
    return parser.document();
  }
  return new DOMImplementation().createHTMLDocument("");
};

exports.createWindow = function(html) {
  var document = exports.createDocument(html);
  return new Window(document);
};

exports.impl = require('./impl');

},{"./DOMImplementation":7,"./HTMLParser":16,"./Window":30,"./impl":35}],37:[function(require,module,exports){
/**
 * Zest (https://github.com/chjj/zest)
 * A css selector engine.
 * Copyright (c) 2011-2012, Christopher Jeffrey. (MIT Licensed)
 */

/**
 * Helpers
 */

var compareDocumentPosition = function(a, b) {
      return a.compareDocumentPosition(b);
};

var order = function(a, b) {
  return compareDocumentPosition(a, b) & 2 ? 1 : -1;
};

var next = function(el) {
  while ((el = el.nextSibling)
         && el.nodeType !== 1);
  return el;
};

var prev = function(el) {
  while ((el = el.previousSibling)
         && el.nodeType !== 1);
  return el;
};

var child = function(el) {
  if (el = el.firstChild) {
    while (el.nodeType !== 1
           && (el = el.nextSibling));
  }
  return el;
};

var lastChild = function(el) {
  if (el = el.lastChild) {
    while (el.nodeType !== 1
           && (el = el.previousSibling));
  }
  return el;
};

var unquote = function(str) {
  if (!str) return str;
  var ch = str[0];
  return ch === '"' || ch === '\''
    ? str.slice(1, -1)
    : str;
};

var indexOf = (function() {
  if (Array.prototype.indexOf) {
    return Array.prototype.indexOf;
  }
  return function(obj, item) {
    var i = this.length;
    while (i--) {
      if (this[i] === item) return i;
    }
    return -1;
  };
})();

var makeInside = function(start, end) {
  var regex = rules.inside.source
    .replace(/</g, start)
    .replace(/>/g, end);

  return new RegExp(regex);
};

var replace = function(regex, name, val) {
  regex = regex.source;
  regex = regex.replace(name, val.source || val);
  return new RegExp(regex);
};

var truncateUrl = function(url, num) {
  return url
    .replace(/^(?:\w+:\/\/|\/+)/, '')
    .replace(/(?:\/+|\/*#.*?)$/, '')
    .split('/', num)
    .join('/');
};

/**
 * Handle `nth` Selectors
 */

var parseNth = function(param, test) {
  var param = param.replace(/\s+/g, '')
    , cap;

  if (param === 'even') {
    param = '2n+0';
  } else if (param === 'odd') {
    param = '2n+1';
  } else if (!~param.indexOf('n')) {
    param = '0n' + param;
  }

  cap = /^([+-])?(\d+)?n([+-])?(\d+)?$/.exec(param);

  return {
    group: cap[1] === '-'
      ? -(cap[2] || 1)
      : +(cap[2] || 1),
    offset: cap[4]
      ? (cap[3] === '-' ? -cap[4] : +cap[4])
      : 0
  };
};

var nth = function(param, test, last) {
  var param = parseNth(param)
    , group = param.group
    , offset = param.offset
    , find = !last ? child : lastChild
    , advance = !last ? next : prev;

  return function(el) {
    if (el.parentNode.nodeType !== 1) return;

    var rel = find(el.parentNode)
      , pos = 0;

    while (rel) {
      if (test(rel, el)) pos++;
      if (rel === el) {
        pos -= offset;
        return group && pos
          ? !(pos % group) && (pos < 0 === group < 0)
          : !pos;
      }
      rel = advance(rel);
    }
  };
};

/**
 * Simple Selectors
 */

var selectors = {
  '*': (function() {
    if (false/*function() {
      var el = document.createElement('div');
      el.appendChild(document.createComment(''));
      return !!el.getElementsByTagName('*')[0];
    }()*/) {
      return function(el) {
        if (el.nodeType === 1) return true;
      };
    }
    return function() {
      return true;
    };
  })(),
  'type': function(type) {
    type = type.toLowerCase();
    return function(el) {
      return el.nodeName.toLowerCase() === type;
    };
  },
  'attr': function(key, op, val, i) {
    op = operators[op];
    return function(el) {
      var attr;
      switch (key) {
        case 'for':
          attr = el.htmlFor;
          break;
        case 'class':
          // className is '' when non-existent
          // getAttribute('class') is null
          attr = el.className;
          if (attr === '' && el.getAttribute('class') == null) {
            attr = null;
          }
          break;
        case 'href':
          attr = el.getAttribute('href', 2);
          break;
        case 'title':
          // getAttribute('title') can be '' when non-existent sometimes?
          attr = el.getAttribute('title') || null;
          break;
        case 'id':
          if (el.getAttribute) {
            attr = el.getAttribute('id');
            break;
          }
        default:
          attr = el[key] != null
            ? el[key]
            : el.getAttribute && el.getAttribute(key);
          break;
      }
      if (attr == null) return;
      attr = attr + '';
      if (i) {
        attr = attr.toLowerCase();
        val = val.toLowerCase();
      }
      return op(attr, val);
    };
  },
  ':first-child': function(el) {
    return !prev(el) && el.parentNode.nodeType === 1;
  },
  ':last-child': function(el) {
    return !next(el) && el.parentNode.nodeType === 1;
  },
  ':only-child': function(el) {
    return !prev(el) && !next(el)
      && el.parentNode.nodeType === 1;
  },
  ':nth-child': function(param, last) {
    return nth(param, function() {
      return true;
    }, last);
  },
  ':nth-last-child': function(param) {
    return selectors[':nth-child'](param, true);
  },
  ':root': function(el) {
    return el.ownerDocument.documentElement === el;
  },
  ':empty': function(el) {
    return !el.firstChild;
  },
  ':not': function(sel) {
    var test = compileGroup(sel);
    return function(el) {
      return !test(el);
    };
  },
  ':first-of-type': function(el) {
    if (el.parentNode.nodeType !== 1) return;
    var type = el.nodeName;
    while (el = prev(el)) {
      if (el.nodeName === type) return;
    }
    return true;
  },
  ':last-of-type': function(el) {
    if (el.parentNode.nodeType !== 1) return;
    var type = el.nodeName;
    while (el = next(el)) {
      if (el.nodeName === type) return;
    }
    return true;
  },
  ':only-of-type': function(el) {
    return selectors[':first-of-type'](el)
        && selectors[':last-of-type'](el);
  },
  ':nth-of-type': function(param, last) {
    return nth(param, function(rel, el) {
      return rel.nodeName === el.nodeName;
    }, last);
  },
  ':nth-last-of-type': function(param) {
    return selectors[':nth-of-type'](param, true);
  },
  ':checked': function(el) {
    return !!(el.checked || el.selected);
  },
  ':indeterminate': function(el) {
    return !selectors[':checked'](el);
  },
  ':enabled': function(el) {
    return !el.disabled && el.type !== 'hidden';
  },
  ':disabled': function(el) {
    return !!el.disabled;
  },
  ':target': function(el) {
    return el.id === window.location.hash.substring(1);
  },
  ':focus': function(el) {
    return el === el.ownerDocument.activeElement;
  },
  ':matches': function(sel) {
    return compileGroup(sel);
  },
  ':nth-match': function(param, last) {
    var args = param.split(/\s*,\s*/)
      , arg = args.shift()
      , test = compileGroup(args.join(','));

    return nth(arg, test, last);
  },
  ':nth-last-match': function(param) {
    return selectors[':nth-match'](param, true);
  },
  ':links-here': function(el) {
    return el + '' === window.location + '';
  },
  ':lang': function(param) {
    return function(el) {
      while (el) {
        if (el.lang) return el.lang.indexOf(param) === 0;
        el = el.parentNode;
      }
    };
  },
  ':dir': function(param) {
    return function(el) {
      while (el) {
        if (el.dir) return el.dir === param;
        el = el.parentNode;
      }
    };
  },
  ':scope': function(el, con) {
    var context = con || el.ownerDocument;
    if (context.nodeType === 9) {
      return el === context.documentElement;
    }
    return el === context;
  },
  ':any-link': function(el) {
    return typeof el.href === 'string';
  },
  ':local-link': function(el) {
    if (el.nodeName) {
      return el.href && el.host === window.location.host;
    }
    var param = +el + 1;
    return function(el) {
      if (!el.href) return;

      var url = window.location + ''
        , href = el + '';

      return truncateUrl(url, param) === truncateUrl(href, param);
    };
  },
  ':default': function(el) {
    return !!el.defaultSelected;
  },
  ':valid': function(el) {
    return el.willValidate || (el.validity && el.validity.valid);
  },
  ':invalid': function(el) {
    return !selectors[':valid'](el);
  },
  ':in-range': function(el) {
    return el.value > el.min && el.value <= el.max;
  },
  ':out-of-range': function(el) {
    return !selectors[':in-range'](el);
  },
  ':required': function(el) {
    return !!el.required;
  },
  ':optional': function(el) {
    return !el.required;
  },
  ':read-only': function(el) {
    if (el.readOnly) return true;

    var attr = el.getAttribute('contenteditable')
      , prop = el.contentEditable
      , name = el.nodeName.toLowerCase();

    name = name !== 'input' && name !== 'textarea';

    return (name || el.disabled) && attr == null && prop !== 'true';
  },
  ':read-write': function(el) {
    return !selectors[':read-only'](el);
  },
  ':hover': function() {
    throw new Error(':hover is not supported.');
  },
  ':active': function() {
    throw new Error(':active is not supported.');
  },
  ':link': function() {
    throw new Error(':link is not supported.');
  },
  ':visited': function() {
    throw new Error(':visited is not supported.');
  },
  ':column': function() {
    throw new Error(':column is not supported.');
  },
  ':nth-column': function() {
    throw new Error(':nth-column is not supported.');
  },
  ':nth-last-column': function() {
    throw new Error(':nth-last-column is not supported.');
  },
  ':current': function() {
    throw new Error(':current is not supported.');
  },
  ':past': function() {
    throw new Error(':past is not supported.');
  },
  ':future': function() {
    throw new Error(':future is not supported.');
  },
  // Non-standard, for compatibility purposes.
  ':contains': function(param) {
    return function(el) {
      var text = el.innerText || el.textContent || el.value || '';
      return !!~text.indexOf(param);
    };
  },
  ':has': function(param) {
    return function(el) {
      return zest(param, el).length > 0;
    };
  }
  // Potentially add more pseudo selectors for
  // compatibility with sizzle and most other
  // selector engines (?).
};

/**
 * Attribute Operators
 */

var operators = {
  '-': function() {
    return true;
  },
  '=': function(attr, val) {
    return attr === val;
  },
  '*=': function(attr, val) {
    return attr.indexOf(val) !== -1;
  },
  '~=': function(attr, val) {
    var i = attr.indexOf(val)
      , f
      , l;

    if (i === -1) return;
    f = attr[i - 1];
    l = attr[i + val.length];

    return (!f || f === ' ') && (!l || l === ' ');
  },
  '|=': function(attr, val) {
    var i = attr.indexOf(val)
      , l;

    if (i !== 0) return;
    l = attr[i + val.length];

    return l === '-' || !l;
  },
  '^=': function(attr, val) {
    return attr.indexOf(val) === 0;
  },
  '$=': function(attr, val) {
    return attr.indexOf(val) + val.length === attr.length;
  },
  // non-standard
  '!=': function(attr, val) {
    return attr !== val;
  }
};

/**
 * Combinator Logic
 */

var combinators = {
  ' ': function(test) {
    return function(el) {
      while (el = el.parentNode) {
        if (test(el)) return el;
      }
    };
  },
  '>': function(test) {
    return function(el) {
      if (el = el.parentNode) {
        return test(el) && el;
      }
    };
  },
  '+': function(test) {
    return function(el) {
      if (el = prev(el)) {
        return test(el) && el;
      }
    };
  },
  '~': function(test) {
    return function(el) {
      while (el = prev(el)) {
        if (test(el)) return el;
      }
    };
  },
  'noop': function(test) {
    return function(el) {
      return test(el) && el;
    };
  },
  'ref': function(test, name) {
    var node;

    function ref(el) {
      var doc = el.ownerDocument
        , nodes = doc.getElementsByTagName('*')
        , i = nodes.length;

      while (i--) {
        node = nodes[i];
        if (ref.test(el)) {
          node = null;
          return true;
        }
      }

      node = null;
    }

    ref.combinator = function(el) {
      if (!node || !node.getAttribute) return;

      var attr = node.getAttribute(name) || '';
      if (attr[0] === '#') attr = attr.substring(1);

      if (attr === el.id && test(node)) {
        return node;
      }
    };

    return ref;
  }
};

/**
 * Grammar
 */

var rules = {
  qname: /^ *([\w\-]+|\*)/,
  simple: /^(?:([.#][\w\-]+)|pseudo|attr)/,
  ref: /^ *\/([\w\-]+)\/ */,
  combinator: /^(?: +([^ \w*]) +|( )+|([^ \w*]))(?! *$)/,
  attr: /^\[([\w\-]+)(?:([^\w]?=)(inside))?\]/,
  pseudo: /^(:[\w\-]+)(?:\((inside)\))?/,
  inside: /(?:"(?:\\"|[^"])*"|'(?:\\'|[^'])*'|<[^"'>]*>|\\["'>]|[^"'>])*/
};

rules.inside = replace(rules.inside, '[^"\'>]*', rules.inside);
rules.attr = replace(rules.attr, 'inside', makeInside('\\[', '\\]'));
rules.pseudo = replace(rules.pseudo, 'inside', makeInside('\\(', '\\)'));
rules.simple = replace(rules.simple, 'pseudo', rules.pseudo);
rules.simple = replace(rules.simple, 'attr', rules.attr);

/**
 * Compiling
 */

var compile = function(sel) {
  var sel = sel.replace(/^\s+|\s+$/g, '')
    , test
    , filter = []
    , buff = []
    , subject
    , qname
    , cap
    , op
    , ref;

  while (sel) {
    if (cap = rules.qname.exec(sel)) {
      sel = sel.substring(cap[0].length);
      qname = cap[1];
      buff.push(tok(qname, true));
    } else if (cap = rules.simple.exec(sel)) {
      sel = sel.substring(cap[0].length);
      qname = '*';
      buff.push(tok(qname, true));
      buff.push(tok(cap));
    } else {
      throw new Error('Invalid selector.');
    }

    while (cap = rules.simple.exec(sel)) {
      sel = sel.substring(cap[0].length);
      buff.push(tok(cap));
    }

    if (sel[0] === '!') {
      sel = sel.substring(1);
      subject = makeSubject();
      subject.qname = qname;
      buff.push(subject.simple);
    }

    if (cap = rules.ref.exec(sel)) {
      sel = sel.substring(cap[0].length);
      ref = combinators.ref(makeSimple(buff), cap[1]);
      filter.push(ref.combinator);
      buff = [];
      continue;
    }

    if (cap = rules.combinator.exec(sel)) {
      sel = sel.substring(cap[0].length);
      op = cap[1] || cap[2] || cap[3];
      if (op === ',') {
        filter.push(combinators.noop(makeSimple(buff)));
        break;
      }
    } else {
      op = 'noop';
    }

    filter.push(combinators[op](makeSimple(buff)));
    buff = [];
  }

  test = makeTest(filter);
  test.qname = qname;
  test.sel = sel;

  if (subject) {
    subject.lname = test.qname;

    subject.test = test;
    subject.qname = subject.qname;
    subject.sel = test.sel;
    test = subject;
  }

  if (ref) {
    ref.test = test;
    ref.qname = test.qname;
    ref.sel = test.sel;
    test = ref;
  }

  return test;
};

var tok = function(cap, qname) {
  // qname
  if (qname) {
    return cap === '*'
      ? selectors['*']
      : selectors.type(cap);
  }

  // class/id
  if (cap[1]) {
    return cap[1][0] === '.'
      ? selectors.attr('class', '~=', cap[1].substring(1))
      : selectors.attr('id', '=', cap[1].substring(1));
  }

  // pseudo-name
  // inside-pseudo
  if (cap[2]) {
    return cap[3]
      ? selectors[cap[2]](unquote(cap[3]))
      : selectors[cap[2]];
  }

  // attr name
  // attr op
  // attr value
  if (cap[4]) {
    var i;
    if (cap[6]) {
      i = cap[6].length;
      cap[6] = cap[6].replace(/ +i$/, '');
      i = i > cap[6].length;
    }
    return selectors.attr(cap[4], cap[5] || '-', unquote(cap[6]), i);
  }

  throw new Error('Unknown Selector.');
};

var makeSimple = function(func) {
  var l = func.length
    , i;

  // Potentially make sure
  // `el` is truthy.
  if (l < 2) return func[0];

  return function(el) {
    if (!el) return;
    for (i = 0; i < l; i++) {
      if (!func[i](el)) return;
    }
    return true;
  };
};

var makeTest = function(func) {
  if (func.length < 2) {
    return function(el) {
      return !!func[0](el);
    };
  }
  return function(el) {
    var i = func.length;
    while (i--) {
      if (!(el = func[i](el))) return;
    }
    return true;
  };
};

var makeSubject = function() {
  var target;

  function subject(el) {
    var node = el.ownerDocument
      , scope = node.getElementsByTagName(subject.lname)
      , i = scope.length;

    while (i--) {
      if (subject.test(scope[i]) && target === el) {
        target = null;
        return true;
      }
    }

    target = null;
  }

  subject.simple = function(el) {
    target = el;
    return true;
  };

  return subject;
};

var compileGroup = function(sel) {
  var test = compile(sel)
    , tests = [ test ];

  while (test.sel) {
    test = compile(test.sel);
    tests.push(test);
  }

  if (tests.length < 2) return test;

  return function(el) {
    var l = tests.length
      , i = 0;

    for (; i < l; i++) {
      if (tests[i](el)) return true;
    }
  };
};

/**
 * Selection
 */

var find = function(sel, node) {
  var results = []
    , test = compile(sel)
    , scope = node.getElementsByTagName(test.qname)
    , i = 0
    , el;

  while (el = scope[i++]) {
    if (test(el)) results.push(el);
  }

  if (test.sel) {
    while (test.sel) {
      test = compile(test.sel);
      scope = node.getElementsByTagName(test.qname);
      i = 0;
      while (el = scope[i++]) {
        if (test(el) && !~indexOf.call(results, el)) {
          results.push(el);
        }
      }
    }
    results.sort(order);
  }

  return results;
};

/**
 * Expose
 */

module.exports = exports = function(sel, context) {
  /* when context isn't a DocumentFragment and the selector is simple: */
  if (context.nodeType !== 11 && !~sel.indexOf(' ')) {
    if (sel[0] === '#' && context.rooted && /^#\w+$/.test(sel)) {
      return [context.doc.getElementById(sel.substring(1))];
    }
    if (sel[0] === '.' && /^\.\w+$/.test(sel)) {
      return context.getElementsByClassName(sel.substring(1));
    }
    if (/^\w+$/.test(sel)) {
      return context.getElementsByTagName(sel);
    }
  }
  /* do things the hard/slow way */
  return find(sel, context);
};

exports.selectors = selectors;
exports.operators = operators;
exports.combinators = combinators;

exports.matches = function(el, sel) {
  return !!compile(sel)(el);
};



},{}],38:[function(require,module,exports){
var DOMException = require('./DOMException');
var ERR = DOMException;

exports.NAMESPACE = {
  HTML: 'http://www.w3.org/1999/xhtml',
  XML: 'http://www.w3.org/XML/1998/namespace',
  XMLNS: 'http://www.w3.org/2000/xmlns/',
  MATHML: 'http://www.w3.org/1998/Math/MathML',
  SVG: 'http://www.w3.org/2000/svg',
  XLINK: 'http://www.w3.org/1999/xlink'
};

//
// Shortcut functions for throwing errors of various types.
//
exports.IndexSizeError = function() { throw new DOMException(ERR.INDEX_SIZE_ERR); }
exports.HierarchyRequestError = function() { throw new DOMException(ERR.HIERARCHY_REQUEST_ERR); }
exports.WrongDocumentError = function() { throw new DOMException(ERR.WRONG_DOCUMENT_ERR); }
exports.InvalidCharacterError = function() { throw new DOMException(ERR.INVALID_CHARACTER_ERR); }
exports.NoModificationAllowedError = function() { throw new DOMException(ERR.NO_MODIFICATION_ALLOWED_ERR); }
exports.NotFoundError = function() { throw new DOMException(ERR.NOT_FOUND_ERR); }
exports.NotSupportedError = function() { throw new DOMException(ERR.NOT_SUPPORTED_ERR); }
exports.InvalidStateError = function() { throw new DOMException(ERR.INVALID_STATE_ERR); }
exports.SyntaxError = function() { throw new DOMException(ERR.SYNTAX_ERR); }
exports.InvalidModificationError = function() { throw new DOMException(ERR.INVALID_MODIFICATION_ERR); }
exports.NamespaceError = function() { throw new DOMException(ERR.NAMESPACE_ERR); }
exports.InvalidAccessError = function() { throw new DOMException(ERR.INVALID_ACCESS_ERR); }
exports.TypeMismatchError = function() { throw new DOMException(ERR.TYPE_MISMATCH_ERR); }
exports.SecurityError = function() { throw new DOMException(ERR.SECURITY_ERR); }
exports.NetworkError = function() { throw new DOMException(ERR.NETWORK_ERR); }
exports.AbortError = function() { throw new DOMException(ERR.ABORT_ERR); }
exports.UrlMismatchError = function() { throw new DOMException(ERR.URL_MISMATCH_ERR); }
exports.QuotaExceededError = function() { throw new DOMException(ERR.QUOTA_EXCEEDED_ERR); }
exports.TimeoutError = function() { throw new DOMException(ERR.TIMEOUT_ERR); }
exports.InvalidNodeTypeError = function() { throw new DOMException(ERR.INVALID_NODE_TYPE_ERR); }
exports.DataCloneError = function() { throw new DOMException(ERR.DATA_CLONE_ERR); }

exports.nyi = function() {
  throw new Error("NotYetImplemented");
}

exports.assert = function(expr, msg) {
  if (!expr) {
    throw new Error("Assertion failed: " + (msg || "") + "\n" + new Error().stack);
  }
};

exports.expose = function(src, c) {
  for (var n in src) {
    Object.defineProperty(c.prototype, n, {value: src[n] });
  }
};

exports.merge = function(a, b) {
  for (var n in b) {
    a[n] = b[n]
  }
};

// Compare two nodes based on their document order. This function is intended
// to be passed to sort(). Assumes that the array being sorted does not
// contain duplicates.  And that all nodes are connected and comparable.
// Clever code by ppk via jeresig.
exports.documentOrder = function(n,m) {
  return 3 - (n.compareDocumentPosition(m) & 6);
};

},{"./DOMException":6}],39:[function(require,module,exports){
// This grammar is from the XML and XML Namespace specs. It specifies whether
// a string (such as an element or attribute name) is a valid Name or QName.
//
// Name           ::= NameStartChar (NameChar)*
// NameStartChar  ::= ":" | [A-Z] | "_" | [a-z] |
//                    [#xC0-#xD6] | [#xD8-#xF6] | [#xF8-#x2FF] |
//                    [#x370-#x37D] | [#x37F-#x1FFF] |
//                    [#x200C-#x200D] | [#x2070-#x218F] |
//                    [#x2C00-#x2FEF] | [#x3001-#xD7FF] |
//                    [#xF900-#xFDCF] | [#xFDF0-#xFFFD] |
//                    [#x10000-#xEFFFF]
//
// NameChar       ::= NameStartChar | "-" | "." | [0-9] |
//                    #xB7 | [#x0300-#x036F] | [#x203F-#x2040]
//
// QName          ::= PrefixedName| UnprefixedName
// PrefixedName   ::= Prefix ':' LocalPart
// UnprefixedName ::= LocalPart
// Prefix         ::= NCName
// LocalPart      ::= NCName
// NCName         ::= Name - (Char* ':' Char*)
//                    # An XML Name, minus the ":"
//

exports.isValidName = isValidName;
exports.isValidQName = isValidQName;

// Most names will be ASCII only. Try matching against simple regexps first
var simplename = /^[_:A-Za-z][-.:\w]+$/;
var simpleqname = /^([_A-Za-z][-.\w]+|[_A-Za-z][-.\w]+:[_A-Za-z][-.\w]+)$/

// If the regular expressions above fail, try more complex ones that work
// for any identifiers using codepoints from the Unicode BMP
var ncnamestartchars = "_A-Za-z\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u02ff\u0370-\u037D\u037F-\u1FFF\u200C-\u200D\u2070-\u218F\u2C00-\u2FEF\u3001-\uD7FF\uF900-\uFDCF\uFDF0-\uFFFD";
var ncnamechars = "-._A-Za-z0-9\u00B7\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u02ff\u0300-\u037D\u037F-\u1FFF\u200C\u200D\u203f\u2040\u2070-\u218F\u2C00-\u2FEF\u3001-\uD7FF\uF900-\uFDCF\uFDF0-\uFFFD";

var ncname = "[" + ncnamestartchars + "][" + ncnamechars + "]*";
var namestartchars = ncnamestartchars + ":";
var namechars = ncnamechars + ":";
var name = new RegExp("^[" + namestartchars + "]" + "[" + namechars + "]*$");
var qname = new RegExp("^(" + ncname + "|" + ncname + ":" + ncname + ")$");

// XML says that these characters are also legal:
// [#x10000-#xEFFFF].  So if the patterns above fail, and the
// target string includes surrogates, then try the following
// patterns that allow surrogates and then run an extra validation
// step to make sure that the surrogates are in valid pairs and in
// the right range.  Note that since the characters \uf0000 to \u1f0000
// are not allowed, it means that the high surrogate can only go up to
// \uDB7f instead of \uDBFF.
var hassurrogates = /[\uD800-\uDB7F\uDC00-\uDFFF]/;
var surrogatechars = /[\uD800-\uDB7F\uDC00-\uDFFF]/g;
var surrogatepairs = /[\uD800-\uDB7F][\uDC00-\uDFFF]/g;

// Modify the variables above to allow surrogates
ncnamestartchars += "\uD800-\uDB7F\uDC00-\uDFFF";
ncnamechars += "\uD800-\uDB7F\uDC00-\uDFFF";
ncname = "[" + ncnamestartchars + "][" + ncnamechars + "]*";
namestartchars = ncnamestartchars + ":";
namechars = ncnamechars + ":";

// Build another set of regexps that include surrogates
var surrogatename = new RegExp("^[" + namestartchars + "]" + "[" + namechars + "]*$");
var surrogateqname = new RegExp("^(" + ncname + "|" + ncname + ":" + ncname + ")$");

function isValidName(s) {
  if (simplename.test(s)) return true; // Plain ASCII
  if (name.test(s)) return true; // Unicode BMP

  // Maybe the tests above failed because s includes surrogate pairs
  // Most likely, though, they failed for some more basic syntax problem
  if (!hassurrogates.test(s)) return false;

  // Is the string a valid name if we allow surrogates?
  if (!surrogatename.test(s)) return false;

  // Finally, are the surrogates all correctly paired up?
  var chars = s.match(surrogatechars), pairs = s.match(surrogatepairs);
  return pairs != null && 2*pairs.length === chars.length;
}

function isValidQName(s) {
  if (simpleqname.test(s)) return true; // Plain ASCII
  if (qname.test(s)) return true; // Unicode BMP

  if (!hassurrogates.test(s)) return false;
  if (!surrogateqname.test(s)) return false;
  var chars = s.match(surrogatechars), pairs = s.match(surrogatepairs);
  return pairs != null && 2*pairs.length === chars.length;
}

},{}]},{},[1])
