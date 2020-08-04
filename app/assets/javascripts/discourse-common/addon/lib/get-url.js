let cdn, baseUrl, baseUri;
let S3BaseUrl, S3CDN;

export default function getURL(url) {
  if (!url) return url;

  if (baseUri === undefined) {
    baseUri = $('meta[name="discourse-base-uri"]').attr("content") || "";
  }

  // if it's a non relative URL, return it.
  if (url !== "/" && !/^\/[^\/]/.test(url)) return url;

  const found = url.indexOf(baseUri);

  if (found >= 0 && found < 3) return url;
  if (url[0] !== "/") url = "/" + url;

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
  const rootURL = (!baseUri ? "/" : baseUri).replace(/\/$/, "");
  return path.replace(rootURL, "");
}

export function setPrefix(configBaseUri) {
  baseUri = configBaseUri;
}

export function setupURL(configCdn, configBaseUrl, configBaseUri) {
  cdn = configCdn;
  baseUrl = configBaseUrl;
  baseUri = configBaseUri;
}

export function setupS3CDN(configS3BaseUrl, configS3CDN) {
  S3BaseUrl = configS3BaseUrl;
  S3CDN = configS3CDN;
}
