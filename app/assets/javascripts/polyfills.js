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

// adapted from https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/entries
// missing in ie only
if (!Object.values) {
  Object.values = function(obj) {
    var ownProps = Object.keys(obj),
      i = ownProps.length,
      resArray = new Array(i); // preallocate the Array
    while (i--) resArray[i] = obj[ownProps[i]];

    return resArray;
  };
}

// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/assign
if (typeof Object.assign !== "function") {
  // Must be writable: true, enumerable: false, configurable: true
  Object.defineProperty(Object, "assign", {
    value: function assign(target) {
      // .length of function is 2
      "use strict";
      if (target == null) {
        // TypeError if undefined or null
        throw new TypeError("Cannot convert undefined or null to object");
      }

      var to = Object(target);

      for (var index = 1; index < arguments.length; index++) {
        var nextSource = arguments[index];

        if (nextSource != null) {
          // Skip over if undefined or null
          for (var nextKey in nextSource) {
            // Avoid bugs when hasOwnProperty is shadowed
            if (Object.prototype.hasOwnProperty.call(nextSource, nextKey)) {
              to[nextKey] = nextSource[nextKey];
            }
          }
        }
      }
      return to;
    },
    writable: true,
    configurable: true
  });
}

// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/includes#Polyfill
/* eslint-disable */
if (!Array.prototype.includes) {
  Object.defineProperty(Array.prototype, "includes", {
    value: function(searchElement, fromIndex) {
      if (this == null) {
        throw new TypeError('"this" is null or not defined');
      }

      // 1. Let O be ? ToObject(this value).
      var o = Object(this);

      // 2. Let len be ? ToLength(? Get(O, "length")).
      var len = o.length >>> 0;

      // 3. If len is 0, return false.
      if (len === 0) {
        return false;
      }

      // 4. Let n be ? ToInteger(fromIndex).
      //    (If fromIndex is undefined, this step produces the value 0.)
      var n = fromIndex | 0;

      // 5. If n ≥ 0, then
      //  a. Let k be n.
      // 6. Else n < 0,
      //  a. Let k be len + n.
      //  b. If k < 0, let k be 0.
      var k = Math.max(n >= 0 ? n : len - Math.abs(n), 0);

      function sameValueZero(x, y) {
        return (
          x === y ||
          (typeof x === "number" &&
            typeof y === "number" &&
            isNaN(x) &&
            isNaN(y))
        );
      }

      // 7. Repeat, while k < len
      while (k < len) {
        // a. Let elementK be the result of ? Get(O, ! ToString(k)).
        // b. If SameValueZero(searchElement, elementK) is true, return true.
        if (sameValueZero(o[k], searchElement)) {
          return true;
        }
        // c. Increase k by 1.
        k++;
      }

      // 8. Return false
      return false;
    }
  });
}

// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/includes#Polyfill
if (!String.prototype.includes) {
  Object.defineProperty(String.prototype, "includes", {
    value: function(search, start) {
      if (typeof start !== "number") {
        start = 0;
      }

      if (start + search.length > this.length) {
        return false;
      } else {
        return this.indexOf(search, start) !== -1;
      }
    }
  });
}

// https://tc39.github.io/ecma262/#sec-array.prototype.find
if (!Array.prototype.find) {
  Object.defineProperty(Array.prototype, "find", {
    value: function(predicate) {
      // 1. Let O be ? ToObject(this value).
      if (this == null) {
        throw new TypeError('"this" is null or not defined');
      }

      var o = Object(this);

      // 2. Let len be ? ToLength(? Get(O, "length")).
      var len = o.length >>> 0;

      // 3. If IsCallable(predicate) is false, throw a TypeError exception.
      if (typeof predicate !== "function") {
        throw new TypeError("predicate must be a function");
      }

      // 4. If thisArg was supplied, let T be thisArg; else let T be undefined.
      var thisArg = arguments[1];

      // 5. Let k be 0.
      var k = 0;

      // 6. Repeat, while k < len
      while (k < len) {
        // a. Let Pk be ! ToString(k).
        // b. Let kValue be ? Get(O, Pk).
        // c. Let testResult be ToBoolean(? Call(predicate, T, « kValue, k, O »)).
        // d. If testResult is true, return kValue.
        var kValue = o[k];
        if (predicate.call(thisArg, kValue, k, o)) {
          return kValue;
        }
        // e. Increase k by 1.
        k++;
      }

      // 7. Return undefined.
      return undefined;
    },
    configurable: true,
    writable: true
  });
}

// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/RegExp/flags#Polyfill
if (RegExp.prototype.flags === undefined) {
  Object.defineProperty(RegExp.prototype, "flags", {
    configurable: true,
    get: function() {
      return this.toString().match(/[gimsuy]*$/)[0];
    }
  });
}

// https://developer.mozilla.org/en-US/docs/Web/API/Element/classList
// IE10/11 polyfill to fully support classList
// 1. String.prototype.trim polyfill
if (!"".trim)
  String.prototype.trim = function() {
    return this.replace(/^[\s﻿]+|[\s﻿]+$/g, "");
  };
(function(window) {
  "use strict"; // prevent global namespace pollution
  function checkIfValidClassListEntry(O, V) {
    if (V === "")
      throw new DOMException(
        "Failed to execute '" +
          O +
          "' on 'DOMTokenList': The token provided must not be empty."
      );
    if ((wsI = V.search(wsRE)) !== -1)
      throw new DOMException(
        "Failed to execute '" +
          O +
          "' on 'DOMTokenList': " +
          "The token provided ('" +
          V[wsI] +
          "') contains HTML space characters, which are not valid in tokens."
      );
  }
  // 2. Implement the barebones DOMTokenList livelyness polyfill
  if (typeof DOMTokenList !== "function")
    (function(window) {
      var document = window.document,
        Object = window.Object,
        hasOwnProp = Object.prototype.hasOwnProperty;
      var defineProperty = Object.defineProperty,
        allowTokenListConstruction = 0,
        skipPropChange = 0;
      var Element = window.Element,
        wsI = 0,
        wsRE = /[\11\12\14\15\40]/; // WhiteSpace Regular Expression
      function DOMTokenList() {
        if (!allowTokenListConstruction) throw TypeError("Illegal constructor"); // internally let it through
      }
      DOMTokenList.prototype.toString = DOMTokenList.prototype.toLocaleString = function() {
        return this.value;
      };
      DOMTokenList.prototype.add = function() {
        a: for (
          var v = 0,
            argLen = arguments.length,
            val = "",
            ele = this["uCL"],
            proto = ele[" uCLp"];
          v !== argLen;
          ++v
        ) {
          (val = arguments[v] + ""), checkIfValidClassListEntry("add", val);
          for (var i = 0, Len = proto.length, resStr = val; i !== Len; ++i)
            if (this[i] === val) continue a;
            else resStr += " " + this[i];
          (this[Len] = val), (proto.length += 1), (proto.value = resStr);
        }
        (skipPropChange = 1),
          (ele.className = proto.value),
          (skipPropChange = 0);
      };
      DOMTokenList.prototype.remove = function() {
        for (
          var v = 0,
            argLen = arguments.length,
            val = "",
            ele = this["uCL"],
            proto = ele[" uCLp"];
          v !== argLen;
          ++v
        ) {
          (val = arguments[v] + ""), checkIfValidClassListEntry("remove", val);
          for (
            var i = 0, Len = proto.length, resStr = "", is = 0;
            i !== Len;
            ++i
          )
            if (is) {
              this[i - 1] = this[i];
            } else {
              if (this[i] !== val) {
                resStr += this[i] + " ";
              } else {
                is = 1;
              }
            }
          if (!is) continue;
          delete this[Len], (proto.length -= 1), (proto.value = resStr);
        }
        (skipPropChange = 1),
          (ele.className = proto.value),
          (skipPropChange = 0);
      };
      window.DOMTokenList = DOMTokenList;
      function whenPropChanges() {
        var evt = window.event,
          prop = evt.propertyName;
        if (
          !skipPropChange &&
          (prop === "className" || (prop === "classList" && !defineProperty))
        ) {
          var target = evt.srcElement,
            protoObjProto = target[" uCLp"],
            strval = "" + target[prop];
          var tokens = strval.trim().split(wsRE),
            resTokenList = target[prop === "classList" ? " uCL" : "classList"];
          var oldLen = protoObjProto.length;
          a: for (
            var cI = 0, cLen = (protoObjProto.length = tokens.length), sub = 0;
            cI !== cLen;
            ++cI
          ) {
            for (var innerI = 0; innerI !== cI; ++innerI)
              if (tokens[innerI] === tokens[cI]) {
                sub++;
                continue a;
              }
            resTokenList[cI - sub] = tokens[cI];
          }
          for (var i = cLen - sub; i < oldLen; ++i) delete resTokenList[i]; //remove trailing indexs
          if (prop !== "classList") return;
          (skipPropChange = 1),
            (target.classList = resTokenList),
            (target.className = strval);
          (skipPropChange = 0), (resTokenList.length = tokens.length - sub);
        }
      }
      function polyfillClassList(ele) {
        if (!ele || !("innerHTML" in ele))
          throw TypeError("Illegal invocation");
        srcEle.detachEvent("onpropertychange", whenPropChanges); // prevent duplicate handler infinite loop
        allowTokenListConstruction = 1;
        try {
          function protoObj() {}
          protoObj.prototype = new DOMTokenList();
        } finally {
          allowTokenListConstruction = 0;
        }
        var protoObjProto = protoObj.prototype,
          resTokenList = new protoObj();
        a: for (
          var toks = ele.className.trim().split(wsRE),
            cI = 0,
            cLen = toks.length,
            sub = 0;
          cI !== cLen;
          ++cI
        ) {
          for (var innerI = 0; innerI !== cI; ++innerI)
            if (toks[innerI] === toks[cI]) {
              sub++;
              continue a;
            }
          this[cI - sub] = toks[cI];
        }
        (protoObjProto.length = Len - sub),
          (protoObjProto.value = ele.className),
          (protoObjProto[" uCL"] = ele);
        if (defineProperty) {
          defineProperty(ele, "classList", {
            // IE8 & IE9 allow defineProperty on the DOM
            enumerable: 1,
            get: function() {
              return resTokenList;
            },
            configurable: 0,
            set: function(newVal) {
              (skipPropChange = 1),
                (ele.className = protoObjProto.value = newVal += ""),
                (skipPropChange = 0);
              var toks = newVal.trim().split(wsRE),
                oldLen = protoObjProto.length;
              a: for (
                var cI = 0,
                  cLen = (protoObjProto.length = toks.length),
                  sub = 0;
                cI !== cLen;
                ++cI
              ) {
                for (var innerI = 0; innerI !== cI; ++innerI)
                  if (toks[innerI] === toks[cI]) {
                    sub++;
                    continue a;
                  }
                resTokenList[cI - sub] = toks[cI];
              }
              for (var i = cLen - sub; i < oldLen; ++i) delete resTokenList[i]; //remove trailing indexs
            }
          });
          defineProperty(ele, " uCLp", {
            // for accessing the hidden prototype
            enumerable: 0,
            configurable: 0,
            writeable: 0,
            value: protoObj.prototype
          });
          defineProperty(protoObjProto, " uCL", {
            enumerable: 0,
            configurable: 0,
            writeable: 0,
            value: ele
          });
        } else {
          (ele.classList = resTokenList),
            (ele[" uCL"] = resTokenList),
            (ele[" uCLp"] = protoObj.prototype);
        }
        srcEle.attachEvent("onpropertychange", whenPropChanges);
      }
      try {
        // Much faster & cleaner version for IE8 & IE9:
        // Should work in IE8 because Element.prototype instanceof Node is true according to the specs
        window.Object.defineProperty(window.Element.prototype, "classList", {
          enumerable: 1,
          get: function(val) {
            if (!hasOwnProp.call(window.Element.prototype, "classList"))
              polyfillClassList(this);
            return this.classList;
          },
          configurable: 0,
          set: function(val) {
            this.className = val;
          }
        });
      } catch (e) {
        // Less performant fallback for older browsers (IE 6-8):
        window[" uCL"] = polyfillClassList;
        // the below code ensures polyfillClassList is applied to all current and future elements in the doc.
        document.documentElement.firstChild.appendChild(
          document.createElement("style")
        ).styleSheet.cssText =
          '_*{x-uCLp:expression(!this.hasOwnProperty("classList")&&window[" uCL"](this))}' + //  IE6
          '[class]{x-uCLp/**/:expression(!this.hasOwnProperty("classList")&&window[" uCL"](this))}'; //IE7-8
      }
    })(window);
  // 3. Patch in unsupported methods in DOMTokenList
  (function(DOMTokenListProto, testClass) {
    if (!DOMTokenListProto.item)
      DOMTokenListProto.item = function(i) {
        function NullCheck(n) {
          return n === void 0 ? null : n;
        }
        return NullCheck(this[i]);
      };
    if (!DOMTokenListProto.toggle || testClass.toggle("a", 0) !== false)
      DOMTokenListProto.toggle = function(val) {
        if (arguments.length > 1)
          return this[arguments[1] ? "add" : "remove"](val), !!arguments[1];
        var oldValue = this.value;
        return (
          this.remove(oldValue),
          oldValue === this.value && (this.add(val), true) /*|| false*/
        );
      };
    if (
      !DOMTokenListProto.replace ||
      typeof testClass.replace("a", "b") !== "boolean"
    )
      DOMTokenListProto.replace = function(oldToken, newToken) {
        checkIfValidClassListEntry("replace", oldToken),
          checkIfValidClassListEntry("replace", newToken);
        var oldValue = this.value;
        return (
          this.remove(oldToken),
          this.value !== oldValue && (this.add(newToken), true)
        );
      };
    if (!DOMTokenListProto.contains)
      DOMTokenListProto.contains = function(value) {
        for (var i = 0, Len = this.length; i !== Len; ++i)
          if (this[i] === value) return true;
        return false;
      };
    if (!DOMTokenListProto.forEach)
      DOMTokenListProto.forEach = function(f) {
        if (arguments.length === 1)
          for (var i = 0, Len = this.length; i !== Len; ++i)
            f(this[i], i, this);
        else
          for (
            var i = 0, Len = this.length, tArg = arguments[1];
            i !== Len;
            ++i
          )
            f.call(tArg, this[i], i, this);
      };
    if (!DOMTokenListProto.entries)
      DOMTokenListProto.entries = function() {
        var nextIndex = 0,
          that = this;
        return {
          next: function() {
            return nextIndex < that.length
              ? { value: [nextIndex, that[nextIndex]], done: false }
              : { done: true };
          }
        };
      };
    if (!DOMTokenListProto.values)
      DOMTokenListProto.values = function() {
        var nextIndex = 0,
          that = this;
        return {
          next: function() {
            return nextIndex < that.length
              ? { value: that[nextIndex], done: false }
              : { done: true };
          }
        };
      };
    if (!DOMTokenListProto.keys)
      DOMTokenListProto.keys = function() {
        var nextIndex = 0,
          that = this;
        return {
          next: function() {
            return nextIndex < that.length
              ? { value: nextIndex, done: false }
              : { done: true };
          }
        };
      };
  })(
    window.DOMTokenList.prototype,
    window.document.createElement("div").classList
  );
})(window);

/* eslint-enable */
