(function(document, $) {

  // cf. http://mths.be/details
  var hasNativeSupport = (function(doc) {
    var fake, el = doc.createElement("details");
    // fail-fast
    if (!("open" in el)) { return false; }
    // figure out a root node
    var root = doc.body || (function() {
      var de = doc.documentElement;
      fake = true;
      return de.insertBefore(doc.createElement("body"), de.firstElementChild || de.firstChild);
    })();
    // setup test element
    el.innerHTML = "<summary>a</summary>b";
    el.style.display = "block";
    // add test element to the root node
    root.appendChild(el);
    // can we open it?
    var diff = el.offsetHeight;
    el.open = true;
    diff = diff !== el.offsetHeight;
    // cleanup
    root.removeChild(el);
    if (fake) { root.parentNode.removeChild(root); }
    // return the result
    return diff;
  })(document);

  function toggleOpen($details) {
    $details.toggleClass("open");
  }

  $.fn.details = function() {
    if (hasNativeSupport) { return this; }

    return this.each(function() {
      var $details = $(this),
          $firstSummary = $("summary", $details).first();

      $firstSummary.prop("tabIndex", 0);

      $firstSummary.on("keydown", function(event) {
        if (event.keyCode === 32 /* SPACE */ || event.keyCode === 13 /* ENTER */) {
          toggleOpen($details);
          return false;
        }
      });

      $firstSummary.on("click", function() {
        $firstSummary.focus();
        toggleOpen($details);
      });

    });
  };

})(document, jQuery);
