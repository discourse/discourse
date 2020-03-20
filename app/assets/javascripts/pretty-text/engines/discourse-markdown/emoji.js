import { buildEmojiUrl, isCustomEmoji } from "pretty-text/emoji";
import { translations } from "pretty-text/emoji/data";

const MAX_NAME_LENGTH = 60;

let translationTree = null;

// This allows us to efficiently search for aliases
// We build a data structure that allows us to quickly
// search through our N next chars to see if any match
// one of our alias emojis.
function buildTranslationTree() {
  let tree = [];
  let lastNode;

  Object.keys(translations).forEach(key => {
    let node = tree;

    for (let i = 0; i < key.length; i++) {
      let code = key.charCodeAt(i);
      let found = false;

      for (let j = 0; j < node.length; j++) {
        if (node[j][0] === code) {
          node = node[j][1];
          found = true;
          break;
        }
      }

      if (!found) {
        // code, children, value
        let tmp = [code, []];
        node.push(tmp);
        lastNode = tmp;
        node = tmp[1];
      }
    }

    lastNode[2] = translations[key];
  });

  return tree;
}

function imageFor(code, opts) {
  code = code.toLowerCase();
  const url = buildEmojiUrl(code, opts);
  if (url) {
    const title = `:${code}:`;
    const classes = isCustomEmoji(code, opts) ? "emoji emoji-custom" : "emoji";
    return { url, title, classes };
  }
}

function getEmojiName(content, pos, state, inlineEmoji) {
  if (content.charCodeAt(pos) !== 58) {
    return;
  }

  if (pos > 0) {
    let prev = content.charCodeAt(pos - 1);
    if (
      !inlineEmoji &&
      !state.md.utils.isSpace(prev) &&
      !state.md.utils.isPunctChar(String.fromCharCode(prev))
    ) {
      return;
    }
  }

  pos++;
  if (content.charCodeAt(pos) === 58) {
    return;
  }

  let length = 0;
  while (length < MAX_NAME_LENGTH) {
    length++;

    if (content.charCodeAt(pos + length) === 58) {
      // check for t2-t6
      if (content.substr(pos + length + 1, 3).match(/t[2-6]:/)) {
        length += 3;
      }
      break;
    }

    if (pos + length > content.length) {
      return;
    }
  }

  if (length === MAX_NAME_LENGTH) {
    return;
  }

  return content.substr(pos, length);
}

// straight forward :smile: to emoji image
function getEmojiTokenByName(name, state) {
  let info;
  if ((info = imageFor(name, state.md.options.discourse))) {
    let token = new state.Token("emoji", "img", 0);
    token.attrs = [
      ["src", info.url],
      ["title", info.title],
      ["class", info.classes],
      ["alt", info.title]
    ];

    return token;
  }
}

function getEmojiTokenByTranslation(content, pos, state) {
  translationTree = translationTree || buildTranslationTree();

  let t = translationTree;
  let start = pos;
  let found = null;

  while (t.length > 0 && pos < content.length) {
    let matched = false;
    let code = content.charCodeAt(pos);

    for (let i = 0; i < t.length; i++) {
      if (t[i][0] === code) {
        matched = true;
        found = t[i][2];
        t = t[i][1];
        break;
      }
    }

    if (!matched) {
      return;
    }

    pos++;
  }

  if (!found) {
    return;
  }

  // quick boundary check
  if (start > 0) {
    let leading = content.charAt(start - 1);
    if (
      !state.md.utils.isSpace(leading.charCodeAt(0)) &&
      !state.md.utils.isPunctChar(leading)
    ) {
      return;
    }
  }

  // check trailing for punct or space
  if (pos < content.length) {
    let trailing = content.charCodeAt(pos);
    if (!state.md.utils.isSpace(trailing)) {
      return;
    }
  }

  let token = getEmojiTokenByName(found, state);
  if (token) {
    return { pos, token };
  }
}

function applyEmoji(
  content,
  state,
  emojiUnicodeReplacer,
  enableShortcuts,
  inlineEmoji
) {
  let result = null;
  let start = 0;

  if (emojiUnicodeReplacer) {
    content = emojiUnicodeReplacer(content);
  }

  let end = content.length;

  for (let i = 0; i < content.length - 1; i++) {
    let offset = 0;
    let token = null;

    const name = getEmojiName(content, i, state, inlineEmoji);

    if (name) {
      token = getEmojiTokenByName(name, state);
      if (token) {
        offset = name.length + 2;
      }
    }

    if (enableShortcuts && !token) {
      // handle aliases (note: we can't do this in inline cause ; is not a split point)
      const info = getEmojiTokenByTranslation(content, i, state);

      if (info) {
        offset = info.pos - i;
        token = info.token;
      }
    }

    if (token) {
      result = result || [];

      if (i - start > 0) {
        let text = new state.Token("text", "", 0);
        text.content = content.slice(start, i);
        result.push(text);
      }

      result.push(token);

      end = start = i + offset;
      i += offset - 1;
    }
  }

  if (end < content.length) {
    let text = new state.Token("text", "", 0);
    text.content = content.slice(end);
    result.push(text);
  }

  // we check for a result <= 5 because we support maximum 3 large emojis
  // EMOJI SPACE EMOJI SPACE EMOJI => 5 tokens
  if (result && result.length > 0 && result.length <= 5) {
    // we ensure line starts and ends with an emoji
    // and has no more than 3 emojis
    if (
      result[0].type === "emoji" &&
      result[result.length - 1].type === "emoji" &&
      result.filter(r => r.type === "emoji").length <= 3
    ) {
      let onlyEmojiLine = true;
      let index = 0;

      const checkNextToken = t => {
        if (!t) {
          return;
        }

        if (!["emoji", "text"].includes(t.type)) {
          onlyEmojiLine = false;
        }

        // a text token should always have an emoji before
        // and be a space
        if (
          t.type === "text" &&
          ((result[index - 1] && result[index - 1].type !== "emoji") ||
            t.content !== " ")
        ) {
          onlyEmojiLine = false;
        }

        // exit as soon as possible
        if (onlyEmojiLine) {
          index += 1;
          checkNextToken(result[index]);
        }
      };

      checkNextToken(result[index]);

      if (onlyEmojiLine) {
        result.forEach(r => {
          if (r.type === "emoji") {
            applyOnlyEmojiClass(r);
          }
        });
      }
    }
  }

  return result;
}

function applyOnlyEmojiClass(token) {
  token.attrs.forEach(attr => {
    if (attr[0] === "class") {
      attr[1] = `${attr[1]} only-emoji`;
    }
  });
}

export function setup(helper) {
  helper.registerOptions((opts, siteSettings, state) => {
    opts.features.emoji = !state.disableEmojis && !!siteSettings.enable_emoji;
    opts.features.emojiShortcuts = !!siteSettings.enable_emoji_shortcuts;
    opts.features.inlineEmoji = !!siteSettings.enable_inline_emoji_translation;
    opts.emojiSet = siteSettings.emoji_set || "";
    opts.customEmoji = state.customEmoji;
  });

  helper.registerPlugin(md => {
    md.core.ruler.push("emoji", state =>
      md.options.discourse.helpers.textReplace(state, (c, s) =>
        applyEmoji(
          c,
          s,
          md.options.discourse.emojiUnicodeReplacer,
          md.options.discourse.features.emojiShortcuts,
          md.options.discourse.features.inlineEmoji
        )
      )
    );
  });

  helper.whiteList([
    "img[class=emoji]",
    "img[class=emoji emoji-custom]",
    "img[class=emoji emoji-custom only-emoji]",
    "img[class=emoji only-emoji]"
  ]);
}
