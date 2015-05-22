/* global assetPath */

const _loaded = {};
const _loading = {};

function loadWithTag(path, cb) {
  const head = document.getElementsByTagName('head')[0];

  let s = document.createElement('script');
  s.src = path;
  if (Ember.Test) { Ember.Test.pendingAjaxRequests++; }
  head.appendChild(s);

  s.onload = s.onreadystatechange = function(_, abort) {
    if (Ember.Test) { Ember.Test.pendingAjaxRequests--; }
    if (abort || !s.readyState || s.readyState === "loaded" || s.readyState === "complete") {
      s = s.onload = s.onreadystatechange = null;
      if (!abort) {
        Ember.run(null, cb);
      }
    }
  };
}

export default function loadScript(url, opts) {
  opts = opts || {};

  return new Ember.RSVP.Promise(function(resolve) {
    url = Discourse.getURL((assetPath && assetPath(url)) || url);

    // If we already loaded this url
    if (_loaded[url]) { return resolve(); }
    if (_loading[url]) { return _loading[url].then(resolve);}

    var done;
    _loading[url] = new Ember.RSVP.Promise(function(_done){
      done = _done;
    });

    _loading[url].then(function(){
      delete _loading[url];
    });

    const cb = function() {
      _loaded[url] = true;
      done();
      resolve();
    };

    var cdnUrl = url;

    // Scripts should always load from CDN
    if (Discourse.CDN && url[0] === "/" && url[1] !== "/") {
      cdnUrl = Discourse.CDN.replace(/\/$/,"") + url;
    }

    // Some javascript depends on the path of where it is loaded (ace editor)
    // to dynamically load more JS. In that case, add the `scriptTag: true`
    // option.
    if (opts.scriptTag) {
      loadWithTag(cdnUrl, cb);
    } else {
      Discourse.ajax({url: cdnUrl, dataType: "script", cache: true}).then(cb);
    }
  });
}
