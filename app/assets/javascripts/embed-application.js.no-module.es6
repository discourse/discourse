(function() {
  const referer = document.getElementById("data-embedded").dataset.referer;

  function postUp(msg) {
    if (parent) {
      parent.postMessage(msg, referer);
    }
  }

  function clickPostLink(e) {
    var postId = e.target.getAttribute("data-link-to-post");
    if (postId) {
      var postElement = document.getElementById("post-" + postId);
      if (postElement) {
        var rect = postElement.getBoundingClientRect();
        if (rect && rect.top) {
          postUp({ type: "discourse-scroll", top: rect.top });
          e.preventDefault();
          return false;
        }
      }
    }
  }

  window.onload = function() {
    // get state info from data attribute
    var embedState = document.querySelector("[data-embed-state]");
    var state = "unknown";
    var embedId = null;
    if (embedState) {
      state = embedState.getAttribute("data-embed-state");
      embedId = embedState.getAttribute("data-embed-id");
    }

    // Send a post message with our loaded height and state
    postUp({
      type: "discourse-resize",
      height: document["body"].offsetHeight,
      state,
      embedId
    });

    var postLinks = document.querySelectorAll("a[data-link-to-post]"),
      i;

    for (i = 0; i < postLinks.length; i++) {
      postLinks[i].onclick = clickPostLink;
    }

    // Make sure all links in the iframe point to _blank
    var cookedLinks = document.querySelectorAll(".cooked a");
    for (i = 0; i < cookedLinks.length; i++) {
      cookedLinks[i].target = "_blank";
    }

    // Adjust all names
    var names = document.querySelectorAll(".username a");
    for (i = 0; i < names.length; i++) {
      var username = names[i].innerHTML;
      if (username) {
        /* global BreakString */
        names[i].innerHTML = new BreakString(username).break();
      }
    }
  };
})();
