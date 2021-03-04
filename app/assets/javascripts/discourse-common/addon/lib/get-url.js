let cdn, baseUrl, baseUri, baseUriMatcher;
let S3BaseUrl, S3CDN;

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

export function setupURL(configCdn, configBaseUrl, configBaseUri) {
  cdn = configCdn;
  baseUrl = configBaseUrl;
  setPrefix(configBaseUri);
}

export function setupS3CDN(configS3BaseUrl, configS3CDN) {
  S3BaseUrl = configS3BaseUrl;
  S3CDN = configS3CDN;
}
