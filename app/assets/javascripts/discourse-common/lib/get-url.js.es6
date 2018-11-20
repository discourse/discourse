let baseUri;

export default function getURL(url) {
  if (!url) return url;

  if (!baseUri) {
    baseUri = $('meta[name="discourse-base-uri"]').attr("content") || "";
  }

  // if it's a non relative URL, return it.
  if (url !== "/" && !/^\/[^\/]/.test(url)) return url;

  const found = url.indexOf(baseUri);

  if (found >= 0 && found < 3) return url;
  if (url[0] !== "/") url = "/" + url;

  return baseUri + url;
}
