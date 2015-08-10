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
      measure: measure,
      displayProbes: displayProbes
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

  var displayProbes = function(){
     var pre;
     var text = "";
     var body = document.getElementsByTagName("body")[0];

     for(var prop in window.probes){
       var probe = window.probes[prop];
       if(probe && probe.count){
          text += prop + ": " + probe.time + " ( " + probe.count + " )\n";
       }
     }

     pre = document.getElementById("__probes");

     if(!body){
       return;
     }

     if(pre){
       pre.textContent = text;
       pre.innerText = text;
       return;
     }

     var div = document.createElement("div");
     div.id = "__probes_wrapper";
     div.setAttribute("style", "position: fixed; bottom: 25px; left: 50px; z-index: 99999; border: 1px solid #777; padding: 10px; background-color: rgba(255,255,255, 0.8);");

     pre = document.createElement("pre");
     pre.setAttribute("style", "margin:0 0 5px;");
     pre.textContent = text;
     pre.innerText = text;
     pre.id = "__probes";

     div.appendChild(pre);

     var a = document.createElement('a');
     a.href = "";
     a.innerText = "clear";
     a.addEventListener("click", function(e){
        for(var prop in window.probes){
          var probe = window.probes[prop];
          if(probe && probe.count){
            delete window.probes[prop];
          }
        }
        displayProbes();
        e.preventDefault();
     });

     div.appendChild(a);

     body.appendChild(div);
  };


  // setInterval(displayProbes, 1000);
  clear();

})();
