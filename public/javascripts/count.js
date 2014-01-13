/* global discourseUrl:true */

(function() {


  // Discover the URLs we want counts for
  var links = document.getElementsByTagName("a"),
      countFor = [];

  for(var i=0; i<links.length; i++) {
    var href = links[i].href;
    if (href && href.length) {
      var m = /^(.*)#discourse-comments$/.exec(href);
      if (m && m[1]) { countFor.push(m[1]); }
    }
  }
  //
  // JSONP callback to update counts
  window.discourseUpdateCounts = function(result) {
    if (result && result.counts) {
      var byUrl = result.counts;
      for (var i=0; i<links.length; i++) {
        var link = links[i],
            linkCount = byUrl[link];

        if (linkCount) {
          var t = document.createTextNode(" (" + linkCount + ")");
          link.appendChild(t);
        }
      }
    }
  };

  if (countFor.length > 0) {
    // Send JSONP request for the counts
    var d = document.createElement('script');
    d.src = discourseUrl + "embed/count?callback=discourseUpdateCounts&";

    for (var j=0; j<countFor.length; j++) {
      d.src += "&" + "embed_url[]=" + encodeURIComponent(countFor[j]);
    }
    (document.getElementsByTagName('head')[0] || document.getElementsByTagName('body')[0]).appendChild(d);
  }

})(); 
