console.log('Starting Smoke Test');
var system = require('system');

if(system.args.length !== 2) {
  console.log("expecting phantomjs {smoke_test.js} {base_url}");
  phantom.exit(1);
}

var page = require('webpage').create();

page.waitFor = function(desc, fn, t) {
  var check,start,promise;

  console.log("RUNNING: " + desc);

  start = +new Date();
  promise = {};
  check = function() {
    var r;

    try {
      r = page.evaluate(fn);
    } 
    catch(err) {
      // next time
    }

    if(r) {
      promise.success = true;
      console.log("PASSED: " + desc);
    } else {
      var diff = (+new Date()) - start;
      if(diff > t) {
        promise.failure = true;
        console.log("FAILED: " + desc);
      } else {
        setTimeout(check, 50);
      }
    }
  };

  check();
  return promise;
};

function afterAll(promises, fn){
  var i;
  var test = function(){
    var good = true;
    var allDone = true;
    
    for(i=0;i<promises.length;i++){
      good = good && promises[i].success; 
      allDone = allDone && (promises[i].success || promises[i].failure);
    }

    if(allDone){
      fn(good);
    } else {
      setTimeout(test, 50);
    }
  };
  test();
}

page.open(system.args[1], function (status) {
    
    console.log("Opened " + system.args[1]);

    var gotTopics = page.waitFor("more than one topic shows up" , function(){ 
      return ($('#topic-list tbody tr').length > 0); 
    }, 5000);

    afterAll([gotTopics], function(success){
      if(success) {
        console.log("ALL PASSED");
      }
      phantom.exit();
    });
});
