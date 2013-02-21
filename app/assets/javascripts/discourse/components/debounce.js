window.Discourse.debounce = function(func, wait, trickle) {
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
      /* already queued, let it through */
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
