import { SIDEBAR_URL } from "discourse/lib/constants";

const EXPLICIT_LINK_TYPES = ["text/uri-list", "text/x-moz-url"];
// Some sources expose URLs only as text, so drops accept broadly while visuals require URL types.
const LINK_TYPES = [...EXPLICIT_LINK_TYPES, "text/html", "text/plain"];

function dragTypes(dataTransfer) {
  return Array.from(dataTransfer?.types || [], (type) => type.toLowerCase());
}

export function isWebLinkDrag(dataTransfer) {
  const types = dragTypes(dataTransfer);

  return (
    !types.includes("files") &&
    LINK_TYPES.some((linkType) => types.includes(linkType))
  );
}

export function isExplicitWebLinkDrag(dataTransfer) {
  const types = dragTypes(dataTransfer);

  return (
    !types.includes("files") &&
    EXPLICIT_LINK_TYPES.some((linkType) => types.includes(linkType))
  );
}

export function extractDroppedWebLink(dataTransfer) {
  if (!dataTransfer) {
    return;
  }

  const uriList = uris(dataTransfer.getData("text/uri-list") || "");
  const [mozUri, mozName] = lines(dataTransfer.getData("text/x-moz-url") || "");
  const htmlLink = linkFromHtml(dataTransfer.getData("text/html") || "");
  const plainText = (dataTransfer.getData("text/plain") || "").trim();
  const candidate = [
    ...uriList.map((value, index) => ({
      value,
      name: index === 0 ? htmlLink?.name : undefined,
    })),
    { value: mozUri, name: mozName },
    htmlLink,
    { value: plainText },
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

function uris(value) {
  return lines(value).filter((line) => line && !line.startsWith("#"));
}

function lines(value) {
  return value.split(/\r?\n/).map((line) => line.trim());
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
