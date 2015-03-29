/* global discourseUrl:true */

(function() {


  // Discover the URLs we want counts for
  var links = document.getElementsByTagName("a"),
      countFor = [];

  for(var i=0; i<links.length; i++) {
    var link = links[i],
        href = link.href;
    if (href && href.length) {
      if (/#discourse-comments$/.test(href)) {
        countFor.push(href);
      }
    }

    var dataEmbed = link.getAttribute('data-discourse-embed-url');
    if (dataEmbed && dataEmbed.length) {
      countFor.push(dataEmbed);
    }
  }

  // JSONP callback to update counts
  window.discourseUpdateCounts = function(result) {
    if (result && result.counts) {
      var byUrl = result.counts;
      for (var i=0; i<links.length; i++) {
        var link = links[i],
            linkCount = byUrl[link.href] || byUrl[link.href.replace(/\/#/, '#')];

        if (linkCount) {
          var t = document.createTextNode(" (" + linkCount + ")");
          link.appendChild(t);
        }
      }
    }
  };

  if (countFor.length > 0) {
    // Send JSONP request for the counts
    var d = document.createElement('script'),
        srcUrl = discourseUrl + "embed/count?callback=discourseUpdateCounts";

    for (var j=0; j<countFor.length; j++) {
      srcUrl += "&" + "embed_url[]=" + encodeURIComponent(countFor[j]);
    }
    d.src = srcUrl;
    (document.getElementsByTagName('head')[0] || document.getElementsByTagName('body')[0]).appendChild(d);
  }

})();
