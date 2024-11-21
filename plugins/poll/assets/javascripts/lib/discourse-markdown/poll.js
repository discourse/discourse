/*eslint no-bitwise:0 */
import { i18n } from "discourse-i18n";

const DATA_PREFIX = "data-poll-";
const DEFAULT_POLL = { name: "poll", status: "open" };
const ALLOWED_ATTRIBUTES = [
  "chartType",
  "close",
  "groups",
  "max",
  "min",
  "name",
  "order",
  "public",
  "results",
  "status",
  "step",
  "type",
];

function addNumberListItems(state, pollTokens, min, max, step) {
  pollTokens.push(new state.Token("bullet_list_open", "ul", 1));

  for (let i = min; i <= max; i += step) {
    pollTokens.push(new state.Token("list_item_open", "li", 1));

    let token = new state.Token("text", "", 0);
    token.content = String(i);
    pollTokens.push(token);

    pollTokens.push(new state.Token("list_item_close", "li", -1));
  }

  pollTokens.push(new state.Token("bullet_list_close", "ul", -1));
}

function addPollContainer(state, titleTokens, pollTokens) {
  let token = state.push("poll_container_open", "div", 1);
  token.attrs = [["class", "poll-container"]];

  if (titleTokens.length > 0) {
    token = state.push("poll_title_open", "div", 1);
    token.attrs = [["class", "poll-title"]];
    state.tokens.push(...titleTokens);
    state.push("poll_title_close", "div", -1);
  }

  for (let i = 0; i < pollTokens.length; i++) {
    if (pollTokens[i].type === "list_item_open") {
      let listItemCloseIndex = pollTokens.findIndex(
        (t, j) => j > i && t.type === "list_item_close"
      );

      if (listItemCloseIndex === -1) {
        continue;
      }

      let text = pollTokens
        .slice(i, listItemCloseIndex + 1)
        .filter((c) => c.type === "text" || c.type === "inline")
        .map((c) => c.content)
        .join(" ");

      let hash = md5(JSON.stringify([text]));

      pollTokens[i].attrs ||= [];
      pollTokens[i].attrs.push([DATA_PREFIX + "option-id", hash]);
    }
  }

  state.tokens.push(...pollTokens);

  state.push("poll_container_close", "div", -1);
}

function addPollInfo(state) {
  let token = state.push("poll_info_open", "div", 1);
  token.attrs = [["class", "poll-info"]];

  token = state.push("poll_info_counts_open", "div", 1);
  token.attrs = [["class", "poll-info_counts"]];

  token = state.push("poll_info_counts_count_open", "div", 1);
  token.attrs = [["class", "poll-info_counts-count"]];

  token = state.push("poll_info_number_open", "span", 1);
  token.attrs = [["class", "info-number"]];
  token.block = false;

  token = state.push("text", "", 0);
  token.content = "0";

  state.push("poll_info_number_close", "span", -1);

  token = state.push("poll_info_label_open", "span", 1);
  token.attrs = [["class", "info-label"]];
  token.block = false;

  token = state.push("text", "", 0);
  token.content = i18n("poll.voters", { count: 0 });

  state.push("poll_info_label_close", "span", -1);
  state.push("poll_info_counts_count_close", "div", -1);
  state.push("poll_info_counts_close", "div", -1);
  state.push("poll_info_close", "div", -1);
}

const rule = {
  tag: "poll",

  before(state, { attrs }) {
    let open = state.tokens.filter((t) => t.type === "poll_open").length;
    let closed = state.tokens.filter((t) => t.type === "poll_close").length;

    if (open > closed) {
      return; // poll-ception is now allowed
    }

    let token = state.push("poll_open", "div", 1);
    token.poll_attrs = { ...DEFAULT_POLL, ...attrs };
  },

  after(state, openToken) {
    if (openToken.type !== "poll_open") {
      return;
    }

    let attrs = openToken.poll_attrs;
    let openTokenIndex = state.tokens.indexOf(openToken);
    let pollTokens = state.tokens.slice(openTokenIndex + 1);
    let titleTokens = [];

    if (pollTokens.length > 0 && pollTokens[0].type === "heading_open") {
      let idx = pollTokens.findIndex((t) => t.type === "heading_close");

      if (idx !== -1) {
        titleTokens = pollTokens.splice(0, idx + 1).slice(1, -1);
        state.tokens.splice(openTokenIndex + 1, idx + 1);
      }
    }

    if (attrs.type === "number") {
      let min = parseInt(attrs.min, 10);
      let max = parseInt(attrs.max, 10);
      let step = parseInt(attrs.step, 10);

      if (isNaN(min)) {
        min = 1;
      }

      if (isNaN(max)) {
        max = state.md.options.discourse.pollMaximumOptions;
      }

      if (isNaN(step) || step < 1) {
        step = 1;
      }

      if (pollTokens.length > 0) {
        state.tokens.splice(openTokenIndex, 1);
        return;
      } else if (min <= max) {
        addNumberListItems(state, pollTokens, min, max, step);
      }
    }

    state.tokens.splice(openTokenIndex + 1);

    openToken.attrs ||= [];
    openToken.attrs.push(["class", "poll"]);

    for (let n of ALLOWED_ATTRIBUTES) {
      if (attrs[n]) {
        openToken.attrs.push([DATA_PREFIX + n, attrs[n]]);
      }
    }

    if (pollTokens.length > 0) {
      if (!pollTokens[0].type.endsWith("_list_open")) {
        return;
      }
    }

    addPollContainer(state, titleTokens, pollTokens);
    addPollInfo(state);

    state.push("poll_close", "div", -1);
  },
};

