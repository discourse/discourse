import { run } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
const _loaded = {};
const _loading = {};

function loadWithTag(path, cb) {
  const head = document.getElementsByTagName("head")[0];

  let finished = false;
  let s = document.createElement("script");
  s.src = path;
  if (Ember.Test) {
    Ember.Test.registerWaiter(() => finished);
  }

  s.onload = s.onreadystatechange = function(_, abort) {
    finished = true;
    if (
      abort ||
      !s.readyState ||
      s.readyState === "loaded" ||
      s.readyState === "complete"
    ) {
      s = s.onload = s.onreadystatechange = null;
      if (!abort) {
        run(null, cb);
      }
    }
  };

  head.appendChild(s);
}

export function loadCSS(url) {
  return loadScript(url, { css: true });
}

export default function loadScript(url, opts) {
  // TODO: Remove this once plugins have been updated not to use it:
  if (url === "defer/html-sanitizer-bundle") {
    return Ember.RSVP.Promise.resolve();
  }

  opts = opts || {};

  // Scripts should always load from CDN
  // CSS is type text, to accept it from a CDN we would need to handle CORS
  url = opts.css ? Discourse.getURL(url) : Discourse.getURLWithCDN(url);

  $("script").each((i, tag) => {
    const src = tag.getAttribute("src");

    if (src && src !== url && !_loading[src]) {
      _loaded[src] = true;
    }
  });

  return new Ember.RSVP.Promise(function(resolve) {
    // If we already loaded this url
    if (_loaded[url]) {
      return resolve();
    }
    if (_loading[url]) {
      return _loading[url].then(resolve);
    }

    let done;
    _loading[url] = new Ember.RSVP.Promise(function(_done) {
      done = _done;
    });

    _loading[url].then(function() {
      delete _loading[url];
    });

    const cb = function(data) {
      if (opts && opts.css) {
        $("head").append("<style>" + data + "</style>");
      }
      done();
      resolve();
      _loaded[url] = true;
    };

    if (opts.css) {
      ajax({
        url: url,
        dataType: "text",
        cache: true
      }).then(cb);
    } else {
      // Always load JavaScript with script tag to avoid Content Security Policy inline violations
      loadWithTag(url, cb);
    }
  });
}
