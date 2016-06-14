import { registerOption } from 'pretty-text/pretty-text';
import { buildEmojiUrl } from 'pretty-text/emoji';
import { translations } from 'pretty-text/emoji/data';

let _unicodeReplacements;
let _unicodeRegexp;
export function setUnicodeReplacements(replacements) {
  _unicodeReplacements = replacements;
  if (replacements) {
    _unicodeRegexp = new RegExp(Object.keys(replacements).join("|"), "g");
  }
};

function escapeRegExp(s) {
  return s.replace(/[-/\\^$*+?.()|[\]{}]/gi, '\\$&');
}

function checkPrev(prev) {
  if (prev && prev.length) {
    const lastToken = prev[prev.length-1];
    if (lastToken && lastToken.charAt) {
      const lastChar = lastToken.charAt(lastToken.length-1);
      if (!/\W/.test(lastChar)) return false;
    }
  }
  return true;
}

registerOption((siteSettings, opts, state) => {
  opts.features.emoji = !!siteSettings.enable_emoji;
  opts.emojiSet = siteSettings.emoji_set || "";
  opts.customEmoji = state.customEmoji;
});

export function setup(helper) {

  helper.whiteList('img.emoji');

  function imageFor(code) {
    code = code.toLowerCase();
    const url = buildEmojiUrl(code, helper.getOptions());
    if (url) {
      const title = `:${code}:`;
      return ['img', { href: url, title, 'class': 'emoji', alt: title }];
    }
  }

  const translationsWithColon = {};
  Object.keys(translations).forEach(t => {
    if (t[0] === ':') {
      translationsWithColon[t] = translations[t];
    } else {
      const replacement = translations[t];
      helper.inlineReplace(t, (token, match, prev) => {
        return checkPrev(prev) ? imageFor(replacement) : token;
      });
    }
  });
  const translationColonRegexp = new RegExp(Object.keys(translationsWithColon).map(t => `(${escapeRegExp(t)})`).join("|"));

  helper.registerInline(':', (text, match, prev) => {
    const endPos = text.indexOf(':', 1);
    const firstSpace = text.search(/\s/);
    if (!checkPrev(prev)) { return; }

    // If there is no trailing colon, check our translations that begin with colons
    if (endPos === -1 || (firstSpace !== -1 && endPos > firstSpace)) {
      translationColonRegexp.lastIndex = 0;
      const m = translationColonRegexp.exec(text);
      if (m && m[0] && text.indexOf(m[0]) === 0) {
        // Check outer edge
        const lastChar = text.charAt(m[0].length);
        if (lastChar && !/\s/.test(lastChar)) return;
        const contents = imageFor(translationsWithColon[m[0]]);
        if (contents) {
          return [m[0].length, contents];
        }
      }
      return;
    }

    // Simple find and replace from our array
    const between = text.slice(1, endPos);
    const contents = imageFor(between);
    if (contents) {
      return [endPos+1, contents];
    }
  });

  helper.addPreProcessor(text => {
    if (_unicodeReplacements) {
      _unicodeRegexp.lastIndex = 0;

      let m;
      while ((m = _unicodeRegexp.exec(text)) !== null) {
        let replacement = ":" + _unicodeReplacements[m[0]] + ":";
        const before = text.charAt(m.index-1);
        if (!/\B/.test(before)) {
          replacement = "\u200b" + replacement;
        }
        text = text.replace(m[0], replacement);
      }
    }
    return text;
  });
}
