/* eslint-disable */

// Any IE only polyfill should be moved in discourse-internet-explorer plugin

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

/* eslint-enable */
