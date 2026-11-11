let cdn: string | null | undefined,
  baseUrl: string | undefined,
  baseUri: string | null | undefined,
  baseUriMatcher: RegExp | undefined;
let S3BaseUrl: string | null | undefined, S3CDN: string | null | undefined;

let snapshot:
  | {
      cdn?: string | null;
      baseUri?: string | null;
      baseUrl?: string;
      configBaseUrl?: string;
      baseUriMatcher?: RegExp;
      S3BaseUrl?: string | null;
      S3CDN?: string | null;
    }
  | undefined;

/** Options for the setup functions. */
interface SetupOptions {
  /** Whether to record the values so `restoreBaseUri` can bring them back. */
  snapshot?: boolean;
}

/**
 * Prefixes a relative path with the site's base URI. Absolute URLs and paths that
 * already carry the prefix are returned unchanged.
 *
 * @param url - The path or URL. When it is missing, the base URI itself is returned.
 * @returns The prefixed path, or the URL as given.
 */
export default function getURL(url?: string | null): string {
  if (baseUri === undefined) {
    setPrefix(
      document
        .querySelector('meta[name="discourse-base-uri"]')
        ?.getAttribute("content") || ""
    );
  }

  // `setPrefix` has assigned `baseUri` and `baseUriMatcher` by this point. Only tests
  // set a `null` prefix; the app always passes a string.
  if (!url) {
    return baseUri === "/" ? "" : (baseUri as string);
  }

  // if it's a non relative URL, return it.
  if (url !== "/" && !/^\/[^\/]/.test(url)) {
    return url;
  }

  const found = (baseUriMatcher as RegExp).test(url);

  if (found) {
    return url;
  }
  if (url[0] !== "/") {
    url = "/" + url;
  }

  return baseUri + url;
}

/**
 * Like `getURL`, but serves relative paths from the CDN and rewrites S3 URLs to the S3
 * CDN when those are configured.
 *
 * @param url - The path or URL.
 * @returns The resulting URL.
 */
export function getURLWithCDN(url?: string | null): string {
  url = getURL(url);
  // only relative urls
  if (cdn && /^\/[^\/]/.test(url)) {
    url = cdn + url;
  } else if (S3CDN && S3BaseUrl) {
    // Strip http: and https: to ensure robust domain comparison
    const normalizedUrl = url.replace(/^https?:/i, "");
    const normalizedBase = S3BaseUrl.replace(/^https?:/i, "");

    if (normalizedUrl.startsWith(normalizedBase)) {
      url = S3CDN + normalizedUrl.substring(normalizedBase.length);
    }
  }
  return url;
}

/**
 * Builds an absolute URL on the site's base URL.
 *
 * @param path - The path, with or without the base URI prefix.
 * @returns The absolute URL.
 */
export function getAbsoluteURL(path: string): string {
  return baseUrl + withoutPrefix(path);
}

/**
 * Whether a URL is on the site's base URL.
 *
 * @param url - The URL to check.
 * @returns True when the URL starts with the base URL.
 */
export function isAbsoluteURL(url: string): boolean {
  // `setupURL` sets `baseUrl` at boot.
  return url.startsWith(baseUrl as string);
}

/**
 * Removes the base URI prefix from a path.
 *
 * @param path - The path.
 * @returns The path without the prefix.
 */
export function withoutPrefix(path: string): string {
  if (!baseUri) {
    return path;
  } else {
    // `setPrefix` assigns `baseUriMatcher` together with `baseUri`.
    return path.replace(baseUriMatcher as RegExp, "$1");
  }
}

/**
 * Sets the base URI that relative paths are prefixed with.
 *
 * @param configBaseUri - The base URI, such as `"/forum"`, or `""` for none.
 */
export function setPrefix(configBaseUri: string | null | undefined) {
  baseUri = configBaseUri;
  baseUriMatcher = new RegExp(`^${baseUri}(/|$)`);
}

/**
 * Configures the CDN, base URL and base URI.
 *
 * @param configCdn - The CDN URL, if the site uses one.
 * @param configBaseUrl - The site's base URL.
 * @param configBaseUri - The site's base URI.
 * @param opts - The setup options.
 */
export function setupURL(
  configCdn: string | null | undefined,
  configBaseUrl: string,
  configBaseUri: string | null | undefined,
  opts?: SetupOptions | null
) {
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

/**
 * Restores the values recorded by a setup call with `snapshot: true`. Tests change
 * these values and restore them afterwards.
 */
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

/**
 * Configures the S3 base URL and the CDN that serves it.
 *
 * @param configS3BaseUrl - The S3 base URL.
 * @param configS3CDN - The CDN URL for S3 uploads.
 * @param opts - The setup options.
 */
export function setupS3CDN(
  configS3BaseUrl: string | null | undefined,
  configS3CDN: string | null | undefined,
  opts?: SetupOptions | null
) {
  S3BaseUrl = configS3BaseUrl;
  S3CDN = configS3CDN;
  if (opts?.snapshot) {
    snapshot = snapshot || {};
    snapshot.S3BaseUrl = S3BaseUrl;
    snapshot.S3CDN = S3CDN;
  }
}

/**
 * Whether a URL stays inside the site's base URI. It tells navigation on the same host
 * but outside the prefix directory apart, for example from `/forum` to `/about-us`.
 *
 * @param url - A path or a full URL.
 * @returns True when the URL is inside the prefix.
 */
export function samePrefix(url: string): boolean {
  if (baseUri === undefined) {
    setPrefix(
      document
        .querySelector('meta[name="discourse-base-uri"]')
        ?.getAttribute("content") || ""
    );
  }

  const origin = window.location.origin;
  const cmp = url[0] === "/" ? baseUri || "/" : origin + baseUri || origin;
  return url.startsWith(cmp);
}
