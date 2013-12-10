/* global discourseUrl */
/* global discourseEmbedUrl */
(function() {

  var comments = document.getElementById('discourse-comments'),
      iframe = document.createElement('iframe');
  iframe.src = discourseUrl + "embed/best?embed_url=" + encodeURIComponent(discourseEmbedUrl);
  iframe.id = 'discourse-embed-frame';
  iframe.width = "100%";
  iframe.frameBorder = "0";
  iframe.scrolling = "no";
  comments.appendChild(iframe);


  function postMessageReceived(e) {
    if (!e) { return; }
    if (discourseUrl.indexOf(e.origin) === -1) { return; }

    if (e.data) {
      if (e.data.type === 'discourse-resize' && e.data.height) {
        iframe.height = e.data.height + "px";
      }
    }
  }
  window.addEventListener('message', postMessageReceived, false);

})();
