/* eslint-disable */

// Any IE only polyfill should be moved in discourse-unsupported-browser plugin

// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/RegExp/flags#Polyfill
// IE and EDGE
if (RegExp.prototype.flags === undefined) {
  Object.defineProperty(RegExp.prototype, "flags", {
    configurable: true,
    get: function() {
      return this.toString().match(/[gimsuy]*$/)[0];
    }
  });
}

// https://github.com/uxitten/polyfill/blob/master/string.polyfill.js
// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/padStart
if (!String.prototype.padStart) {
  String.prototype.padStart = function padStart(targetLength, padString) {
    targetLength = targetLength >> 0; //truncate if number, or convert non-number to 0;
    padString = String(typeof padString !== "undefined" ? padString : " ");
    if (this.length >= targetLength) {
      return String(this);
    } else {
      targetLength = targetLength - this.length;
      if (targetLength > padString.length) {
        padString += padString.repeat(targetLength / padString.length); //append to original to ensure we are longer than needed
      }
      return padString.slice(0, targetLength) + String(this);
    }
  };
}

// https://github.com/uxitten/polyfill/blob/master/string.polyfill.js
// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/padEnd
if (!String.prototype.padEnd) {
  String.prototype.padEnd = function padEnd(targetLength, padString) {
    targetLength = targetLength >> 0; //floor if number or convert non-number to 0;
    padString = String(typeof padString !== "undefined" ? padString : " ");
    if (this.length > targetLength) {
      return String(this);
    } else {
      targetLength = targetLength - this.length;
      if (targetLength > padString.length) {
        padString += padString.repeat(targetLength / padString.length); //append to original to ensure we are longer than needed
      }
      return String(this) + padString.slice(0, targetLength);
    }
  };
}

// Needed for iOS 9.3
// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/entries
if (!Object.entries) {
  Object.entries = function(obj) {
    var ownProps = Object.keys(obj),
      i = ownProps.length,
      resArray = new Array(i); // preallocate the Array
    while (i--) resArray[i] = [ownProps[i], obj[ownProps[i]]];

    return resArray;
  };
}

// Needed for iOS 9.3
// adapted from https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/entries
if (!Object.values) {
  Object.values = function(obj) {
    var ownProps = Object.keys(obj),
      i = ownProps.length,
      resArray = new Array(i); // preallocate the Array
    while (i--) resArray[i] = obj[ownProps[i]];

    return resArray;
  };
}

// Needed for iOS 9.3
// https://developer.mozilla.org/fr/docs/Web/API/NodeList/forEach
if (window.NodeList && !NodeList.prototype.forEach) {
  NodeList.prototype.forEach = function(callback, thisArg) {
    thisArg = thisArg || window;
    for (var i = 0; i < this.length; i++) {
      callback.call(thisArg, this[i], i, this);
    }
  };
}

// Needed for iOS 9.3
// from: https://github.com/jserz/js_piece/blob/master/DOM/ChildNode/before()/before().md
(function(arr) {
  arr.forEach(function(item) {
    if (item.hasOwnProperty("before")) {
      return;
    }
    Object.defineProperty(item, "before", {
      configurable: true,
      enumerable: true,
      writable: true,
      value: function before() {
        var argArr = Array.prototype.slice.call(arguments),
          docFrag = document.createDocumentFragment();

        argArr.forEach(function(argItem) {
          var isNode = argItem instanceof Node;
          docFrag.appendChild(
            isNode ? argItem : document.createTextNode(String(argItem))
          );
        });

        this.parentNode.insertBefore(docFrag, this);
      }
    });
  });
})([Element.prototype, CharacterData.prototype, DocumentType.prototype]);

/* eslint-enable */
