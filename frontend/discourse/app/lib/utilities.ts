/* eslint-disable prefer-const -- Preserve the original JavaScript emit for this types-only port. */
import { cancel } from "@ember/runloop";
import type { MomentInput } from "moment";
import { caretCoordinates } from "discourse/lib/caret-position";
import deprecated from "discourse/lib/deprecated";
import escape from "discourse/lib/escape";
import getURL from "discourse/lib/get-url";
import discourseLater from "discourse/lib/later";
import { processSelectionFragment } from "discourse/lib/selection/preserve-list-structure";
import { parseAsync } from "discourse/lib/text";
import toMarkdown from "discourse/lib/to-markdown";
import Site from "discourse/models/site";
import { capabilities } from "discourse/services/capabilities";
import { i18n } from "discourse-i18n";

/** A start and an end offset in a text. */
export interface TextSpan {
  start: number;
  end: number;
}

/** A paste event, or a jQuery or delegated event that wraps one. */
export interface ClipboardEventLike {
  clipboardData?: DataTransfer | null;
  originalEvent?: { clipboardData?: DataTransfer | null };
  delegatedEvent?: { originalEvent: { clipboardData?: DataTransfer | null } };
}

/** Options for `clipboardHelpers`. */
export interface ClipboardHelperOptions {
  /** Whether the user can upload files here. */
  canUpload?: boolean;

  /** The site settings, for `enable_rich_text_paste`. */
  siteSettings: { enable_rich_text_paste: boolean };
}

/** The site settings `siteDefaultHomepage` reads. */
export interface HomepageSettings {
  default_homepage?: string | null;
  top_menu: string;
}

/** A chart data point. Its `x` is a `YYYY-MM-DD` date. */
export interface DatedValue {
  x: unknown;
  y: unknown;
}

/** An element whose caret `setCaretPosition` can move. */
interface CaretControl {
  focus(): void;
  setSelectionRange?(start: number, end: number): void;
  createTextRange?(): {
    collapse(toStart: boolean): void;
    moveEnd(unit: string, count: number): void;
    moveStart(unit: string, count: number): void;
    select(): void;
  };
}

/** The part of a markdown token that `findToken` reads. */
interface MarkdownToken {
  type: string;
  content?: string | null;
  children?: MarkdownToken[] | null;
}

declare global {
  interface Window {
    /** The bridge the mobile app's webview adds. */
    ReactNativeWebView?: { postMessage(message: string): void };
  }
}

let _defaultHomepage: string | undefined;

/**
 * Splits a string, dropping empty parts.
 *
 * @param str - The string. Anything else gives an empty list.
 * @param separator - The separator. Defaults to `","`.
 * @returns The parts.
 */
export function splitString(str: unknown, separator: string = ","): string[] {
  if (typeof str === "string") {
    return str.split(separator).filter(Boolean);
  } else {
    return [];
  }
}

/**
 * Removes a leading "Discourse" word from a name.
 *
 * @param text - The name.
 * @returns The name without the prefix.
 */
export function stripDiscoursePrefix(text: string | null | undefined): string {
  return (text || "").replace(/^discourse[\s-]+/i, "");
}

/**
 * Escapes text for use in HTML.
 *
 * @param string - The text. A falsy value gives `""`.
 * @returns The escaped text.
 */
export function escapeExpression(string: unknown): string {
  if (!string) {
    return "";
  }

  return escape(string);
}

let _usernameFormatDelegate = (username: string): string => username;

/**
 * Formats a username for display, with the formatter `replaceFormatter` set.
 *
 * @param username - The username.
 * @returns The formatted username.
 */
export function formatUsername(username: string | null | undefined): string {
  return _usernameFormatDelegate(username || "");
}

/**
 * Replaces the function `formatUsername` formats usernames with.
 *
 * @param fn - The formatter.
 */
export function replaceFormatter(fn: (username: string) => string) {
  _usernameFormatDelegate = fn;
}

/**
 * Builds the URL of a topic, or of a post in it after the first.
 *
 * @param slug - The topic slug.
 * @param topicId - The topic id.
 * @param postNumber - The post number.
 * @returns The URL.
 */
export function postUrl(
  slug: string | null | undefined,
  topicId: number | string,
  postNumber?: number | null
): string {
  let url = getURL("/t/");
  if (slug) {
    url += slug + "/";
  } else {
    url += "topic/";
  }
  url += topicId;
  // A missing post number compares as not greater than one.
  if ((postNumber as number) > 1) {
    url += "/" + postNumber;
  }
  return url;
}

