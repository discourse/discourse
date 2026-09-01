import { SIDEBAR_URL } from "discourse/lib/constants";

/**
 * The external drag kinds a dragged-in web link can arrive as, for a target's
 * `accepts` filter. Broader than the URL types alone because some sources
 * expose a link only as HTML or as plain text.
 */
export const WEB_LINK_KINDS = ["urls", "html", "text"];

/**
 * The drop effect a target answers a link drag with. A row being moved is taken
 * from where it was. An incoming link is copied in.
 *
 * Every target that accepts both must agree. A row drags as `move`, so a target
 * answering `copy` makes the pair incompatible. The browser then refuses the
 * drop outright: no `drop` event, nothing logged.
 *
 * @param {Object} source - The source a drop target reported.
 * @returns {"move"|"copy"} The effect for this source.
 */
export function linkDropEffectFor(source) {
  return source.type === "sidebar-link" ? "move" : "copy";
}

/**
 * Lets the sidebar accept a link the browser started dragging from this page —
 * a topic row, a category, a link in a post — none of which register a drag
 * source, and there are far too many kinds to.
 *
 * Matches on the anchor rather than on the payload's declared kinds: a web link
 * has to accept plain text, since some sources publish a URL only that way, and
 * a dragged text selection carries plain text too. Requiring an `http(s)` anchor
 * is what separates them.
 */
export const WEB_LINK_ADOPTION = {
  type: "web-link",
  match: ({ element }) => {
    const anchor = element.closest("a[href]");
    if (!anchor) {
      return false;
    }
    try {
      return ["http:", "https:"].includes(new URL(anchor.href).protocol);
    } catch {
      return false;
    }
  },
};

/**
 * The native payload, wherever the drag came from.
 *
 * An external drop target hands its payload directly; an adopted one carries it
 * on `native`, because the rest of that source describes an element drag. Both
 * read the same from here on.
 *
 * @param {Object} source - The source a drop target reported.
 */
export function webLinkPayload(source) {
  return source.native ?? source;
}

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
    // Named from the absolute URL, since the hostname is the fallback name and
    // stripping it first would leave nothing to fall back to.
    name: suitableName(candidate.name) || defaultName(value),
    value: withoutOwnHost(value),
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

/**
 * Reduces a link to this same site to a path.
 *
 * The server does this on save regardless, so leaving it absolute would only
 * mean showing the user a URL in the form and storing a different one. A path
 * also keeps working when the site is reached by another hostname.
 */
function withoutOwnHost(value) {
  const url = new URL(value);

  if (url.host !== window.location.host) {
    return value;
  }

  return `${url.pathname}${url.search}${url.hash}`;
}

function suitableName(value) {
  const name = value?.replace(/\s+/g, " ").trim();
  return name && name.length <= SIDEBAR_URL.max_name_length ? name : undefined;
}

function defaultName(value) {
  const hostname = new URL(value).hostname.replace(/^www\./, "");
  return hostname || value;
}
