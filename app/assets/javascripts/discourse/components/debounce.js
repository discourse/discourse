/**
  Debounce a Javascript function. This means if it's called many times in a time limit it
  should only be executed once.

  @method debounce
  @module Discourse
  @param {function} func The function to debounce
  @param {Numbers} wait how long to wait
**/
Discourse.debounce = function(func, wait) {
  var timeout = null;

  return function() {
    var context = this;
    var args = arguments;

    var later = function() {
      timeout = null;
      return func.apply(context, args);
    };

    if (timeout) return;

    var currentWait;
    if (typeof wait === "function") {
      currentWait = wait();
    } else {
      currentWait = wait;
    }

    if (timeout) {
      clearTimeout(timeout);
    }

    timeout = setTimeout(later, currentWait);
    return timeout;
  };
};
