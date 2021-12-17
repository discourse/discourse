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
!(function () {
  "use strict";
  function o() {
    var o = window,
      t = document;
    if (
      !(
        "scrollBehavior" in t.documentElement.style &&
        !0 !== o.__forceSmoothScrollPolyfill__
      )
    ) {
      var l,
        e = o.HTMLElement || o.Element,
        r = 468,
        i = {
          scroll: o.scroll || o.scrollTo,
          scrollBy: o.scrollBy,
          elementScroll: e.prototype.scroll || n,
          scrollIntoView: e.prototype.scrollIntoView,
        },
        s =
          o.performance && o.performance.now
            ? o.performance.now.bind(o.performance)
            : Date.now,
        c =
          ((l = o.navigator.userAgent),
          new RegExp(["MSIE ", "Trident/", "Edge/"].join("|")).test(l) ? 1 : 0);
      (o.scroll = o.scrollTo = function () {
        void 0 !== arguments[0] &&
          (!0 !== f(arguments[0])
            ? h.call(
                o,
                t.body,
                void 0 !== arguments[0].left
                  ? ~~arguments[0].left
                  : o.scrollX || o.pageXOffset,
                void 0 !== arguments[0].top
                  ? ~~arguments[0].top
                  : o.scrollY || o.pageYOffset
              )
            : i.scroll.call(
                o,
                void 0 !== arguments[0].left
                  ? arguments[0].left
                  : "object" != typeof arguments[0]
                  ? arguments[0]
                  : o.scrollX || o.pageXOffset,
                void 0 !== arguments[0].top
                  ? arguments[0].top
                  : void 0 !== arguments[1]
                  ? arguments[1]
                  : o.scrollY || o.pageYOffset
              ));
      }),
        (o.scrollBy = function () {
          void 0 !== arguments[0] &&
            (f(arguments[0])
              ? i.scrollBy.call(
                  o,
                  void 0 !== arguments[0].left
                    ? arguments[0].left
                    : "object" != typeof arguments[0]
                    ? arguments[0]
                    : 0,
                  void 0 !== arguments[0].top
                    ? arguments[0].top
                    : void 0 !== arguments[1]
                    ? arguments[1]
                    : 0
                )
              : h.call(
                  o,
                  t.body,
                  ~~arguments[0].left + (o.scrollX || o.pageXOffset),
                  ~~arguments[0].top + (o.scrollY || o.pageYOffset)
                ));
        }),
        (e.prototype.scroll = e.prototype.scrollTo = function () {
          if (void 0 !== arguments[0])
            if (!0 !== f(arguments[0])) {
              var o = arguments[0].left,
                t = arguments[0].top;
              h.call(
                this,
                this,
                void 0 === o ? this.scrollLeft : ~~o,
                void 0 === t ? this.scrollTop : ~~t
              );
            } else {
              if ("number" == typeof arguments[0] && void 0 === arguments[1])
                throw new SyntaxError("Value could not be converted");
              i.elementScroll.call(
                this,
                void 0 !== arguments[0].left
                  ? ~~arguments[0].left
                  : "object" != typeof arguments[0]
                  ? ~~arguments[0]
                  : this.scrollLeft,
                void 0 !== arguments[0].top
                  ? ~~arguments[0].top
                  : void 0 !== arguments[1]
                  ? ~~arguments[1]
                  : this.scrollTop
              );
            }
        }),
        (e.prototype.scrollBy = function () {
          void 0 !== arguments[0] &&
            (!0 !== f(arguments[0])
              ? this.scroll({
                  left: ~~arguments[0].left + this.scrollLeft,
                  top: ~~arguments[0].top + this.scrollTop,
                  behavior: arguments[0].behavior,
                })
              : i.elementScroll.call(
                  this,
                  void 0 !== arguments[0].left
                    ? ~~arguments[0].left + this.scrollLeft
                    : ~~arguments[0] + this.scrollLeft,
                  void 0 !== arguments[0].top
                    ? ~~arguments[0].top + this.scrollTop
                    : ~~arguments[1] + this.scrollTop
                ));
        }),
        (e.prototype.scrollIntoView = function () {
          if (!0 !== f(arguments[0])) {
            var l = (function (o) {
                for (
                  ;
                  o !== t.body &&
                  !1 ===
                    ((e = p((l = o), "Y") && a(l, "Y")),
                    (r = p(l, "X") && a(l, "X")),
                    e || r);

                )
                  o = o.parentNode || o.host;
                var l, e, r;
                return o;
              })(this),
              e = l.getBoundingClientRect(),
              r = this.getBoundingClientRect();
            l !== t.body
              ? (h.call(
                  this,
                  l,
                  l.scrollLeft + r.left - e.left,
                  l.scrollTop + r.top - e.top
                ),
                "fixed" !== o.getComputedStyle(l).position &&
                  o.scrollBy({ left: e.left, top: e.top, behavior: "smooth" }))
              : o.scrollBy({ left: r.left, top: r.top, behavior: "smooth" });
          } else
            i.scrollIntoView.call(
              this,
              void 0 === arguments[0] || arguments[0]
            );
        });
    }
    function n(o, t) {
      (this.scrollLeft = o), (this.scrollTop = t);
    }
    function f(o) {
      if (
        null === o ||
        "object" != typeof o ||
        void 0 === o.behavior ||
        "auto" === o.behavior ||
        "instant" === o.behavior
      )
        return !0;
      if ("object" == typeof o && "smooth" === o.behavior) return !1;
      throw new TypeError(
        "behavior member of ScrollOptions " +
          o.behavior +
          " is not a valid value for enumeration ScrollBehavior."
      );
    }
    function p(o, t) {
      return "Y" === t
        ? o.clientHeight + c < o.scrollHeight
        : "X" === t
        ? o.clientWidth + c < o.scrollWidth
        : void 0;
    }
    function a(t, l) {
      var e = o.getComputedStyle(t, null)["overflow" + l];
      return "auto" === e || "scroll" === e;
    }
    function d(t) {
      var l,
        e,
        i,
        c,
        n = (s() - t.startTime) / r;
      (c = n = n > 1 ? 1 : n),
        (l = 0.5 * (1 - Math.cos(Math.PI * c))),
        (e = t.startX + (t.x - t.startX) * l),
        (i = t.startY + (t.y - t.startY) * l),
        t.method.call(t.scrollable, e, i),
        (e === t.x && i === t.y) || o.requestAnimationFrame(d.bind(o, t));
    }
    function h(l, e, r) {
      var c,
        f,
        p,
        a,
        h = s();
      l === t.body
        ? ((c = o),
          (f = o.scrollX || o.pageXOffset),
          (p = o.scrollY || o.pageYOffset),
          (a = i.scroll))
        : ((c = l), (f = l.scrollLeft), (p = l.scrollTop), (a = n)),
        d({
          scrollable: c,
          method: a,
          startTime: h,
          startX: f,
          startY: p,
          x: e,
          y: r,
        });
    }
  }
  "object" == typeof exports && "undefined" != typeof module
    ? (module.exports = { polyfill: o })
    : o();
})();

/* eslint-enable */
