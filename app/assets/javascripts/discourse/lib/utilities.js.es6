import { escape } from "pretty-text/sanitizer";
import toMarkdown from "discourse/lib/to-markdown";

const homepageSelector = "meta[name=discourse_current_homepage]";

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
  // don't escape SafeStrings, since they're already safe
  if (string instanceof Handlebars.SafeString) {
    return string.toString();
  }

  return escape(string);
}

let _usernameFormatDelegate = username => username;

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
  return size * Math.min(3, Math.max(1, Math.round(pixelRatio)));
}

export function avatarImg(options, getURL) {
  getURL = getURL || Discourse.getURLWithCDN;

  const size = translateSize(options.size);
  const url = avatarUrl(options.avatarTemplate, size);

  // We won't render an invalid url
  if (!url || url.length === 0) {
    return "";
  }

  const classes =
    "avatar" + (options.extraClasses ? " " + options.extraClasses : "");
  const title = options.title
    ? " title='" + escapeExpression(options.title || "") + "'"
    : "";

  return (
    "<img alt='' width='" +
    size +
    "' height='" +
    size +
    "' src='" +
    getURL(url) +
    "' class='" +
    classes +
    "'" +
    title +
    ">"
  );
}

export function tinyAvatar(avatarTemplate, options) {
  return avatarImg(
    _.merge({ avatarTemplate: avatarTemplate, size: "tiny" }, options)
  );
}

