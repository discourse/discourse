import getURL, { getURLWithCDN } from "discourse-common/lib/get-url";
import Handlebars from "handlebars";
import I18n from "I18n";
import { deepMerge } from "discourse-common/lib/object";
import { escape } from "pretty-text/sanitizer";
import { helperContext } from "discourse-common/lib/helpers";
import toMarkdown from "discourse/lib/to-markdown";
import deprecated from "discourse-common/lib/deprecated";

let _defaultHomepage;

export function splitString(str, separator = ",") {
  if (typeof str === "string") {
    return str.split(separator).filter(Boolean);
  } else {
    return [];
  }
}

export function translateSize(size) {
  switch (size) {
    case "tiny":
      return 20;
    case "small":
      return 25;
    case "medium":
      return 32;
    case "large":
      return 45;
    case "extra_large":
      return 60;
    case "huge":
      return 120;
  }
  return size;
}

export function escapeExpression(string) {
  if (!string) {
    return "";
  }

  // don't escape SafeStrings, since they're already safe
  if (string instanceof Handlebars.SafeString) {
    return string.toString();
  }

  return escape(string);
}

let _usernameFormatDelegate = (username) => username;

export function formatUsername(username) {
  return _usernameFormatDelegate(username || "");
}

export function replaceFormatter(fn) {
  _usernameFormatDelegate = fn;
}

export function avatarUrl(template, size) {
  if (!template) {
    return "";
  }
  const rawSize = getRawSize(translateSize(size));
  return template.replace(/\{size\}/g, rawSize);
}

export function getRawSize(size) {
  const pixelRatio = window.devicePixelRatio || 1;
  let rawSize = 1;
  if (pixelRatio > 1.1 && pixelRatio < 2.1) {
    rawSize = 2;
  } else if (pixelRatio >= 2.1) {
    rawSize = 3;
  }
  return size * rawSize;
}

export function avatarImg(options, customGetURL) {
  const size = translateSize(options.size);
  let path = avatarUrl(options.avatarTemplate, size);

  // We won't render an invalid url
  if (!path || path.length === 0) {
    return "";
  }
  path = (customGetURL || getURLWithCDN)(path);

  const classes =
    "avatar" + (options.extraClasses ? " " + options.extraClasses : "");

  let title = "";
  if (options.title) {
    const escaped = escapeExpression(options.title || "");
    title = ` title='${escaped}' aria-label='${escaped}'`;
  }

  return `<img loading='lazy' alt='' width='${size}' height='${size}' src='${path}' class='${classes}'${title}>`;
}

export function tinyAvatar(avatarTemplate, options) {
  return avatarImg(deepMerge({ avatarTemplate, size: "tiny" }, options));
}

export function postUrl(slug, topicId, postNumber) {
  let url = getURL("/t/");
  if (slug) {
    url += slug + "/";
  } else {
    url += "topic/";
  }
  url += topicId;
  if (postNumber > 1) {
    url += "/" + postNumber;
  }
  return url;
}

export function highlightPost(postNumber) {
  const container = document.querySelector(`#post_${postNumber}`);
  if (!container) {
    return;
  }
  const element = container.querySelector(".topic-body");
  if (!element || element.classList.contains("highlighted")) {
    return;
  }

  element.classList.add("highlighted");

  const removeHighlighted = function () {
    element.classList.remove("highlighted");
    element.removeEventListener("animationend", removeHighlighted);
  };
  element.addEventListener("animationend", removeHighlighted);
  container.querySelector(".tabLoc").focus();
}

