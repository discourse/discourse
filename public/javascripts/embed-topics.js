(function() {
  function postMessageReceived(e) {
    if (!e) {
      return;
    }

    if (e.data && e.data.type === "discourse-resize" && e.data.embedId) {
      var elem = document.getElementById(e.data.embedId);
      if (elem) {
        elem.height = e.data.height + "px";
      }
    }
  }
  window.addEventListener("message", postMessageReceived, false);

  document.addEventListener("DOMContentLoaded", function(event) {
    var lists = document.querySelectorAll("d-topics-list");

    for (var i = 0; i < lists.length; i++) {
      var list = lists[i];
      var url = list.getAttribute("discourse-url");
      if (!url || url.length === 0) {
        console.error("Error, `data-discourse-url` was not found");
        continue;
      }
      var frameId =
        "de-" +
        Math.random()
          .toString(36)
          .substr(2, 9);
      var params = ["discourse_embed_id=" + frameId];
      list.removeAttribute("discourse-url");

      for (var j = 0; j < list.attributes.length; j++) {
        var attr = list.attributes[j];
        params.push(attr.name.replace("-", "_") + "=" + attr.value);
      }

      var iframe = document.createElement("iframe");
      iframe.src = url + "/embed/topics?" + params.join("&");
      iframe.id = frameId;
      iframe.frameBorder = 0;
      iframe.scrolling = "no";
      list.appendChild(iframe);
    }
  });
})();
