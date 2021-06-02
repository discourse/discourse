import getURL, { getURLWithCDN } from "discourse-common/lib/get-url";
import { PUBLIC_JS_VERSIONS } from "discourse/lib/public-js-versions";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import { run } from "@ember/runloop";

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

  s.onload = s.onreadystatechange = function (_, abort) {
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
    return Promise.resolve();
  }

  opts = opts || {};

  if (_loaded[url]) {
    return Promise.resolve();
  }

  if (PUBLIC_JS_VERSIONS) {
    url = cacheBuster(url);
  }

  // Scripts should always load from CDN
  // CSS is type text, to accept it from a CDN we would need to handle CORS
  const fullUrl = opts.css ? getURL(url) : getURLWithCDN(url);

  $("script").each((i, tag) => {
    const src = tag.getAttribute("src");

    if (src && src !== fullUrl && !_loading[src]) {
      _loaded[src] = true;
    }
  });

  return new Promise(function (resolve) {
    // If we already loaded this url
    if (_loaded[fullUrl]) {
      return resolve();
    }
    if (_loading[fullUrl]) {
      return _loading[fullUrl].then(resolve);
    }

    let done;
    _loading[fullUrl] = new Promise(function (_done) {
      done = _done;
    });

    _loading[fullUrl].then(function () {
      delete _loading[fullUrl];
    });

    const cb = function (data) {
      if (opts && opts.css) {
        $("head").append("<style>" + data + "</style>");
      }
      done();
      resolve();
      _loaded[url] = true;
      _loaded[fullUrl] = true;
    };

    if (opts.css) {
      ajax({
        url: fullUrl,
        dataType: "text",
      }).then(cb);
    } else {
      // Always load JavaScript with script tag to avoid Content Security Policy inline violations
      loadWithTag(fullUrl, cb);
    }
  });
}

export function cacheBuster(url) {
  if (PUBLIC_JS_VERSIONS) {
    let [folder, ...lib] = url.split("/").filter(Boolean);
    if (folder === "javascripts") {
      lib = lib.join("/");
      const versionedPath = PUBLIC_JS_VERSIONS[lib];
      if (versionedPath) {
        return `/javascripts/${versionedPath}`;
      }
    }
  }

  return url;
}
