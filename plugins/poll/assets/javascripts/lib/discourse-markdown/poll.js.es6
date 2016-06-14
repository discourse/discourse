/*eslint no-bitwise:0 */
import { registerOption } from 'pretty-text/pretty-text';

const DATA_PREFIX = "data-poll-";
const DEFAULT_POLL_NAME = "poll";
const WHITELISTED_ATTRIBUTES = ["type", "name", "min", "max", "step", "order", "status", "public"];
const ATTRIBUTES_REGEX = new RegExp("(" + WHITELISTED_ATTRIBUTES.join("|") + ")=['\"]?[^\\s\\]]+['\"]?", "g");

registerOption((siteSettings, opts) => {
  opts.features.poll = !!siteSettings.poll_enabled;
  opts.pollMaximumOptions = siteSettings.poll_maximum_options;
});

export function setup(helper) {
  helper.whiteList([
    'div.poll',
    'div.poll-info',
    'div.poll-container',
    'div.poll-buttons',
    'div[data-*]',
    'span.info-number',
    'span.info-text',
    'a.button.cast-votes',
    'a.button.toggle-results',
    'li[data-*'
  ]);

  helper.replaceBlock({
    start: /\[poll((?:\s+\w+=[^\s\]]+)*)\]([\s\S]*)/igm,
    stop: /\[\/poll\]/igm,

    emitter(blockContents, matches) {
      const contents = [];

      // post-process inside block contents
      if (blockContents.length) {
        const postProcess = bc => {
          if (typeof bc === "string" || bc instanceof String) {
            const processed = this.processInline(String(bc));
            if (processed.length) {
              contents.push(["p"].concat(processed));
            }
          } else {
            contents.push(bc);
          }
        };

        let b;
        while ((b = blockContents.shift()) !== undefined) {
          this.processBlock(b, blockContents).forEach(postProcess);
        }
      }

      // default poll attributes
      const attributes = { "class": "poll" };
      attributes[DATA_PREFIX + "status"] = "open";
      attributes[DATA_PREFIX + "name"] = DEFAULT_POLL_NAME;

      // extract poll attributes
      (matches[1].match(ATTRIBUTES_REGEX) || []).forEach(function(m) {
        const [ name, value ] = m.split("=");
        const escaped = helper.escape(value.replace(/["']/g, ""));
        attributes[DATA_PREFIX + name] = escaped;
      });

      // we might need these values later...
      let min = parseInt(attributes[DATA_PREFIX + "min"], 10);
      let max = parseInt(attributes[DATA_PREFIX + "max"], 10);
      let step = parseInt(attributes[DATA_PREFIX + "step"], 10);

      // generate the options when the type is "number"
      if (attributes[DATA_PREFIX + "type"] === "number") {
        // default values
        if (isNaN(min)) { min = 1; }
        if (isNaN(max)) { max = helper.getOptions().pollMaximumOptions; }
        if (isNaN(step)) { step = 1; }
        // dynamically generate options
        contents.push(["bulletlist"]);
        for (let o = min; o <= max; o += step) {
          contents[0].push(["listitem", String(o)]);
        }
      }

      // make sure there's only 1 child and it's a list with at least 1 option
      if (contents.length !== 1 || contents[0].length <= 1 || (contents[0][0] !== "numberlist" && contents[0][0] !== "bulletlist")) {
        return ["div"].concat(contents);
      }

      // make sure there's only options in the list
      for (let o=1; o < contents[0].length; o++) {
        if (contents[0][o][0] !== "listitem") {
          return ["div"].concat(contents);
        }
      }

      // TODO: remove non whitelisted content

      // add option id (hash)
      for (let o = 1; o < contents[0].length; o++) {
        const attr = {};
        // compute md5 hash of the content of the option
        attr[DATA_PREFIX + "option-id"] = md5(JSON.stringify(contents[0][o].slice(1)));
        // store options attributes
        contents[0][o].splice(1, 0, attr);
      }

      const result = ["div", attributes],
      poll = ["div"];

      // 1 - POLL CONTAINER
      const container = ["div", { "class": "poll-container" }].concat(contents);
      poll.push(container);

      // 2 - POLL INFO
      const info = ["div", { "class": "poll-info" }];

      // # of voters
      info.push(["p",
        ["span", { "class": "info-number" }, "0"],
        ["span", { "class": "info-text"}, I18n.t("poll.voters", { count: 0 })]
      ]);

      // multiple help text
      if (attributes[DATA_PREFIX + "type"] === "multiple") {
        const optionCount = contents[0].length - 1;

        // default values
        if (isNaN(min) || min < 1) { min = 1; }
        if (isNaN(max) || max > optionCount) { max = optionCount; }

        // add some help text
        let help;

        if (max > 0) {
          if (min === max) {
            if (min > 1) {
              help = I18n.t("poll.multiple.help.x_options", { count: min });
            }
          } else if (min > 1) {
            if (max < optionCount) {
              help = I18n.t("poll.multiple.help.between_min_and_max_options", { min: min, max: max });
            } else {
              help = I18n.t("poll.multiple.help.at_least_min_options", { count: min });
            }
          } else if (max <= optionCount) {
            help = I18n.t("poll.multiple.help.up_to_max_options", { count: max });
          }
        }

        if (help) { info.push(["p", help]); }
      }

      if (attributes[DATA_PREFIX + "public"] === "true") {
        info.push(["p", I18n.t("poll.public.title")]);
      }

      poll.push(info);

      // 3 - BUTTONS
      const buttons = ["div", { "class": "poll-buttons" }];

      // add "cast-votes" button
      if (attributes[DATA_PREFIX + "type"] === "multiple") {
        buttons.push(["a", { "class": "button cast-votes", "title": I18n.t("poll.cast-votes.title") }, I18n.t("poll.cast-votes.label")]);
      }

      // add "toggle-results" button
      buttons.push(["a", { "class": "button toggle-results", "title": I18n.t("poll.show-results.title") }, I18n.t("poll.show-results.label")]);

      // 4 - MIX IT ALL UP
      result.push(poll);
      result.push(buttons);

      return result;
    }
  });
}

/*!
 * Joseph Myer's md5() algorithm wrapped in a self-invoked function to prevent
 * global namespace polution, modified to hash unicode characters as UTF-8.
 *  
 * Copyright 1999-2010, Joseph Myers, Paul Johnston, Greg Holt, Will Bond <will@wbond.net>
 * http://www.myersdaily.org/joseph/javascript/md5-text.html
 * http://pajhome.org.uk/crypt/md5
 * 
 * Released under the BSD license
 * http://www.opensource.org/licenses/bsd-license
 */
function md5cycle(x, k) {
  var a = x[0], b = x[1], c = x[2], d = x[3];

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
  return cmn((b & c) | ((~b) & d), a, b, x, s, t);
}

function gg(a, b, c, d, x, s, t) {
  return cmn((b & d) | (c & (~d)), a, b, x, s, t);
}

function hh(a, b, c, d, x, s, t) {
  return cmn(b ^ c ^ d, a, b, x, s, t);
}

function ii(a, b, c, d, x, s, t) {
  return cmn(c ^ (b | (~d)), a, b, x, s, t);
}

function md51(s) {
  // Converts the string to UTF-8 "bytes" when necessary
  if (/[\x80-\xFF]/.test(s)) {
    s = unescape(encodeURI(s));
  }
  var n = s.length, state = [1732584193, -271733879, -1732584194, 271733878], i;
  for (i = 64; i <= s.length; i += 64) {
    md5cycle(state, md5blk(s.substring(i - 64, i)));
  }
  s = s.substring(i - 64);
  var tail = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
  for (i = 0; i < s.length; i++)
  tail[i >> 2] |= s.charCodeAt(i) << ((i % 4) << 3);
  tail[i >> 2] |= 0x80 << ((i % 4) << 3);
  if (i > 55) {
    md5cycle(state, tail);
    for (i = 0; i < 16; i++) tail[i] = 0;
  }
  tail[14] = n * 8;
  md5cycle(state, tail);
  return state;
}

function md5blk(s) { /* I figured global was faster.   */
  var md5blks = [], i; /* Andy King said do it this way. */
  for (i = 0; i < 64; i += 4) {
    md5blks[i >> 2] = s.charCodeAt(i) +
                      (s.charCodeAt(i + 1) << 8) +
                      (s.charCodeAt(i + 2) << 16) +
                      (s.charCodeAt(i + 3) << 24);
  }
  return md5blks;
}

var hex_chr = '0123456789abcdef'.split('');

function rhex(n) {
  var s = '', j = 0;
  for (; j < 4; j++)
  s += hex_chr[(n >> (j * 8 + 4)) & 0x0F] +
       hex_chr[(n >> (j * 8)) & 0x0F];
  return s;
}

function hex(x) {
  for (var i = 0; i < x.length; i++)
  x[i] = rhex(x[i]);
  return x.join('');
}

function add32(a, b) {
  return (a + b) & 0xFFFFFFFF;
}

function md5(s) {
  return hex(md51(s));
}
