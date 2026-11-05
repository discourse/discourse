import { helperContext } from "discourse/lib/helpers";
import { prioritizeNameFallback } from "discourse/lib/settings";
import { applyValueTransformer } from "discourse/lib/transformer";
import { stripQuotationMarks } from "discourse-markdown-it/features/bbcode-block";

const WHITESPACE = /\s/;
const WORD_CHARACTER = /[\p{L}\p{N}_]/u;
const MIN_PARTIAL_MATCH_LENGTH = 20;
const MEDIA_START = "\uE000";
const MEDIA_END = "\uE001";
const SKIPPED = "img.emoji, .lightbox-wrapper .meta, aside.quote > .title";
const HIGHLIGHT_CLASS = "quote-highlight";
const UPLOAD_SHA1 = /[0-9a-f]{40}/;
const URL_ORIGIN = /^([a-z]+:)?\/\/[^/]+/i;

export const QUOTE_HIGHLIGHT_ID = "quote-highlight-start";

export const QUOTE_REGEXP =
  /\[quote=([^\]]*)\]((?:[\s\S](?!\[quote=[^\]]*\]))*?)\[\/quote\]/im;

// Build the BBCode quote around the selected text
export function buildQuote(post, contents, opts = {}) {
  if (!post || !contents) {
    return "";
  }

  let fullName = post.name;
  // if the quote username data attr is present but it does not
  // match the post username then fallback to the quote username instead of fetching
  // the full name from the post
  if (opts.username && opts.username !== post.username) {
    fullName = null;
  }

  const name = prioritizeNameFallback(fullName, opts.username || post.username);

  const params = [
    stripQuotationMarks(name),
    `post:${opts.post || post.post_number}`,
    `topic:${opts.topic || post.topic_id}`,
  ];

  if (opts.full) {
    params.push("full:true");
  }
  if (
    helperContext().siteSettings.display_name_on_posts &&
    !helperContext().siteSettings.prioritize_username_in_ux &&
    fullName
  ) {
    params.push(`username:${opts.username || post.username}`);
  }

  const transformedParams = applyValueTransformer("quote-params", params, {
    post,
    contents,
    opts,
  });

  const paramsString = transformedParams.join(", ");
  return `[quote="${paramsString}"]\n${contents.trim()}\n[/quote]\n\n`;
}

function indexOfWord(haystack, needle, isWordAt) {
  const first = haystack.indexOf(needle);

  for (
    let index = first;
    index !== -1;
    index = haystack.indexOf(needle, index + 1)
  ) {
    if (isWordAt(index, index + needle.length)) {
      return index;
    }
  }

  return first;
}

function findLongestPrefix(haystack, needle, isBoundary) {
  const start = indexOfWord(
    haystack,
    needle,
    (from, to) => isBoundary(from) && isBoundary(to)
  );
  if (start !== -1) {
    return [start, needle.length];
  }

  let best = [-1, 0];
  let low = MIN_PARTIAL_MATCH_LENGTH;
  let high = needle.length - 1;

  while (low <= high) {
    const length = Math.floor((low + high) / 2);
    const index = indexOfWord(haystack, needle.slice(0, length), isBoundary);

    if (index === -1) {
      high = length - 1;
      continue;
    }

    best = [index, length];
    low = length + 1;
  }

  return best;
}

function mediaSource(element) {
  if (element.matches("img")) {
    const src = element.getAttribute("src") ?? "";
    return (
      src.match(UPLOAD_SHA1)?.[0] ??
      element.dataset.base62Sha1 ??
      src.replace(URL_ORIGIN, "")
    );
  }

  if (element.matches("aside.onebox")) {
    return element.dataset.oneboxSrc;
  }

  if (
    element.matches("a.inline-onebox, a.inline-onebox-loading") ||
    (element.matches("a") &&
      element.textContent === element.getAttribute("href"))
  ) {
    return element.getAttribute("href");
  }

  if (element.matches("[data-video-src]")) {
    return element.dataset.videoSrc;
  }
}

function collectText(node, visit) {
  for (const child of node.childNodes) {
    if (child.nodeType === Node.TEXT_NODE) {
      visit(child, child.data);
      continue;
    }

    if (child.nodeType !== Node.ELEMENT_NODE || child.matches(SKIPPED)) {
      continue;
    }

    const source = mediaSource(child);
    if (source) {
      visit(child, `${MEDIA_START}${source}${MEDIA_END}`);
      continue;
    }

    collectText(child, visit);
  }
}

export function quotableText(node) {
  let text = "";
  collectText(node, (_, data) => (text += data));
  return text.trim();
}

function indexText(node) {
  const index = { haystack: "", targets: [], offsets: [], spacedBefore: [] };
  let spaced = true;

  collectText(node, (target, data) => {
    for (let offset = 0; offset < data.length; offset++) {
      if (WHITESPACE.test(data[offset])) {
        spaced = true;
        continue;
      }

      index.haystack += data[offset];
      index.targets.push(target);
      index.offsets.push(offset);
      index.spacedBefore.push(spaced);
      spaced = false;
    }
  });

  return index;
}

function wrapMatch(target, from, to) {
  if (target.nodeType === Node.ELEMENT_NODE) {
    const visible =
      getComputedStyle(target).display === "none"
        ? target.parentElement
        : target;
    visible.classList.add(HIGHLIGHT_CLASS);
    return visible;
  }

  const parent = target.parentElement;
  if (
    parent.classList.contains(HIGHLIGHT_CLASS) &&
    from === 0 &&
    to === target.length
  ) {
    return parent;
  }

  const match = target.splitText(from);
  match.splitText(to - from);

  const span = document.createElement("span");
  span.className = HIGHLIGHT_CLASS;
  match.replaceWith(span);
  span.append(match);
  return span;
}

export function highlightQuote(node, text) {
  const needle = text?.replaceAll(/\s+/g, "");
  if (!needle) {
    return [];
  }

  const { haystack, targets, offsets, spacedBefore } = indexText(node);

  const isBoundary = (index) =>
    index === haystack.length ||
    spacedBefore[index] ||
    !WORD_CHARACTER.test(haystack[index - 1]) ||
    !WORD_CHARACTER.test(haystack[index]);

  const [start, length] = findLongestPrefix(haystack, needle, isBoundary);
  if (start === -1) {
    return [];
  }

  const matches = new Map();
  for (let i = start; i < start + length; i++) {
    const from = matches.get(targets[i])?.[0] ?? offsets[i];
    matches.set(targets[i], [from, offsets[i] + 1]);
  }

  return [...matches]
    .filter(([target]) => !target.parentElement.closest("svg"))
    .map(([target, [from, to]]) => wrapMatch(target, from, to));
}
