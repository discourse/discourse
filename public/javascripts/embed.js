/* global discourseUrl */
/* global discourseUserName */
/* global discourseEmbedUrl */
(function() {
  var comments = document.getElementById('discourse-comments'),
  iframe = document.createElement('iframe');
  if (typeof discourseUserName === 'undefined') {
    iframe.src =
      [ discourseUrl,
        'embed/comments?embed_url=',
        encodeURIComponent(discourseEmbedUrl)
      ].join('');
  } else {
    iframe.src =
      [ discourseUrl,
        'embed/comments?embed_url=',
        encodeURIComponent(discourseEmbedUrl),
        '&discourse_username=',
        discourseUserName
      ].join('');
  }
  iframe.id = 'discourse-embed-frame';
  iframe.width = "100%";
  iframe.frameBorder = "0";
  iframe.scrolling = "no";
  comments.appendChild(iframe);

  // Thanks http://amendsoft-javascript.blogspot.ca/2010/04/find-x-and-y-coordinate-of-html-control.html
  function findPosY(obj)
  {
    var top = 0;
    if(obj.offsetParent)
    {
        while(1)
        {
          top += obj.offsetTop;
          if(!obj.offsetParent)
            break;
          obj = obj.offsetParent;
        }
    }
    else if(obj.y)
    {
        top += obj.y;
    }
    return top;
  }

  function postMessageReceived(e) {
    if (!e) { return; }
    if (discourseUrl.indexOf(e.origin) === -1) { return; }

    if (e.data) {
      if (e.data.type === 'discourse-resize' && e.data.height) {
        iframe.height = e.data.height + "px";
      }

      if (e.data.type === 'discourse-scroll' && e.data.top) {
        // find iframe offset
        var destY = findPosY(iframe) + e.data.top;
        window.scrollTo(0, destY);
      }
    }
  }
  window.addEventListener('message', postMessageReceived, false);

})();
