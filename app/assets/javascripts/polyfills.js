/* eslint-disable */

// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/RegExp/flags#Polyfill
// IE and EDGE
if (RegExp.prototype.flags === undefined) {
  Object.defineProperty(RegExp.prototype, "flags", {
    configurable: true,
    get: function () {
      return this.toString().match(/[gimsuy]*$/)[0];
    },
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

// Needed for Safari 15.2 and below
// from: https://github.com/iamdustan/smoothscroll
(function () {
  "use strict";

  function e() {
    var e = window;
    var t = document;
    if (
      "scrollBehavior" in t.documentElement.style &&
      e.__forceSmoothScrollPolyfill__ !== true
    ) {
      return;
    }
    var o = e.HTMLElement || e.Element;
    var r = 1.8;
    var l = {
      scroll: e.scroll || e.scrollTo,
      scrollBy: e.scrollBy,
      elementScroll: o.prototype.scroll || s,
      scrollIntoView: o.prototype.scrollIntoView,
    };
    var n =
      e.performance && e.performance.now
        ? e.performance.now.bind(e.performance)
        : Date.now;

    function i(e) {
      var t = ["MSIE ", "Trident/", "Edge/"];
      return new RegExp(t.join("|")).test(e);
    }
    var f = i(e.navigator.userAgent) ? 1 : 0;

    function s(e, t) {
      this.scrollLeft = e;
      this.scrollTop = t;
    }

    function c(e) {
      return 0.5 * (1 - Math.cos(Math.PI * e));
    }

    function a(e) {
      if (
        e === null ||
        typeof e !== "object" ||
        e.behavior === undefined ||
        e.behavior === "auto" ||
        e.behavior === "instant"
      ) {
        return true;
      }
      if (typeof e === "object" && e.behavior === "smooth") {
        return false;
      }
      throw new TypeError(
        "behavior member of ScrollOptions " +
          e.behavior +
          " is not a valid value for enumeration ScrollBehavior."
      );
    }

    function u(e, t) {
      if (t === "Y") {
        return e.clientHeight + f < e.scrollHeight;
      }
      if (t === "X") {
        return e.clientWidth + f < e.scrollWidth;
      }
    }

    function d(t, o) {
      var r = e.getComputedStyle(t, null)["overflow" + o];
      return r === "auto" || r === "scroll";
    }

    function p(e) {
      var t = u(e, "Y") && d(e, "Y");
      var o = u(e, "X") && d(e, "X");
      return t || o;
    }

    function h(e) {
      while (e !== t.body && p(e) === false) {
        e = e.parentNode || e.host;
      }
      return e;
    }

    function v(e, t) {
      var o = r / t;
      var l = Math.pow(1.16, Math.max(e / 80, 1));
      return o * e * (1 / l);
    }

    function y(t) {
      var o = n();
      var r = e.devicePixelRatio;
      var l;
      var i;
      var f;
      var s;
      var a = v(Math.abs(t.x - t.startX), r);
      var u = v(Math.abs(t.y - t.startY), r);
      var d = (o - t.startTime) / a;
      var p = (o - t.startTime) / u;
      d = d > 1 ? 1 : d;
      p = p > 1 ? 1 : p;
      l = c(d);
      i = c(p);
      f = t.startX + (t.x - t.startX) * l;
      s = t.startY + (t.y - t.startY) * i;
      t.method.call(t.scrollable, f, s);
      if (f !== t.x || s !== t.y) {
        e.requestAnimationFrame(y.bind(e, t));
      }
    }

    function m(o, r, i) {
      var f;
      var c;
      var a;
      var u;
      var d = n();
      if (o === t.body) {
        f = e;
        c = e.scrollX || e.pageXOffset;
        a = e.scrollY || e.pageYOffset;
        u = l.scroll;
      } else {
        f = o;
        c = o.scrollLeft;
        a = o.scrollTop;
        u = s;
      }
      y({
        scrollable: f,
        method: u,
        startTime: d,
        startX: c,
        startY: a,
        x: r,
        y: i,
      });
    }
    e.scroll = e.scrollTo = function () {
      if (arguments[0] === undefined) {
        return;
      }
      if (a(arguments[0]) === true) {
        l.scroll.call(
          e,
          arguments[0].left !== undefined
            ? arguments[0].left
            : typeof arguments[0] !== "object"
            ? arguments[0]
            : e.scrollX || e.pageXOffset,
          arguments[0].top !== undefined
            ? arguments[0].top
            : arguments[1] !== undefined
            ? arguments[1]
            : e.scrollY || e.pageYOffset
        );
        return;
      }
      m.call(
        e,
        t.body,
        arguments[0].left !== undefined
          ? ~~arguments[0].left
          : e.scrollX || e.pageXOffset,
        arguments[0].top !== undefined
          ? ~~arguments[0].top
          : e.scrollY || e.pageYOffset
      );
    };
    e.scrollBy = function () {
      if (arguments[0] === undefined) {
        return;
      }
      if (a(arguments[0])) {
        l.scrollBy.call(
          e,
          arguments[0].left !== undefined
            ? arguments[0].left
            : typeof arguments[0] !== "object"
            ? arguments[0]
            : 0,
          arguments[0].top !== undefined
            ? arguments[0].top
            : arguments[1] !== undefined
            ? arguments[1]
            : 0
        );
        return;
      }
      m.call(
        e,
        t.body,
        ~~arguments[0].left + (e.scrollX || e.pageXOffset),
        ~~arguments[0].top + (e.scrollY || e.pageYOffset)
      );
    };
    o.prototype.scroll = o.prototype.scrollTo = function () {
      if (arguments[0] === undefined) {
        return;
      }
      if (a(arguments[0]) === true) {
        if (typeof arguments[0] === "number" && arguments[1] === undefined) {
          throw new SyntaxError("Value could not be converted");
        }
        l.elementScroll.call(
          this,
          arguments[0].left !== undefined
            ? ~~arguments[0].left
            : typeof arguments[0] !== "object"
            ? ~~arguments[0]
            : this.scrollLeft,
          arguments[0].top !== undefined
            ? ~~arguments[0].top
            : arguments[1] !== undefined
            ? ~~arguments[1]
            : this.scrollTop
        );
        return;
      }
      var e = arguments[0].left;
      var t = arguments[0].top;
      m.call(
        this,
        this,
        typeof e === "undefined" ? this.scrollLeft : ~~e,
        typeof t === "undefined" ? this.scrollTop : ~~t
      );
    };
    o.prototype.scrollBy = function () {
      if (arguments[0] === undefined) {
        return;
      }
      if (a(arguments[0]) === true) {
        l.elementScroll.call(
          this,
          arguments[0].left !== undefined
            ? ~~arguments[0].left + this.scrollLeft
            : ~~arguments[0] + this.scrollLeft,
          arguments[0].top !== undefined
            ? ~~arguments[0].top + this.scrollTop
            : ~~arguments[1] + this.scrollTop
        );
        return;
      }
      this.scroll({
        left: ~~arguments[0].left + this.scrollLeft,
        top: ~~arguments[0].top + this.scrollTop,
        behavior: arguments[0].behavior,
      });
    };
    o.prototype.scrollIntoView = function () {
      if (a(arguments[0]) === true) {
        l.scrollIntoView.call(
          this,
          arguments[0] === undefined ? true : arguments[0]
        );
        return;
      }
      var o = h(this);
      var r = o.getBoundingClientRect();
      var n = this.getBoundingClientRect();
      if (o !== t.body) {
        m.call(
          this,
          o,
          o.scrollLeft + n.left - r.left,
          o.scrollTop + n.top - r.top
        );
        if (e.getComputedStyle(o).position !== "fixed") {
          e.scrollBy({
            left: r.left,
            top: r.top,
            behavior: "smooth",
          });
        }
      } else {
        e.scrollBy({
          left: n.left,
          top: n.top,
          behavior: "smooth",
        });
      }
    };
  }
  if (typeof exports === "object" && typeof module !== "undefined") {
    module.exports = {
      polyfill: e,
    };
  } else {
    e();
  }
})();

/* eslint-enable */