/**
 * Moves screen-reader focus to a post's body, for posts after the first.
 *
 * @param postNumber - The post number.
 */
export function highlightPost(postNumber: number) {
  const container = document.querySelector(`#post_${postNumber}`);
  if (!container) {
    return;
  }

  const element = container.querySelector<HTMLElement>(
    ".topic-body, .small-action-desc"
  );
  if (!element) {
    return;
  }

  if (postNumber > 1) {
    // Transport screenreader to correct post by focusing it
    element.setAttribute("tabindex", "0");
    element.focus();
  }
}

/**
 * Whether a value looks like an email address.
 *
 * @param email - The value. Anything but a string is invalid.
 * @returns True for a valid address.
 */
export function emailValid(email: unknown): boolean {
  // see:  http://stackoverflow.com/questions/46155/validate-email-address-in-javascript
  const re =
    /^[a-zA-Z0-9!#$%&'*+\/=?\^_`{|}~\-]+(?:\.[a-zA-Z0-9!#$%&'\*+\/=?\^_`{|}~\-]+)*@(?:[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?\.)+[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?$/;
  // `test` converts any value to a string first.
  return re.test(email as string);
}

/**
 * Whether a string is a valid hostname.
 *
 * @param hostname - The string.
 * @returns True for a valid hostname. A falsy hostname is returned as is.
 */
export function hostnameValid(hostname: string | null | undefined) {
  // see:  https://stackoverflow.com/questions/106179/regular-expression-to-match-dns-hostname-or-ip-address
  const re =
    /^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)+([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$/;
  return hostname && re.test(hostname);
}

/**
 * Extracts the host, without a port, from a URL.
 *
 * @param url - The URL, with or without a scheme.
 * @returns The host.
 */
export function extractDomainFromUrl(url: string): string {
  if (url.includes("://")) {
    url = url.split("/")[2];
  } else {
    url = url.split("/")[0];
  }
  return url.split(":")[0];
}

// Whether everything before `node` in its parent is insignificant whitespace,
// i.e. `node` is effectively the first thing in its parent. (Cooked HTML has
// whitespace text nodes between blocks, so a strict firstChild check fails.)
function isFirstMeaningfulChild(node: Node): boolean {
  for (let sibling = node.previousSibling; sibling; ) {
    // A text node always has text content.
    if (sibling.nodeType !== Node.TEXT_NODE || sibling.textContent!.trim()) {
      return false;
    }
    sibling = sibling.previousSibling;
  }
  return true;
}

// A triple-click (and similar) leaves the selection's end at the very start of
// the following block (endOffset 0). cloneContents() would then materialize
// that block as an empty husk (e.g. <blockquote><p></p></blockquote>) that
// serializes to stray markdown like a lone "> ". Pull the end back past the
// husk — to the topmost ancestor it starts — so it is never cloned.
// Returns the original range when there's nothing to trim.
function rangeWithoutTrailingHusk(range: Range): Range {
  if (range.endOffset !== 0) {
    return range;
  }

  const common = range.commonAncestorContainer;
  let boundary: Node = range.endContainer;
  while (
    boundary !== common &&
    boundary.parentNode !== common &&
    isFirstMeaningfulChild(boundary)
  ) {
    // The walk stays below `common`, so a parent exists.
    boundary = boundary.parentNode!;
  }

  if (boundary === common || !boundary.parentNode) {
    return range;
  }

  const trimmed = range.cloneRange();
  trimmed.setEndBefore(boundary);
  return trimmed;
}

/**
 * Serializes the selection as HTML, quoting code blocks and whole oneboxes.
 *
 * @returns The HTML, or `""` without a selection.
 */
export function selectedHTML(): string {
  // `getSelection` only returns null outside a browsing context.
  const selection = window.getSelection()!;
  if (selection.isCollapsed) {
    return "";
  }

  const div = document.createElement("div");
  for (let r = 0; r < selection.rangeCount; r++) {
    const range = selection.getRangeAt(r);
    // A selection in the page always has an element around it.
    const ancestor = (
      range.commonAncestorContainer.nodeType === Node.ELEMENT_NODE
        ? range.commonAncestorContainer
        : range.commonAncestorContainer.parentElement
    ) as Element;

    const oneboxTest = ancestor.closest<HTMLElement>(
      "aside.onebox[data-onebox-src]"
    );
    const codeBlockTest = ancestor.closest("pre");
    if (codeBlockTest) {
      const code = document.createElement("code");
      code.append(range.cloneContents());

      // Even though this was a code block, produce a non-block quote if it's a single line.
      if (/\n/.test(code.innerText)) {
        const pre = document.createElement("pre");
        pre.append(code);
        div.append(pre);
      } else {
        div.append(code);
      }
    } else if (oneboxTest) {
      // This is a partial quote from a onebox.
      // Treat it as though the entire onebox was quoted.
      // The selector requires `data-onebox-src`.
      div.append(oneboxTest.dataset.oneboxSrc!);
    } else {
      const effectiveRange = rangeWithoutTrailingHusk(range);
      const fragmentContainer = document.createElement("div");
      fragmentContainer.append(effectiveRange.cloneContents());
      processSelectionFragment(fragmentContainer, effectiveRange);
      div.append(...fragmentContainer.childNodes);
    }
  }

  div
    .querySelectorAll<HTMLElement>("aside.onebox[data-onebox-src]")
    .forEach((element) => {
      element.replaceWith(element.dataset.oneboxSrc!);
    });

  return div.outerHTML;
}

/**
 * Converts the selection to markdown.
 *
 * @returns The markdown, or `""` without a selection.
 */
export async function selectedText(): Promise<string> {
  const html = selectedHTML();
  if (!html) {
    return "";
  }

  return await toMarkdown(html);
}

/**
 * The node that contains the whole of the first selection range.
 *
 * @returns The node, or `undefined` without a selection.
 */
export function selectedNode(): Node | undefined {
  return selectedRange()?.commonAncestorContainer;
}

/**
 * The first selection range.
 *
 * @returns The range, or `undefined` without a selection.
 */
export function selectedRange(): Range | undefined {
  // `getSelection` only returns null outside a browsing context.
  const selection = window.getSelection()!;
  if (selection.rangeCount > 0) {
    return selection.getRangeAt(0);
  }
}

/**
 * Determines the row and column of the caret in a text field.
 *
 * @param el - The text field.
 * @returns The 1-based row and the 0-based column.
 */
export function caretRowCol(el: HTMLTextAreaElement | HTMLInputElement) {
  let cp = caretPosition(el);
  let rows = el.value.slice(0, cp).split("\n");
  let rowNum = rows.length;

  let colNum =
    cp -
    rows.splice(0, rowNum - 1).reduce(function (sum: number, row: string) {
      return sum + row.length + 1;
    }, 0);

  return { rowNum, colNum };
}

/**
 * Determines the position of the caret in a text field.
 *
 * @param el - The text field.
 * @returns The caret offset, or 0 without a field.
 */
export function caretPosition(
  el: { selectionStart?: number | null } | null | undefined
): number {
  return el?.selectionStart || 0;
}

/**
 * Moves the caret of a text field.
 *
 * @param ctrl - The field, or a selector for it.
 * @param pos - The caret offset.
 * @returns Nothing, or the result of the legacy text range's `select`.
 */
export function setCaretPosition(ctrl: string | CaretControl, pos: number) {
  if (typeof ctrl === "string") {
    // A missing element throws below.
    ctrl = document.querySelector<HTMLInputElement>(ctrl) as CaretControl;
  }

  let range;
  if (ctrl.setSelectionRange) {
    ctrl.focus();
    ctrl.setSelectionRange(pos, pos);
    return;
  }
  if (ctrl.createTextRange) {
    range = ctrl.createTextRange();
    range.collapse(true);
    range.moveEnd("character", pos);
    range.moveStart("character", pos);
    return range.select();
  }
}

/**
 * The homepage the site settings configure.
 *
 * @param siteSettings - The site settings.
 * @returns The `default_homepage` when it is still a choice, or else the first
 *   item of the top menu.
 */
export function siteDefaultHomepage(siteSettings: HomepageSettings): string {
  const configured = siteSettings.default_homepage;

  const choices = Site.current()?.homepage_choices;
  if (configured && (!choices || choices.includes(configured))) {
    return configured;
  }

  return siteSettings.top_menu.split("|")[0].split(",")[0];
}

/**
 * Sets the default homepage from the page's meta tag, or else the site settings.
 *
 * @param siteSettings - The site settings.
 */
export function initializeDefaultHomepage(siteSettings: HomepageSettings) {
  const sel = document.querySelector("meta[name='discourse_current_homepage']");
  const homepage =
    sel?.getAttribute("content") || siteDefaultHomepage(siteSettings);
  setDefaultHomepage(homepage);
}

/**
 * The default homepage.
 *
 * @returns The homepage, such as `"latest"`, or `undefined` before it is set.
 */
export function defaultHomepage(): string | undefined {
  return _defaultHomepage;
}

/**
 * Sets the default homepage.
 *
 * @param homepage - The homepage, such as `"latest"`.
 */
export function setDefaultHomepage(homepage: string) {
  _defaultHomepage = homepage;
}

/**
 * Works out where a selection ends up after text in it is replaced.
 *
 * @param options - The spans.
 * @returns The new selection.
 */
export function determinePostReplaceSelection({
  selection,
  needle,
  replacement,
}: {
  /** The selection before the replacement. */
  selection: TextSpan;

  /** The replaced text. */
  needle: TextSpan;

  /** The replacing text. */
  replacement: TextSpan;
}): TextSpan {
  const diff =
    replacement.end - replacement.start - (needle.end - needle.start);

  if (selection.end <= needle.start) {
    // Selection ends (and starts) before needle.
    return { start: selection.start, end: selection.end };
  } else if (selection.start <= needle.start) {
    // Selection starts before needle...
    if (selection.end < needle.end) {
      // ... and ends inside needle.
      return { start: selection.start, end: needle.start };
    } else {
      // ... and spans needle completely.
      return { start: selection.start, end: selection.end + diff };
    }
  } else if (selection.start < needle.end) {
    // Selection starts inside needle...
    if (selection.end <= needle.end) {
      // ... and ends inside needle.
      return { start: replacement.end, end: replacement.end };
    } else {
      // ... and spans end of needle.
      return { start: replacement.end, end: selection.end + diff };
    }
  } else {
    // Selection starts (and ends) behind needle.
    return { start: selection.start + diff, end: selection.end + diff };
  }
}

const toArray = <T>(
  items: ArrayLike<T> | Iterable<T> | null | undefined
): T[] => {
  items = items || [];

  if (!Array.isArray(items)) {
    return Array.from(items as ArrayLike<T>);
  }

  return items as T[];
};

const gifInDisguise = (clipboard: DataTransfer) => {
  return (
    clipboard.files.length === 1 &&
    clipboard.files[0].type === "image/png" &&
    clipboard.types.every((e) => ["text/html", "Files"].includes(e)) &&
    /<img.*src=.*\.gif/.test(clipboard.getData("text/html"))
  );
};

/**
 * Reads what a paste event carries and what can be done with it.
 *
 * @param e - The paste event.
 * @param opts - The options.
 * @returns The clipboard data, its types, and whether files can be uploaded and
 *   HTML pasted.
 */
export function clipboardHelpers(
  e: ClipboardEventLike,
  opts: ClipboardHelperOptions
) {
  // One of the wrapped events carries the clipboard data.
  const clipboard = (e.clipboardData ||
    e.originalEvent!.clipboardData ||
    e.delegatedEvent!.originalEvent.clipboardData) as DataTransfer;

  const types = toArray(clipboard.types);
  let files: (File | DataTransferItem)[] = toArray(clipboard.files);

  if (types.includes("Files") && files.length === 0) {
    // for IE
    files = toArray(clipboard.items).filter((i) => i.kind === "file");
  }

  let canUpload = files && opts.canUpload && types.includes("Files");
  const canUploadImage =
    canUpload &&
    files.filter((f) => f.type.match("^image/"))[0] &&
    !gifInDisguise(clipboard);
  const canPasteHtml =
    opts.siteSettings.enable_rich_text_paste &&
    types.includes("text/html") &&
    !canUploadImage;

  return { clipboard, types, canUpload, canPasteHtml };
}

/**
 * Removes accents from letters.
 *
 * @param string - The text.
 * @returns The text without accents.
 */
export function removeAccents(string: string): string {
  return string.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
}

/**
 * Replaces any accented characters with their ASCII equivalent.
 *
 * @param string - The text.
 * @param fallback - The value to return when the text is not ASCII printable.
 * @returns The text if it only contains ASCII printable characters, or else
 *   the fallback.
 */
export function toAsciiPrintable(string: string): string | undefined;
export function toAsciiPrintable<T>(string: string, fallback: T): string | T;
export function toAsciiPrintable<T>(
  string: string,
  fallback?: T
): string | T | undefined {
  if (typeof string.normalize === "function") {
    string = removeAccents(string);
  }

  // TypeScript rejects octal escapes, so the printable range is in hex.
  return /^[\x20-\x7e]*$/.test(string) ? string : fallback;
}

/**
 * Converts text to an ASCII slug.
 *
 * @param string - The text.
 * @returns The slug.
 */
export function slugify(string: string): string {
  return string
    .trim()
    .toLowerCase()
    .replace(/\s|_+/g, "-") // Replace spaces and underscores with dashes
    .replace(/[^\w\-]+/g, "") // Remove non-word characters except for dashes
    .replace(/\-\-+/g, "-") // Replace multiple dashes with a single dash
    .replace(/^-+/, "") // Remove leading dashes
    .replace(/-+$/, ""); // Remove trailing dashes
}

/**
 * Converts text to a slug that keeps letters from any script.
 *
 * @param string - The text.
 * @returns The slug.
 */
export function unicodeSlugify(string: string): string {
  try {
    return string
      .trim()
      .toLowerCase()
      .normalize("NFD") // normalize the string to remove diacritics
      .replace(/\s|_+/g, "-") // replace spaces and underscores with dashes
      .replace(/[^\p{Letter}\d\-]+/gu, "") // Remove non-letter characters except for dashes
      .replace(/--+/g, "-") // replace multiple dashes with a single dash
      .replace(/^-+/, "") // Remove leading dashes
      .replace(/-+$/, ""); // Remove trailing dashes
  } catch {
    // in case the regex construct \p{Letter} is not supported by the browser
    // fall back to the basic slugify function
    return slugify(string);
  }
}

/**
 * Converts a value to a number, parsing anything that isn't one.
 *
 * @param input - The value.
 * @returns The number, or `NaN`.
 */
export function toNumber(input: unknown): number {
  // `parseFloat` converts any value to a string first.
  return typeof input === "number" ? input : parseFloat(input as string);
}

/**
 * Whether a value is a finite number or parses as one.
 *
 * @param input - The value.
 * @returns True for a numeric value.
 */
export function isNumeric(input: unknown): boolean {
  // `isFinite` converts any value to a number first.
  return !isNaN(toNumber(input)) && isFinite(input as number);
}

/**
 * Adds a zero point for each day between two dates that has none.
 *
 * @param data - The points, sorted by date. They are changed in place.
 * @param startDate - The first day, as `YYYY-MM-DD`.
 * @param endDate - The last day, as `YYYY-MM-DD`.
 * @returns The points.
 */
export function fillMissingDates(
  data: DatedValue[],
  startDate: string,
  endDate: string
): DatedValue[] {
  const startMoment = moment(startDate, "YYYY-MM-DD");
  const endMoment = moment(endDate, "YYYY-MM-DD");
  const countDays = endMoment.diff(startMoment, "days");
  let currentMoment: MomentInput = startMoment;

  for (let i = 0; i <= countDays; i++) {
    let date = data[i] ? moment(data[i].x as MomentInput, "YYYY-MM-DD") : null;
    if (i === 0 && (!date || date.isAfter(startMoment))) {
      data.splice(i, 0, { x: startMoment.format("YYYY-MM-DD"), y: 0 });
    } else {
      if (!date || date.isAfter(moment(currentMoment))) {
        data.splice(i, 0, { x: currentMoment, y: 0 });
      }
    }
    currentMoment = moment(currentMoment).add(1, "day").format("YYYY-MM-DD");
  }
  return data;
}

/**
 * Whether the browser accepts cookies.
 *
 * @returns True when a test cookie can be set.
 */
export function areCookiesEnabled(): boolean {
  // see: https://github.com/Modernizr/Modernizr/blob/400db4043c22af98d46e1d2b9cbc5cb062791192/feature-detects/cookies.js
  try {
    document.cookie = "cookietest=1";
    let ret = document.cookie.includes("cookietest=");
    document.cookie = "cookietest=1; expires=Thu, 01-Jan-1970 00:00:01 GMT";
    return ret;
  } catch {
    return false;
  }
}

/**
 * Whether the user asked the system to reduce motion.
 *
 * @returns True when they did.
 */
export function prefersReducedMotion(): boolean {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

/**
 * Posts a message to the mobile app, when the page runs in its webview.
 *
 * @param prop - The message key.
 * @param value - The message value.
 */
export function postRNWebviewMessage(prop: string, value: unknown) {
  if (window.ReactNativeWebView !== undefined) {
    window.ReactNativeWebView.postMessage(JSON.stringify({ [prop]: value }));
  }
}

function pickMarker(text: string): string | null {
  // Uses the private use area (U+E000 to U+F8FF) to find a character that
  // is not present in the text. This character will be used as a marker in
  // place of the caret.
  for (let code = 0xe000; code <= 0xf8ff; ++code) {
    const char = String.fromCharCode(code);
    if (!text.includes(char)) {
      return char;
    }
  }
  return null;
}

function findToken(
  tokens: MarkdownToken[],
  marker: string,
  level = 0
): MarkdownToken | null | undefined {
  if (level > 50) {
    return null;
  }
  const token = tokens.find((t) => (t.content ?? "").includes(marker));
  return token?.children ? findToken(token.children, marker, level + 1) : token;
}

const CODE_MARKERS_REGEX = /    |```|~~~|[^`]`[^`]|\[code\]/;
const CODE_TOKEN_TYPES = ["code_inline", "code_block", "fence"];

/**
 * Whether a position in markdown falls inside code.
 *
 * @param text - The markdown.
 * @param pos - The position.
 * @returns True inside inline code, a code block or a fence.
 */
export async function inCodeBlock(text: string, pos: number): Promise<boolean> {
  if (!CODE_MARKERS_REGEX.test(text)) {
    return false;
  }

  const marker = pickMarker(text);
  if (!marker) {
    return false;
  }

  const markedText = text.slice(0, pos) + marker + text.slice(pos);
  const tokens = await parseAsync(markedText);
  const type = findToken(tokens, marker)?.type;

  return CODE_TOKEN_TYPES.includes(type as string);
}

/**
 * Replaces modifier names in a shortcut string with their platform spelling.
 *
 * @deprecated To draw a shortcut use `DShortcut` (`discourse/ui-kit/d-shortcut`),
 * which carries the accessible markup too. For the string alone use
 * `formatShortcut` from `discourse/lib/shortcut-format`.
 */
export function translateModKey(string: string, separator = " "): string {
  deprecated(
    "`translateModKey()` is deprecated. To draw a shortcut use `DShortcut` (`discourse/ui-kit/d-shortcut`), which carries the accessible markup too; for the string alone use `formatShortcut()` from `discourse/lib/shortcut-format`.",
    {
      since: "2026.9.0",
      id: "discourse.translate-mod-key",
    }
  );

  const { isApple } = capabilities;
  // Apple device users are used to glyphs for shortcut keys
  if (isApple) {
    string = string
      .replace(/shift/i, "\u21E7")
      .replace(/meta/i, "\u2318")
      .replace(/alt/i, "\u2325")
      .replace(/ctrl/i, "\u2303")
      .replace(/\+/g, separator);
  } else {
    string = string
      .replace(/shift/i, "\u21E7")
      .replace(/ctrl/i, i18n("shortcut_modifier_key.ctrl"))
      .replace(/meta/i, i18n("shortcut_modifier_key.ctrl"))
      .replace(/alt/i, i18n("shortcut_modifier_key.alt"))
      .replace(/\+/g, separator);
  }

  return string;
}

/**
 * Copies text to the clipboard.
 *
 * Use this version if you already have the text to be copied in memory, and
 * you do not need to make an AJAX call to the API to generate any text. See
 * `clipboardCopyAsync` for the latter.
 *
 * @param text - The text.
 * @returns A promise that rejects when the copy fails.
 */
export function clipboardCopy(text: string): Promise<void> {
  // Use the Async Clipboard API when available.
  // Requires a secure browsing context (i.e. HTTPS)
  if (window.navigator.clipboard) {
    return window.navigator.clipboard.writeText(text).catch(function (err) {
      throw err !== undefined
        ? err
        : new DOMException("The request is not allowed", "NotAllowedError");
    });
  }

  // ...Otherwise, use document.execCommand() fallback
  if (clipboardCopyFallback(text)) {
    return Promise.resolve();
  } else {
    return Promise.reject();
  }
}

/**
 * Copies text that is still being fetched to the clipboard.
 *
 * Use this version if you must use an AJAX call to retrieve or generate
 * server-side text to copy to the clipboard. Otherwise this write function will
 * error in certain browsers, because the time taken from the user event to the
 * clipboard text being copied will be too long.
 *
 * @param functionReturningPromise - Returns a promise of a `text/plain` blob.
 * @returns A promise that rejects when the copy fails. Without the Async
 *   Clipboard API, it resolves before the copy and never reports a failure.
 */
export function clipboardCopyAsync(
  functionReturningPromise: () => Promise<Blob>
): Promise<void> {
  // Use the Async Clipboard API when available.
  // Requires a secure browsing context (i.e. HTTPS)
  if (window.navigator.clipboard) {
    // Firefox does not support window.ClipboardItem yet (it is behind
    // a flag (dom.events.asyncClipboard.clipboardItem) as at version 87.)
    // so we need to fall back to the normal non-async clipboard copy, that
    // works in every browser except Safari.
    //
    // TODO: (martin) Look at this on 2022-07-01 to see if support has
    // changed.
    if (!window.ClipboardItem) {
      return functionReturningPromise().then((textBlob) => {
        return textBlob.text().then((text) => {
          return clipboardCopy(text);
        });
      });
    }

    return window.navigator.clipboard
      .write([
        new window.ClipboardItem({ "text/plain": functionReturningPromise() }),
      ])
      .catch(function (err) {
        throw err !== undefined
          ? err
          : new DOMException("The request is not allowed", "NotAllowedError");
      });
  }

  // ...Otherwise, use document.execCommand() fallback
  return functionReturningPromise().then((textBlob) => {
    textBlob.text().then((text) => {
      return clipboardCopyFallback(text);
    });
  });
}

function clipboardCopyFallback(text: string): boolean {
  // Put the text to copy into a <span>
  const span = document.createElement("span");
  span.textContent = text;

  // Preserve consecutive spaces and newlines
  span.style.whiteSpace = "pre";

  // Add the <span> to the page
  document.body.appendChild(span);

  // Make a selection object representing the range of text selected by the user
  // `getSelection` only returns null outside a browsing context.
  const selection = window.getSelection()!;
  const range = window.document.createRange();
  selection.removeAllRanges();
  range.selectNode(span);
  selection.addRange(range);

  // Copy text to the clipboard
  let success = false;
  try {
    success = window.document.execCommand("copy");
  } catch (err) {
    // eslint-disable-next-line no-console
    console.log("error", err);
  }

  // Cleanup
  selection.removeAllRanges();
  window.document.body.removeChild(span);
  return success;
}

/**
 * Merges two sorted lists into one sorted list.
 *
 * @param list1 - The first list.
 * @param list2 - The second list.
 * @param comparator - Called with an item from the first list and an item from
 *   the second list. It returns true if the second item should go before the
 *   first one.
 * @returns The merged list.
 */
export function mergeSortedLists<A, B>(
  list1: A[],
  list2: B[],
  comparator: (item1: A, item2: B) => boolean
): (A | B)[] {
  let index1 = 0;
  let index2 = 0;
  const merged: (A | B)[] = [];
  while (index1 < list1.length || index2 < list2.length) {
    if (
      index1 === list1.length ||
      (index2 < list2.length && comparator(list1[index1], list2[index2]))
    ) {
      merged.push(list2[index2]);
      index2++;
    } else {
      merged.push(list1[index1]);
      index1++;
    }
  }
  return merged;
}

/**
 * The caret's position in the viewport.
 *
 * @param element - The text field.
 * @param options - Options for `caretCoordinates`.
 * @returns The caret's viewport coordinates.
 */
export function getCaretPosition(
  element: HTMLTextAreaElement | HTMLInputElement,
  options?: Parameters<typeof caretCoordinates>[1]
): { x: number; y: number } {
  const position = caretCoordinates(element, options);

  // Get the position of the textarea on the page
  const textareaRect = element.getBoundingClientRect();

  // Calculate the x and y coordinates by adding the element's position
  const adjustedPosition = {
    x: position.left + textareaRect.left,
    y: position.top + textareaRect.top,
  };

  return adjustedPosition;
}

/**
 * Builds a regular expression that finds markdown tables.
 *
 * @returns A regular expression finding all markdown tables.
 */
export function findTableRegex(): RegExp {
  return /((\r?){2}|^)(^\|[^\r\n]*(\r?\n)?)+(?=(\r?\n){2}|$)/gm;
}

/**
 * Blocks every key press except digits, Enter, Tab, the arrow keys and the
 * deletion keys.
 *
 * @param event - The keydown event.
 * @param allowNegative - Whether to allow a minus sign.
 */
export function allowOnlyNumericInput(
  event: KeyboardEvent,
  allowNegative = false
) {
  const ALLOWED_KEYS = [
    "Enter",
    "Backspace",
    "Tab",
    "Delete",
    "ArrowLeft",
    "ArrowUp",
    "ArrowRight",
    "ArrowDown",
    "0",
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
  ];

  if (!ALLOWED_KEYS.includes(event.key)) {
    if (allowNegative && event.key === "-") {
      return;
    } else {
      event.preventDefault();
    }
  }
}

/**
 * Turns `"null"` and `"undefined"` query parameter values back into `null`.
 *
 * @param params - The parameters. They are changed in place.
 * @returns The parameters.
 */
export function cleanNullQueryParams<T extends object>(params: T): T {
  for (const [key, val] of Object.entries(params)) {
    if (val === "undefined" || val === "null") {
      (params as Record<string, unknown>)[key] = null;
    }
  }
  return params;
}

/**
 * The element a node is, or the parent element of a text node.
 *
 * @param node - The node.
 * @returns The element.
 */
export function getElement(node: Node): Element | null {
  // Callers pass the text nodes and elements that selection ranges end in.
  return node.nodeType === Node.TEXT_NODE
    ? node.parentElement
    : (node as Element);
}

/**
 * Asks the service worker whether this tab is the primary one.
 *
 * @returns Whether it is, and true without a service worker or an answer.
 */
export function isPrimaryTab(): Promise<boolean> {
  if (!capabilities.supportsServiceWorker) {
    return Promise.resolve(true);
  }

  return new Promise((resolve) => {
    let timer: ReturnType<typeof discourseLater> | undefined;

    const finish = (isPrimary: boolean) => {
      cancel(timer);
      navigator.serviceWorker.removeEventListener("message", onMessage);
      resolve(isPrimary);
    };

    const onMessage = (event: MessageEvent) => {
      // the service worker also posts unrelated messages on this channel
      if (typeof event.data?.primaryTab === "boolean") {
        finish(event.data.primaryTab);
      }
    };

    navigator.serviceWorker.addEventListener("message", onMessage);

    // if the service worker never answers (no active registration), assume
    // primary rather than hanging forever and silently dropping the action
    timer = discourseLater(() => finish(true), 1000);

    navigator.serviceWorker.ready.then((registration) => {
      registration.active?.postMessage({ action: "primaryTab" });
    });
  });
}

/**
 * Reads an export of a module, when the module exists.
 *
 * @param path - The module name.
 * @param name - The export name. Defaults to `"default"`.
 * @returns The export, or false when there is no such module.
 */
export function optionalRequire(path: string, name = "default") {
  return require.has(path) && require(path)[name];
}

// Keep in sync with `NO_DESTINATION_COOKIE` in `app/controllers/application_controller.rb`
const NO_DESTINATION_COOKIE = [
  "/login",
  "/signup",
  "/session/",
  "/auth/",
  "/uploads/",
];

/**
 * Whether a URL can be sent to after logging in.
 *
 * @param url - The URL.
 * @returns True unless the URL is the homepage or an auth or upload path. A
 *   falsy URL is returned as is.
 */
export function isValidDestinationUrl(url: string | null | undefined) {
  return (
    url &&
    url !== getURL("/") &&
    !NO_DESTINATION_COOKIE.some((p) => url.startsWith(getURL(p)))
  );
}

/**
 * Runs an async action one at a time, queueing at most one more run while it
 * runs.
 */
export class ActionSerializer {
  declare perform: () => unknown;
  declare processing: boolean;
  declare queued: boolean;

  /**
   * @param perform - The action.
   */
  constructor(perform: () => unknown) {
    this.perform = perform;
    this.processing = false;
    this.queued = false;
  }

  /** Runs the action, or queues one more run if it is running. */
  async trigger() {
    this.queued = true;

    if (!this.processing) {
      this.processing = true;

      while (this.queued) {
        this.queued = false;
        await this.perform();
      }

      this.processing = false;
    }
  }
}

/**
 * Given an async method that takes no parameters, produces a method that
 * triggers the original method only if it is not currently executing it.
 * Otherwise it queues up to one execution of the method.
 *
 * @param target - The class prototype.
 * @param key - The method name.
 * @param descriptor - The method descriptor.
 * @returns The descriptor.
 */
export function serializedAction(
  target: object,
  key: string,
  descriptor: PropertyDescriptor
): PropertyDescriptor {
  const originalMethod = descriptor.value;

  descriptor.value = function (this: Record<string, ActionSerializer>) {
    this[`_${key}_serializer`] ||= new ActionSerializer(() =>
      originalMethod.apply(this)
    );
    this[`_${key}_serializer`].trigger();
  };

  return descriptor;
}

/**
 * Breaks a list into chunks, starting a new chunk at each element the predicate
 * is true for.
 *
 * @param elements - The list.
 * @param f - The predicate.
 * @returns The chunks.
 */
export function splitWhere<T>(
  elements: T[],
  f: (element: T) => unknown
): T[][] {
  return elements.reduce((acc: T[][], el, i) => {
    if (i === 0 || f(el)) {
      acc.push([]);
    }
    acc[acc.length - 1].push(el);
    return acc;
  }, []);
}

/** The application provides moment globally. */
declare const moment: typeof import("moment");

/** The module loader's `require`, which the application provides globally. */
declare const require: {
  (path: string): Record<string, unknown>;
  has(path: string): boolean;
};
