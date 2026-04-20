import { run } from "@ember/runloop";
import { buildWaiter } from "@ember/test-waiters";
import { Promise } from "rsvp";
import getURL, { getURLWithCDN } from "discourse/lib/get-url";

const WAITER = buildWaiter("load-script");
const _loaded = {};
const _loading = {};

function loadWithTag(path, cb, errorCb) {
  const head = document.getElementsByTagName("head")[0];

  let s = document.createElement("script");
  s.src = path;

  const token = WAITER.beginAsync();

  s.onerror = function () {
    s.onload = s.onreadystatechange = null;
    s.remove();
    WAITER.endAsync(token);

    // TODO: Remove after diagnosing flaky loadScript failures
    {
      // eslint-disable-next-line no-console
      const log = (msg) => console.error(`[load-script diagnostic] ${msg}`);

      const entries = performance.getEntriesByName(
        new URL(path, location.href).href,
        "resource"
      );
      const entry = entries[entries.length - 1];
      if (entry) {
        log(
          `${path} timing: status=${entry.responseStatus} transfer=${entry.transferSize} ` +
            `encoded=${entry.encodedBodySize} duration=${Math.round(entry.duration)}ms ` +
            `responseStart=${Math.round(entry.responseStart)}ms type=${entry.initiatorType}`
        );
      } else {
        log(`${path} — no resource timing entry`);
      }

      // Discourse-Script header lets the request pass through Pretender
      fetch(path, {
        cache: "no-store",
        headers: { "Discourse-Script": "true" },
      }).then(
        (r) =>
          r.text().then((body) =>
            log(
              `${path} fetch probe: ${r.status} type=${r.headers.get("content-type")} ` +
                `length=${r.headers.get("content-length")} body=${body.slice(0, 200)}`
            )
          ),
        (e) => log(`${path} fetch probe failed: ${e.message || e}`)
      );
    }

    if (errorCb) {
      run(null, errorCb);
    }
  };

  s.onload = s.onreadystatechange = function (_, abort) {
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

    WAITER.endAsync(token);
  };

  head.appendChild(s);
}

export function loadCSS(url) {
  return loadScript(url, { css: true });
}

export default function loadScript(url, opts = {}) {
  if (_loaded[url]) {
    return Promise.resolve();
  }

  // Scripts load from CDN, CSS loads from same origin to avoid CORS issues with fonts
  const fullUrl = opts.css ? getURL(url) : getURLWithCDN(url);

  document.querySelectorAll("script").forEach((element) => {
    const src = element.getAttribute("src");

    if (src && src !== fullUrl && !_loading[src]) {
      _loaded[src] = true;
    }
  });

  return new Promise(function (resolve, reject) {
    // If we already loaded this url
    if (_loaded[fullUrl]) {
      return resolve();
    }

    if (_loading[fullUrl]) {
      return _loading[fullUrl].then(resolve, reject);
    }

    let done;
    let fail;
    _loading[fullUrl] = new Promise(function (_done, _fail) {
      done = _done;
      fail = _fail;
    });

    _loading[fullUrl].finally(() => delete _loading[fullUrl]).catch(() => {});

    const cb = function () {
      done();
      resolve();
      _loaded[url] = true;
      _loaded[fullUrl] = true;
    };

    const errorCb = function () {
      const error = new Error(`Failed to load ${fullUrl}`);
      fail(error);
      reject(error);
    };

    if (opts.css) {
      // Use <link> tag for CSS to preserve URL context for relative paths (e.g., fonts)
      const link = document.createElement("link");
      link.rel = "stylesheet";
      link.href = fullUrl;

      const token = WAITER.beginAsync();

      link.onerror = function () {
        link.onload = null;
        WAITER.endAsync(token);
        run(null, errorCb);
      };

      link.onload = function () {
        run(null, cb);
        WAITER.endAsync(token);
      };

      document.querySelector("head").appendChild(link);
    } else {
      // Always load JavaScript with script tag to avoid Content Security Policy inline violations
      loadWithTag(fullUrl, cb, errorCb);
    }
  });
}
