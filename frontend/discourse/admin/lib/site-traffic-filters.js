export const SITE_TRAFFIC_SAFE_FILTERS = ["country", "asn", "browser"];

export const SITE_TRAFFIC_BROWSER_FAMILIES = new Set([
  "edge",
  "opera",
  "firefox",
  "chrome",
  "safari",
  "ie",
  "discoursehub",
  "unknown",
]);

export function validSiteTrafficSafeFilter(key, value) {
  if (key === "country") {
    return typeof value === "string" && /^[A-Z]{2}$/.test(value);
  }

  if (key === "asn") {
    if (typeof value !== "string" || !/^AS[1-9][0-9]{0,9}$/.test(value)) {
      return false;
    }

    return Number(value.slice(2)) <= 2_147_483_647;
  }

  return key === "browser" && SITE_TRAFFIC_BROWSER_FAMILIES.has(value);
}
