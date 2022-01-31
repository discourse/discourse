let cdn, baseUrl, baseUri, baseUriMatcher;
let S3BaseUrl, S3CDN;

let snapshot;

export default function getURL(url) {
  if (baseUri === undefined) {
    setPrefix($('meta[name="discourse-base-uri"]').attr("content") || "");
  }

  if (!url) {
    return baseUri === "/" ? "" : baseUri;
  }

  // if it's a non relative URL, return it.
  if (url !== "/" && !/^\/[^\/]/.test(url)) {
    return url;
  }

  const found = baseUriMatcher.test(url);

  if (found) {
    return url;
  }
  if (url[0] !== "/") {
    url = "/" + url;
  }

  return baseUri + url;
}

export function getURLWithCDN(url) {
  url = getURL(url);
  // only relative urls
  if (cdn && /^\/[^\/]/.test(url)) {
    url = cdn + url;
  } else if (S3CDN) {
    url = url.replace(S3BaseUrl, S3CDN);
  }
  return url;
}

export function getAbsoluteURL(path) {
  return baseUrl + path;
}

export function isAbsoluteURL(url) {
  return url.startsWith(baseUrl);
}

export function withoutPrefix(path) {
  if (!baseUri) {
    return path;
  } else {
    return path.replace(baseUriMatcher, "$1");
  }
}

export function setPrefix(configBaseUri) {
  baseUri = configBaseUri;
  baseUriMatcher = new RegExp(`^${baseUri}(/|$)`);
}

export function setupURL(configCdn, configBaseUrl, configBaseUri, opts) {
  opts = opts || {};
  cdn = configCdn;
  baseUrl = configBaseUrl;
  setPrefix(configBaseUri);

  if (opts?.snapshot) {
    snapshot = {
      cdn,
      baseUri,
      baseUrl,
      configBaseUrl,
      baseUriMatcher,
    };
  }
}

// In a test environment we might change these values and, after tests, want to restore them.
export function restoreBaseUri() {
  if (snapshot) {
    cdn = snapshot.cdn;
    baseUri = snapshot.baseUri;
    baseUrl = snapshot.baseUrl;
    baseUriMatcher = snapshot.baseUriMatcher;
    S3BaseUrl = snapshot.S3BaseUrl;
    S3CDN = snapshot.S3CDN;
  }
}

export function setupS3CDN(configS3BaseUrl, configS3CDN, opts) {
  S3BaseUrl = configS3BaseUrl;
  S3CDN = configS3CDN;
  if (opts?.snapshot) {
    snapshot = snapshot || {};
    snapshot.S3BaseUrl = S3BaseUrl;
    snapshot.S3CDN = S3CDN;
  }
}

// We can use this to identify when navigating on the same host but outside of the
// prefix directory. For example from `/forum` to `/about-us` which is not discourse
export function samePrefix(url) {
  if (baseUri === undefined) {
    setPrefix($('meta[name="discourse-base-uri"]').attr("content") || "");
  }
  let origin = window.location.origin;
  let cmp = url[0] === "/" ? baseUri || "/" : origin + baseUri || origin;
  return url.indexOf(cmp) === 0;
}
