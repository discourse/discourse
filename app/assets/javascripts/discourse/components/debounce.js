/**
  Debounce a Javascript function. This means if it's called many times in a time limit it
  should only be executed once.

  @method debounce
  @module Discourse
  @param {function} func The function to debounce
  @param {Numbers} wait how long to wait
  @param {Boolean} trickle 
**/
Discourse.debounce = function(func, wait, trickle) {
  var timeout;

  timeout = null;
  return function() {
    var args, context, currentWait, later;
    context = this;
    args = arguments;
    later = function() {
      timeout = null;
      return func.apply(context, args);
    };

    if (timeout && trickle) {
      // already queued, let it through
      return;
    }

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
