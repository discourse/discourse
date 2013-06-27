/*
 * JavaScript probing framework by Sam Saffron
 * MIT license
 *
 *
 * Examples:
 *
 *  someFunction = window.probes.measure(someFunction, {
 *    name: "somename" // or function(args) { return "name"; },
 *    before: function(data, owner, args) {
 *      // if owner is true, we are not in a recursive function call.
 *      //
 *      // data contains the bucker of data already measuer
 *      // data.count >= 0
 *      // data.time is the total time measured till now
 *      //
 *      // arguments contains the original arguments sent to the function
 *    },
 *    after: function(data, owner, args) {
 *      // same format as before
 *    }
 *  });
 *
 *
 *  // minimal
 *  someFunction = window.probes.measure(someFunction, "someFunction");
 *
 * */
(function(){
  var measure, clear;

  clear = function() {
    window.probes = {
      clear: clear,
      measure: measure
    };
  };

  measure = function(fn,options) {
    // start is outside so we measure time around recursive calls properly
    var start = null, nameParam, before, after;
    if (!options) {
      options = {};
    }

    if (typeof options === "string") {
      nameParam = options;
    }
    else
    {
      nameParam = options.name;

      if (nameParam === "measure" || nameParam === "clear") {
        throw new Error("can not be called measure or clear");
      }

      if (!nameParam)
      {
        throw new Error("you must specify the name option measure(fn, {name: 'some name'})");
      }

      before = options.before;
      after = options.after;
    }

    var now = (function(){
      var perf = window.performance || {};
      var time = perf.now || perf.mozNow || perf.webkitNow || perf.msNow || perf.oNow;
      return time ? time.bind(perf) : function() { return new Date().getTime(); };
    })();

    return function() {
      var name = nameParam;
      if (typeof name === "function"){
        name = nameParam(arguments);
      }
      var p = window.probes[name];
      var owner = (!start);

      if (before) {
        // would like to avoid try catch so its optimised properly by chrome
        before(p, owner, arguments);
      }

      if (p === undefined) {
        window.probes[name] = {count: 0, time: 0, currentTime: 0};
        p = window.probes[name];
      }

      var callStart;
      if (owner) {
        start = now();
        callStart = start;
      }
      else if(after) {
        callStart = now();
      }

      var r = fn.apply(this, arguments);
      if (owner && start) {
        p.time += now() - start;
        start = null;
      }
      p.count += 1;

      if (after) {
        p.currentTime = now() - callStart;
        // would like to avoid try catch so its optimised properly by chrome
        after(p, owner, arguments);
      }

      return r;
    };
  };

  clear();

})();