export function setup(helper) {
  helper.allowList([
    "a.button.cast-votes",
    "a.button.toggle-results",
    "div.poll-buttons",
    "div.poll-container",
    "div.poll-info_counts-count",
    "div.poll-info_counts",
    "div.poll-info",
    "div.poll-title",
    "div.poll",
    "div[data-*]",
    "li[data-*]",
    "span.info-label",
    "span.info-number",
    "span.info-text",
  ]);

  helper.registerOptions((opts, siteSettings) => {
    opts.features.poll = siteSettings.poll_enabled;
    opts.pollMaximumOptions = siteSettings.poll_maximum_options;
  });

  helper.registerPlugin((md) => md.block.bbcode.ruler.push("poll", rule));
}

/*!
 * Joseph Myer's md5() algorithm wrapped in a self-invoked function to prevent
 * global namespace pollution, modified to hash unicode characters as UTF-8.
 *
 * Copyright 1999-2010, Joseph Myers, Paul Johnston, Greg Holt, Will Bond <will@wbond.net>
 * http://www.myersdaily.org/joseph/javascript/md5-text.html
 * http://pajhome.org.uk/crypt/md5
 *
 * Released under the BSD license
 * http://www.opensource.org/licenses/bsd-license
 */
function md5cycle(x, k) {
  let a = x[0],
    b = x[1],
    c = x[2],
    d = x[3];

  a = ff(a, b, c, d, k[0], 7, -680876936);
  d = ff(d, a, b, c, k[1], 12, -389564586);
  c = ff(c, d, a, b, k[2], 17, 606105819);
  b = ff(b, c, d, a, k[3], 22, -1044525330);
  a = ff(a, b, c, d, k[4], 7, -176418897);
  d = ff(d, a, b, c, k[5], 12, 1200080426);
  c = ff(c, d, a, b, k[6], 17, -1473231341);
  b = ff(b, c, d, a, k[7], 22, -45705983);
  a = ff(a, b, c, d, k[8], 7, 1770035416);
  d = ff(d, a, b, c, k[9], 12, -1958414417);
  c = ff(c, d, a, b, k[10], 17, -42063);
  b = ff(b, c, d, a, k[11], 22, -1990404162);
  a = ff(a, b, c, d, k[12], 7, 1804603682);
  d = ff(d, a, b, c, k[13], 12, -40341101);
  c = ff(c, d, a, b, k[14], 17, -1502002290);
  b = ff(b, c, d, a, k[15], 22, 1236535329);

  a = gg(a, b, c, d, k[1], 5, -165796510);
  d = gg(d, a, b, c, k[6], 9, -1069501632);
  c = gg(c, d, a, b, k[11], 14, 643717713);
  b = gg(b, c, d, a, k[0], 20, -373897302);
  a = gg(a, b, c, d, k[5], 5, -701558691);
  d = gg(d, a, b, c, k[10], 9, 38016083);
  c = gg(c, d, a, b, k[15], 14, -660478335);
  b = gg(b, c, d, a, k[4], 20, -405537848);
  a = gg(a, b, c, d, k[9], 5, 568446438);
  d = gg(d, a, b, c, k[14], 9, -1019803690);
  c = gg(c, d, a, b, k[3], 14, -187363961);
  b = gg(b, c, d, a, k[8], 20, 1163531501);
  a = gg(a, b, c, d, k[13], 5, -1444681467);
  d = gg(d, a, b, c, k[2], 9, -51403784);
  c = gg(c, d, a, b, k[7], 14, 1735328473);
  b = gg(b, c, d, a, k[12], 20, -1926607734);

  a = hh(a, b, c, d, k[5], 4, -378558);
  d = hh(d, a, b, c, k[8], 11, -2022574463);
  c = hh(c, d, a, b, k[11], 16, 1839030562);
  b = hh(b, c, d, a, k[14], 23, -35309556);
  a = hh(a, b, c, d, k[1], 4, -1530992060);
  d = hh(d, a, b, c, k[4], 11, 1272893353);
  c = hh(c, d, a, b, k[7], 16, -155497632);
  b = hh(b, c, d, a, k[10], 23, -1094730640);
  a = hh(a, b, c, d, k[13], 4, 681279174);
  d = hh(d, a, b, c, k[0], 11, -358537222);
  c = hh(c, d, a, b, k[3], 16, -722521979);
  b = hh(b, c, d, a, k[6], 23, 76029189);
  a = hh(a, b, c, d, k[9], 4, -640364487);
  d = hh(d, a, b, c, k[12], 11, -421815835);
  c = hh(c, d, a, b, k[15], 16, 530742520);
  b = hh(b, c, d, a, k[2], 23, -995338651);

  a = ii(a, b, c, d, k[0], 6, -198630844);
  d = ii(d, a, b, c, k[7], 10, 1126891415);
  c = ii(c, d, a, b, k[14], 15, -1416354905);
  b = ii(b, c, d, a, k[5], 21, -57434055);
  a = ii(a, b, c, d, k[12], 6, 1700485571);
  d = ii(d, a, b, c, k[3], 10, -1894986606);
  c = ii(c, d, a, b, k[10], 15, -1051523);
  b = ii(b, c, d, a, k[1], 21, -2054922799);
  a = ii(a, b, c, d, k[8], 6, 1873313359);
  d = ii(d, a, b, c, k[15], 10, -30611744);
  c = ii(c, d, a, b, k[6], 15, -1560198380);
  b = ii(b, c, d, a, k[13], 21, 1309151649);
  a = ii(a, b, c, d, k[4], 6, -145523070);
  d = ii(d, a, b, c, k[11], 10, -1120210379);
  c = ii(c, d, a, b, k[2], 15, 718787259);
  b = ii(b, c, d, a, k[9], 21, -343485551);

  x[0] = add32(a, x[0]);
  x[1] = add32(b, x[1]);
  x[2] = add32(c, x[2]);
  x[3] = add32(d, x[3]);
}