export function postUrl(slug, topicId, postNumber) {
  var url = Discourse.getURL("/t/");
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

export function emailValid(email) {
  // see:  http://stackoverflow.com/questions/46155/validate-email-address-in-javascript
  const re = /^[a-zA-Z0-9!#$%&'*+\/=?\^_`{|}~\-]+(?:\.[a-zA-Z0-9!#$%&'\*+\/=?\^_`{|}~\-]+)*@(?:[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?\.)+[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?$/;
  return re.test(email);
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

    $div.append(range.cloneContents());
  }

  return toMarkdown($div.html());
}

export function selectedElement() {
  const selection = window.getSelection();
  if (selection.rangeCount > 0) {
    return selection.getRangeAt(0).startContainer.parentElement;
  }
}

// Determine the row and col of the caret in an element
export function caretRowCol(el) {
  var cp = caretPosition(el);
  var rows = el.value.slice(0, cp).split("\n");
  var rowNum = rows.length;

  var colNum =
    cp -
    rows.splice(0, rowNum - 1).reduce(function(sum, row) {
      return sum + row.length + 1;
    }, 0);

  return { rowNum: rowNum, colNum: colNum };
}

// Determine the position of the caret in an element
export function caretPosition(el) {
  var r, rc, re;
  if (el.selectionStart) {
    return el.selectionStart;
  }
  if (document.selection) {
    el.focus();
    r = document.selection.createRange();
    if (!r) return 0;

    re = el.createTextRange();
    rc = re.duplicate();
    re.moveToBookmark(r.getBookmark());
    rc.setEndPoint("EndToStart", re);
    return rc.text.length;
  }
  return 0;
}

// Set the caret's position
export function setCaretPosition(ctrl, pos) {
  var range;
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

export function defaultHomepage() {
  let homepage = null;
  let elem = _.first($(homepageSelector));
  if (elem) {
    homepage = elem.content;
  }
  if (!homepage) {
    homepage = Discourse.SiteSettings.top_menu.split("|")[0].split(",")[0];
  }
  return homepage;
}

export function setDefaultHomepage(homepage) {
  let elem = _.first($(homepageSelector));
  if (elem) {
    elem.content = homepage;
  }
}

export function determinePostReplaceSelection({
  selection,
  needle,
  replacement
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
  const caps = Discourse.__container__.lookup("capabilities:main");
  return caps.isIOS && !navigator.userAgent.match(/Trident/g);
}

let iPadDetected = undefined;

export function iOSWithVisualViewport() {
  return isAppleDevice() && window.visualViewport !== undefined;
}

export function isiPad() {
  if (iPadDetected === undefined) {
    iPadDetected =
      navigator.userAgent.match(/iPad/g) &&
      !navigator.userAgent.match(/Trident/g);
  }
  return iPadDetected;
}

export function safariHacksDisabled() {
  if (iOSWithVisualViewport()) return false;

  let pref = localStorage.getItem("safari-hacks-disabled");
  let result = false;
  if (pref !== null) {
    result = pref === "true";
  }
  return result;
}

const toArray = items => {
  items = items || [];

  if (!Array.isArray(items)) {
    return Array.from(items);
  }

  return items;
};

export function clipboardData(e, canUpload) {
  const clipboard =
    e.clipboardData ||
    e.originalEvent.clipboardData ||
    e.delegatedEvent.originalEvent.clipboardData;

  const types = toArray(clipboard.types);
  let files = toArray(clipboard.files);

  if (types.includes("Files") && files.length === 0) {
    // for IE
    files = toArray(clipboard.items).filter(i => i.kind === "file");
  }

  canUpload = files && canUpload && types.includes("Files");
  const canUploadImage =
    canUpload && files.filter(f => f.type.match("^image/"))[0];
  const canPasteHtml =
    Discourse.SiteSettings.enable_rich_text_paste &&
    types.includes("text/html") &&
    !canUploadImage;

  return { clipboard, types, canUpload, canPasteHtml };
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
    currentMoment = moment(currentMoment)
      .add(1, "day")
      .format("YYYY-MM-DD");
  }
  return data;
}

export function areCookiesEnabled() {
  // see: https://github.com/Modernizr/Modernizr/blob/400db4043c22af98d46e1d2b9cbc5cb062791192/feature-detects/cookies.js
  try {
    document.cookie = "cookietest=1";
    var ret = document.cookie.indexOf("cookietest=") !== -1;
    document.cookie = "cookietest=1; expires=Thu, 01-Jan-1970 00:00:01 GMT";
    return ret;
  } catch (e) {
    return false;
  }
}

export function isiOSPWA() {
  return (
    window.matchMedia("(display-mode: standalone)").matches &&
    navigator.userAgent.match(/(iPad|iPhone|iPod)/g)
  );
}

export function isAppWebview() {
  return window.ReactNativeWebView !== undefined;
}

export function postRNWebviewMessage(prop, value) {
  if (window.ReactNativeWebView !== undefined) {
    window.ReactNativeWebView.postMessage(JSON.stringify({ [prop]: value }));
  }
}

function reportToLogster(name, error) {
  const data = {
    message: `${name} theme/component is throwing errors`,
    stacktrace: error.stack
  };

  Ember.$.ajax(`${Discourse.BaseUri}/logs/report_js_error`, {
    data,
    type: "POST",
    cache: false
  });
}
// this function is used in lib/theme_javascript_compiler.rb
export function rescueThemeError(name, error, api) {
  /* eslint-disable-next-line no-console */
  console.error(`"${name}" error:`, error);
  reportToLogster(name, error);

  const currentUser = api.getCurrentUser();
  if (!currentUser || !currentUser.admin) {
    return;
  }

  const path = `${Discourse.BaseUri}/admin/customize/themes`;
  const message = I18n.t("themes.broken_theme_alert", {
    theme: name,
    path: `<a href="${path}">${path}</a>`
  });
  const alertDiv = document.createElement("div");
  alertDiv.classList.add("broken-theme-alert");
  alertDiv.innerHTML = `⚠️ ${message}`;
  document.body.prepend(alertDiv);
}

const CODE_BLOCKS_REGEX = /^(    |\t).*|`[^`]+`|^```[^]*?^```|\[code\][^]*?\[\/code\]/gm;
//                        |      ^     |   ^   |      ^      |           ^           |
//                               |         |          |                  |
//                               |         |          |       code blocks between [code]
//                               |         |          |
//                               |         |          +--- code blocks between three backquote
//                               |         |
//                               |         +----- inline code between backquotes
//                               |
//                               +------- paragraphs starting with 4 spaces or tab

export function inCodeBlock(text, pos) {
  let result = false;

  let match;
  while ((match = CODE_BLOCKS_REGEX.exec(text)) !== null) {
    const begin = match.index;
    const end = match.index + match[0].length;
    if (begin <= pos && pos <= end) {
      result = true;
    }
  }

  return result;
}

// This prevents a mini racer crash
export default {};
