// inspired from https://github.com/markdown-it/markdown-it/blob/master/lib/rules_inline/html_inline.mjs
// note that allow lister will run on top of it, so if a tag is allowed here but not on
// the allow list, then it won't show up

const inline_names = ["kbd", "mark"];

const patterns = inline_names.join("|");
const attr_name = "[a-zA-Z_:][a-zA-Z0-9:._-]*";
const unquoted = "[^\"'=<>`\\x00-\\x20]+";
const single_quoted = "'[^']*'";
const double_quoted = '"[^"]*"';
const attr_value =
  "(?:" + unquoted + "|" + single_quoted + "|" + double_quoted + ")";
const attribute = "(?:\\s+" + attr_name + "(?:\\s*=\\s*" + attr_value + ")?)";
const open_tag = `<(${patterns})` + attribute + "*\\s*\\/?>";
const close_tag = `<\\/(${patterns})\\s*>`;
const comment = "<!---?>|<!--(?:[^-]|-[^-]|--[^>])*-->";
const processing = "<[?][\\s\\S]*?[?]>";
const declaration = "<![A-Za-z][^>]*>";
const cdata = "<!\\[CDATA\\[[\\s\\S]*?\\]\\]>";
const HTML_TAG_RE = new RegExp(
  "^(?:" +
    open_tag +
    "|" +
    close_tag +
    "|" +
    comment +
    "|" +
    processing +
    "|" +
    declaration +
    "|" +
    cdata +
    ")"
);

function isLinkOpen(str) {
  return /^<a[>\s]/i.test(str);
}
function isLinkClose(str) {
  return /^<\/a\s*>/i.test(str);
}

function isLetter(ch) {
  /*eslint no-bitwise:0*/
  let lc = ch | 0x20; // to lower case
  return lc >= 0x61 /* a */ && lc <= 0x7a /* z */;
}

function chatHtmlInlineRule(state, silent) {
  let ch,
    match,
    max,
    token,
    pos = state.pos;

  if (!state.md.options.html) {
    return false;
  }

  // Check start
  max = state.posMax;
  if (state.src.charCodeAt(pos) !== 0x3c /* < */ || pos + 2 >= max) {
    return false;
  }

  // Quick fail on second char
  ch = state.src.charCodeAt(pos + 1);
  if (
    ch !== 0x21 /* ! */ &&
    ch !== 0x3f /* ? */ &&
    ch !== 0x2f /* / */ &&
    !isLetter(ch)
  ) {
    return false;
  }

  match = state.src.slice(pos).match(HTML_TAG_RE);

  if (!match) {
    return false;
  }

  if (!silent) {
    token = state.push("html_inline", "", 0);

    token.content = match[0];

    if (isLinkOpen(token.content)) {
      state.linkLevel++;
    }
    if (isLinkClose(token.content)) {
      state.linkLevel--;
    }
  }
  state.pos += match[0].length;
  return true;
}

export function setup(helper) {
  helper.registerPlugin((md) => {
    if (md.options.discourse.features["chat-html-inline"]) {
      md.inline.ruler.push("chat-html-inline", chatHtmlInlineRule);
    }
  });
}