export function emailValid(email) {
  // see:  http://stackoverflow.com/questions/46155/validate-email-address-in-javascript
  const re = /^[a-zA-Z0-9!#$%&'*+\/=?\^_`{|}~\-]+(?:\.[a-zA-Z0-9!#$%&'\*+\/=?\^_`{|}~\-]+)*@(?:[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?\.)+[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?$/;
  return re.test(email);
}

export function hostnameValid(hostname) {
  // see:  https://stackoverflow.com/questions/106179/regular-expression-to-match-dns-hostname-or-ip-address
  const re = /^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)+([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$/;
  return hostname && re.test(hostname);
}

export function extractDomainFromUrl(url) {
  if (url.indexOf("://") > -1) {
    url = url.split("/")[2];
  } else {
    url = url.split("/")[0];
  }
  return url.split(":")[0];
}

export function selectedText() {
  const selection = window.getSelection();
  if (selection.isCollapsed) {
    return "";
  }

  const $div = $("<div>");
  for (let r = 0; r < selection.rangeCount; r++) {
    const range = selection.getRangeAt(r);
    const $ancestor = $(range.commonAncestorContainer);

    // ensure we never quote text in the post menu area
    const $postMenuArea = $ancestor.find(".post-menu-area")[0];
    if ($postMenuArea) {
      range.setEndBefore($postMenuArea);
    }

    const $oneboxTest = $ancestor.closest("aside.onebox[data-onebox-src]");
    const $codeBlockTest = $ancestor.parents("pre");
    if ($codeBlockTest.length) {
      const $code = $("<code>");
      $code.append(range.cloneContents());
      // Even though this was a code block, produce a non-block quote if it's a single line.
      if (/\n/.test($code.text())) {
        const $pre = $("<pre>");
        $pre.append($code);
        $div.append($pre);
      } else {
        $div.append($code);
      }
    } else if ($oneboxTest.length) {
      // This is a partial quote from a onebox.
      // Treat it as though the entire onebox was quoted.
      const oneboxUrl = $($oneboxTest).data("onebox-src");
      $div.append(oneboxUrl);
    } else {
      $div.append(range.cloneContents());
    }
  }

  $div.find("aside.onebox[data-onebox-src]").each(function () {
    const oneboxUrl = $(this).data("onebox-src");
    $(this).replaceWith(oneboxUrl);
  });

  return toMarkdown($div.html());
}

export function selectedElement() {
  return selectedRange()?.commonAncestorContainer;
}

export function selectedRange() {
  const selection = window.getSelection();
  if (selection.rangeCount > 0) {
    return selection.getRangeAt(0);
  }
}

// Determine the row and col of the caret in an element
export function caretRowCol(el) {
  let cp = caretPosition(el);
  let rows = el.value.slice(0, cp).split("\n");
  let rowNum = rows.length;

  let colNum =
    cp -
    rows.splice(0, rowNum - 1).reduce(function (sum, row) {
      return sum + row.length + 1;
    }, 0);

  return { rowNum, colNum };
}

// Determine the position of the caret in an element
export function caretPosition(el) {
  return el?.selectionStart || 0;
}

// Set the caret's position
export function setCaretPosition(ctrl, pos) {
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

export function initializeDefaultHomepage(siteSettings) {
  let homepage;
  let sel = document.querySelector("meta[name='discourse_current_homepage']");
  if (sel) {
    homepage = sel.getAttribute("content");
  }
  if (!homepage) {
    homepage = siteSettings.top_menu.split("|")[0].split(",")[0];
  }
  setDefaultHomepage(homepage);
}

export function defaultHomepage() {
  return _defaultHomepage;
}

export function setDefaultHomepage(homepage) {
  _defaultHomepage = homepage;
}

export function determinePostReplaceSelection({
  selection,
  needle,
  replacement,
}) {
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

export function isAppleDevice() {
  // IE has no DOMNodeInserted so can not get this hack despite saying it is like iPhone
  // This will apply hack on all iDevices
  let caps = helperContext().capabilities;
  return caps.isIOS && !navigator.userAgent.match(/Trident/g);
}

let iPadDetected = undefined;

export function isiPad() {
  if (iPadDetected === undefined) {
    iPadDetected =
      navigator.userAgent.match(/iPad/g) &&
      !navigator.userAgent.match(/Trident/g);
  }
  return iPadDetected;
}

export function safariHacksDisabled() {
  deprecated(
    "`safariHacksDisabled()` is deprecated, it now always returns `false`",
    {
      since: "2.8.0.beta8",
      dropFrom: "2.9.0.beta1",
    }
  );

  return false;
}

const toArray = (items) => {
  items = items || [];

  if (!Array.isArray(items)) {
    return Array.from(items);
  }

  return items;
};

export function clipboardHelpers(e, opts) {
  const clipboard =
    e.clipboardData ||
    e.originalEvent.clipboardData ||
    e.delegatedEvent.originalEvent.clipboardData;

  const types = toArray(clipboard.types);
  let files = toArray(clipboard.files);

  if (types.includes("Files") && files.length === 0) {
    // for IE
    files = toArray(clipboard.items).filter((i) => i.kind === "file");
  }

  let canUpload = files && opts.canUpload && types.includes("Files");
  const canUploadImage =
    canUpload && files.filter((f) => f.type.match("^image/"))[0];
  const canPasteHtml =
    opts.siteSettings.enable_rich_text_paste &&
    types.includes("text/html") &&
    !canUploadImage;

  return { clipboard, types, canUpload, canPasteHtml };
}

// Replace any accented characters with their ASCII equivalent
// Return the string if it only contains ASCII printable characters,
// otherwise use the fallback
export function toAsciiPrintable(string, fallback) {
  if (typeof string.normalize === "function") {
    string = string.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
  }

  return /^[\040-\176]*$/.test(string) ? string : fallback;
}

export function slugify(string) {
  return string
    .trim()
    .toLowerCase()
    .replace(/\s|_+/g, "-") // Replace spaces and underscores with dashes
    .replace(/[^\w\-]+/g, "") // Remove non-word characters except for dashes
    .replace(/\-\-+/g, "-") // Replace multiple dashes with a single dash
    .replace(/^-+/, "") // Remove leading dashes
    .replace(/-+$/, ""); // Remove trailing dashes
}

export function toNumber(input) {
  return typeof input === "number" ? input : parseFloat(input);
}

export function isNumeric(input) {
  return !isNaN(toNumber(input)) && isFinite(input);
}

export function fillMissingDates(data, startDate, endDate) {
  const startMoment = moment(startDate, "YYYY-MM-DD");
  const endMoment = moment(endDate, "YYYY-MM-DD");
  const countDays = endMoment.diff(startMoment, "days");
  let currentMoment = startMoment;

  for (let i = 0; i <= countDays; i++) {
    let date = data[i] ? moment(data[i].x, "YYYY-MM-DD") : null;
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

export function areCookiesEnabled() {
  // see: https://github.com/Modernizr/Modernizr/blob/400db4043c22af98d46e1d2b9cbc5cb062791192/feature-detects/cookies.js
  try {
    document.cookie = "cookietest=1";
    let ret = document.cookie.indexOf("cookietest=") !== -1;
    document.cookie = "cookietest=1; expires=Thu, 01-Jan-1970 00:00:01 GMT";
    return ret;
  } catch (e) {
    return false;
  }
}

export function isiOSPWA() {
  let caps = helperContext().capabilities;
  return window.matchMedia("(display-mode: standalone)").matches && caps.isIOS;
}

export function prefersReducedMotion() {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

export function isAppWebview() {
  return window.ReactNativeWebView !== undefined;
}

export function postRNWebviewMessage(prop, value) {
  if (window.ReactNativeWebView !== undefined) {
    window.ReactNativeWebView.postMessage(JSON.stringify({ [prop]: value }));
  }
}

const CODE_BLOCKS_REGEX = /^(    |\t).*|`[^`]+`|^```[^]*?^```|\[code\][^]*?\[\/code\]/gm;
//                        |      ^     |   ^   |      ^      |           ^           |
//                               |         |          |                  |
//                               |         |          |       code blocks between [code]
//                               |         |          |
//                               |         |          +--- code blocks between three backticks
//                               |         |
//                               |         +----- inline code between backticks
//                               |
//                               +------- paragraphs starting with 4 spaces or tab

const OPEN_CODE_BLOCKS_REGEX = /`[^`]+|^```[^]*?|\[code\][^]*?/gm;

export function inCodeBlock(text, pos) {
  let end = 0;
  for (const match of text.matchAll(CODE_BLOCKS_REGEX)) {
    end = match.index + match[0].length;
    if (match.index <= pos && pos <= end) {
      return true;
    }
  }

  // Character at position `pos` can be in a code block that is unfinished.
  // To check this case, we look for any open code blocks after the last closed
  // code block.
  const lastOpenBlock = text.substr(end).search(OPEN_CODE_BLOCKS_REGEX);
  return lastOpenBlock !== -1 && pos >= end + lastOpenBlock;
}

export function translateModKey(string) {
  const { isApple } = helperContext().capabilities;
  // Apple device users are used to glyphs for shortcut keys
  if (isApple) {
    string = string
      .replace("Shift", "\u21E7")
      .replace("Meta", "\u2318")
      .replace("Alt", "\u2325")
      .replace(/\+/g, "");
  } else {
    string = string
      .replace("Shift", I18n.t("shortcut_modifier_key.shift"))
      .replace("Ctrl", I18n.t("shortcut_modifier_key.ctrl"))
      .replace("Meta", I18n.t("shortcut_modifier_key.ctrl"))
      .replace("Alt", I18n.t("shortcut_modifier_key.alt"));
  }

  return string;
}

// http://github.com/feross/clipboard-copy
export function clipboardCopy(text) {
  // Use the Async Clipboard API when available.
  // Requires a secure browsing context (i.e. HTTPS)
  if (navigator.clipboard) {
    return navigator.clipboard.writeText(text).catch(function (err) {
      throw err !== undefined
        ? err
        : new DOMException("The request is not allowed", "NotAllowedError");
    });
  }

  // ...Otherwise, use document.execCommand() fallback

  // Put the text to copy into a <span>
  const span = document.createElement("span");
  span.textContent = text;

  // Preserve consecutive spaces and newlines
  span.style.whiteSpace = "pre";

  // Add the <span> to the page
  document.body.appendChild(span);

  // Make a selection object representing the range of text selected by the user
  const selection = window.getSelection();
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

// This prevents a mini racer crash
export default {};