function cmn(q, a, b, x, s, t) {
  a = add32(add32(a, q), add32(x, t));
  return add32((a << s) | (a >>> (32 - s)), b);
}

function ff(a, b, c, d, x, s, t) {
  return cmn((b & c) | (~b & d), a, b, x, s, t);
}

function gg(a, b, c, d, x, s, t) {
  return cmn((b & d) | (c & ~d), a, b, x, s, t);
}

function hh(a, b, c, d, x, s, t) {
  return cmn(b ^ c ^ d, a, b, x, s, t);
}

function ii(a, b, c, d, x, s, t) {
  return cmn(c ^ (b | ~d), a, b, x, s, t);
}

function md51(s) {
  // Converts the string to UTF-8 "bytes"
  s = unescape(encodeURI(s));

  let n = s.length,
    state = [1732584193, -271733879, -1732584194, 271733878],
    i;
  for (i = 64; i <= s.length; i += 64) {
    md5cycle(state, md5blk(s.substring(i - 64, i)));
  }
  s = s.substring(i - 64);
  let tail = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
  for (i = 0; i < s.length; i++) {
    tail[i >> 2] |= s.charCodeAt(i) << (i % 4 << 3);
  }
  tail[i >> 2] |= 0x80 << (i % 4 << 3);
  if (i > 55) {
    md5cycle(state, tail);
    for (i = 0; i < 16; i++) {
      tail[i] = 0;
    }
  }
  tail[14] = n * 8;
  md5cycle(state, tail);
  return state;
}

function md5blk(s) {
  /* I figured global was faster.   */
  let md5blks = [],
    i; /* Andy King said do it this way. */
  for (i = 0; i < 64; i += 4) {
    md5blks[i >> 2] =
      s.charCodeAt(i) +
      (s.charCodeAt(i + 1) << 8) +
      (s.charCodeAt(i + 2) << 16) +
      (s.charCodeAt(i + 3) << 24);
  }
  return md5blks;
}

let hex_chr = "0123456789abcdef".split("");

function rhex(n) {
  let s = "",
    j = 0;
  for (; j < 4; j++) {
    s += hex_chr[(n >> (j * 8 + 4)) & 0x0f] + hex_chr[(n >> (j * 8)) & 0x0f];
  }
  return s;
}

function hex(x) {
  for (let i = 0; i < x.length; i++) {
    x[i] = rhex(x[i]);
  }
  return x.join("");
}

function add32(a, b) {
  return (a + b) & 0xffffffff;
}

function md5(s) {
  return hex(md51(s));
}
