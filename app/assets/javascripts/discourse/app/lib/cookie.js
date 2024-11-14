import deprecated from "discourse-common/lib/deprecated";

const pluses = /\+/g;

function parseCookieValue(s) {
  if (s.startsWith('"')) {
    // This is a quoted cookie as according to RFC2068, unescape...
    s = s.slice(1, -1).replace(/\\"/g, '"').replace(/\\\\/g, "\\");
  }

  try {
    // Replace server-side written pluses with spaces.
    // If we can't decode the cookie, ignore it, it's unusable.
    // If we can't parse the cookie, ignore it, it's unusable.
    s = decodeURIComponent(s.replace(pluses, " "));
    return s;
  } catch {}
}

function cookie(key, value, options) {
  // Write
  if (value !== undefined) {
    options = { ...(options || {}) };

    if (typeof options.expires === "number") {
      let days = options.expires,
        t = (options.expires = new Date());
      t.setTime(+t + days * 864e5);
    }

    return (document.cookie = [
      encodeURIComponent(key),
      "=",
      encodeURIComponent(String(value)),
      options.expires ? "; expires=" + options.expires.toUTCString() : "", // use expires attribute, max-age is not supported by IE
      options.path ? "; path=" + options.path : "",
      options.domain ? "; domain=" + options.domain : "",
      options.secure ? "; secure" : "",
      ";samesite=Lax",
    ].join(""));
  }

  // Read
  let result = key ? undefined : {};

  // To prevent the for loop in the first place assign an empty array
  // in case there are no cookies at all. Also prevents odd result when
  // calling cookie().
  let cookies = document.cookie ? document.cookie.split("; ") : [];

  for (let i = 0, l = cookies.length; i < l; i++) {
    let parts = cookies[i].split("=");
    let name = decodeURIComponent(parts.shift());
    let c = parts.join("=");

    if (key && key === name) {
      result = parseCookieValue(c);
      break;
    }

    // Prevent storing a cookie that we couldn't decode.
    if (!key && (c = parseCookieValue(c)) !== undefined) {
      result[name] = c;
    }
  }
  return result;
}

export function removeCookie(key, options) {
  if (cookie(key) === undefined) {
    return false;
  }

  // Must not alter options, thus extending a fresh object...
  cookie(key, "", { ...(options || {}), expires: -1 });
  return !cookie(key);
}

if (window && window.$) {
  const depOpts = {
    since: "2.6.0",
    dropFrom: "2.7.0",
    id: "discourse.jquery-cookie",
  };
  window.$.cookie = function () {
    deprecated(
      "$.cookie is being removed from Discourse. Please import our cookie module and use that instead.",
      depOpts
    );
    return cookie(...arguments);
  };
  window.$.removeCookie = function () {
    deprecated(
      "$.removeCookie is being removed from Discourse. Please import our cookie module and use that instead.",
      depOpts
    );
    return removeCookie(...arguments);
  };
}

export default cookie;
