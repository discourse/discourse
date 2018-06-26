import { buildEmojiUrl, isCustomEmoji } from "pretty-text/emoji";
import { translations } from "pretty-text/emoji/data";

const MAX_NAME_LENGTH = 60;

let translationTree = null;

// This allows us to efficiently search for aliases
// We build a data structure that allows us to quickly
// search through our N next chars to see if any match
// one of our alias emojis.
//
function buildTranslationTree() {
  let tree = [];
  let lastNode;

  Object.keys(translations).forEach(function(key) {
    let i;
    let node = tree;

    for (i = 0; i < key.length; i++) {
      let code = key.charCodeAt(i);
      let j;

      let found = false;

      for (j = 0; j < node.length; j++) {
        if (node[j][0] === code) {
          node = node[j][1];
          found = true;
          break;
        }
      }

      if (!found) {
        // token, children, value
        let tmp = [code, []];
        node.push(tmp);
        lastNode = tmp;
        node = tmp[1];
      }
    }

    lastNode[1] = translations[key];
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

function getEmojiName(content, pos, state) {
  if (content.charCodeAt(pos) !== 58) {
    return;
  }

  if (pos > 0) {
    let prev = content.charCodeAt(pos - 1);
    if (
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

  let currentTree = translationTree;

  let i;
  let search = true;
  let found = false;
  let start = pos;

  while (search) {
    search = false;
    let code = content.charCodeAt(pos);

    for (i = 0; i < currentTree.length; i++) {
      if (currentTree[i][0] === code) {
        currentTree = currentTree[i][1];
        pos++;
        search = true;
        if (typeof currentTree === "string") {
          found = currentTree;
        }
        break;
      }
    }
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

function applyEmoji(content, state, emojiUnicodeReplacer, enableShortcuts) {
  let i;
  let result = null;
  let contentToken = null;

  let start = 0;

  if (emojiUnicodeReplacer) {
    content = emojiUnicodeReplacer(content);
  }

  let endToken = content.length;

  for (i = 0; i < content.length - 1; i++) {
    let offset = 0;
    let emojiName = getEmojiName(content, i, state);
    let token = null;

    if (emojiName) {
      token = getEmojiTokenByName(emojiName, state);
      if (token) {
        offset = emojiName.length + 2;
      }
    }

    if (enableShortcuts && !token) {
      // handle aliases (note: we can't do this in inline cause ; is not a split point)
      //
      let info = getEmojiTokenByTranslation(content, i, state);

      if (info) {
        offset = info.pos - i;
        token = info.token;
      }
    }

    if (token) {
      result = result || [];
      if (i - start > 0) {
        contentToken = new state.Token("text", "", 0);
        contentToken.content = content.slice(start, i);
        result.push(contentToken);
      }

      result.push(token);
      endToken = start = i + offset;
    }
  }

  if (endToken < content.length) {
    contentToken = new state.Token("text", "", 0);
    contentToken.content = content.slice(endToken);
    result.push(contentToken);
  }

  return result;
}

export function setup(helper) {
  helper.registerOptions((opts, siteSettings, state) => {
    opts.features.emoji = !!siteSettings.enable_emoji;
    opts.features.emojiShortcuts = !!siteSettings.enable_emoji_shortcuts;
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
          md.options.discourse.features.emojiShortcuts
        )
      )
    );
  });

  helper.whiteList(["img[class=emoji]", "img[class=emoji emoji-custom]"]);
}
