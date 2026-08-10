import { SIDEBAR_URL } from "discourse/lib/constants";

/**
 * The external drag kinds a dragged-in web link can arrive as, for a target's
 * `accepts` filter. Broader than the URL types alone because some sources
 * expose a link only as HTML or as plain text.
 */
export const WEB_LINK_KINDS = ["urls", "html", "text"];

/**
 * Turns an incoming external drag into a sidebar link, or nothing when it
 * carries no usable web URL.
 *
 * Reads the payload through the drop target's decorated source rather than a
 * raw `DataTransfer`, so the URL types are already parsed: comment lines are
 * stripped from a uri-list, and Firefox's alternating URL/title format is
 * reduced to its URLs. What is left here is deciding which candidate to take
 * and what to call it.
 *
 * @param {Object} source - The decorated external drag payload.
 * @returns {Object|undefined} A link ready for the section form.
 */
export function extractDroppedWebLink(source) {
  if (!source) {
    return;
  }

  const htmlLink = linkFromHtml(source.getHTML());
  const firefoxNames = firefoxUrlNames(source);
  const candidate = [
    ...source.getURLs().map((value, index) => ({
      value,
      // A uri-list carries no titles, so the dragged anchor's own text names its
      // first entry. Firefox sends titles of its own, which pair off by index.
      name: firefoxNames[index] ?? (index === 0 ? htmlLink?.name : undefined),
    })),
    htmlLink,
    { value: (source.getText() || "").trim() },
  ]
    .filter(Boolean)
    .find(({ value }) => validWebUrl(value));

  if (!candidate) {
    return;
  }

  const value = validWebUrl(candidate.value);

  return {
    icon: "link",
    name: suitableName(candidate.name) || defaultName(value),
    value,
    segment: "primary",
  };
}

/**
 * Titles from Firefox's own URL format, which alternates URL and title lines.
 *
 * Only consulted when the standard type is absent, because that is the same
 * order the URLs were resolved in: reading titles from one format while the
 * URLs came from the other would pair each link with a stranger's name.
 */
function firefoxUrlNames(source) {
  if (source.getStringData("text/uri-list") != null) {
    return [];
  }

  const raw = source.getStringData("text/x-moz-url");
  if (!raw) {
    return [];
  }

  return raw
    .split("\n")
    .filter((_, index) => index % 2 === 1)
    .map((line) => line.trim());
}

function linkFromHtml(value) {
  if (!value) {
    return;
  }

  const link = new DOMParser()
    .parseFromString(value, "text/html")
    .querySelector("a[href]");

  if (!link) {
    return;
  }

  return {
    value: link.getAttribute("href"),
    name: link.textContent.trim(),
  };
}

function validWebUrl(value) {
  if (!value) {
    return;
  }

  try {
    const url = new URL(value);
    return ["http:", "https:"].includes(url.protocol) ? url.href : undefined;
  } catch {
    return;
  }
}

function suitableName(value) {
  const name = value?.replace(/\s+/g, " ").trim();
  return name && name.length <= SIDEBAR_URL.max_name_length ? name : undefined;
}

function defaultName(value) {
  const hostname = new URL(value).hostname.replace(/^www\./, "");
  return hostname || value;
}
