import xss from 'pretty-text/xss';

const _validIframes = [];

function attr(name, value) {
  return `${name}="${xss.escapeAttrValue(value)}"`;
}

const ESCAPE_REPLACEMENTS = {
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  '"': "&quot;",
  "'": "&#x27;",
  '`': '&#x60;'
};
const BAD_CHARS = /[&<>"'`]/g;
const POSSIBLE_CHARS = /[&<>"'`]/;

function escapeChar(chr) {
  return ESCAPE_REPLACEMENTS[chr];
}

export function escape(string) {
  // don't escape SafeStrings, since they're already safe
  if (string === null) {
    return "";
  } else if (!string) {
    return string + '';
  }

  // Force a string conversion as this will be done by the append regardless and
  // the regex test will do this transparently behind the scenes, causing issues if
  // an object's to string has escaped characters in it.
  string = "" + string;

  if (!POSSIBLE_CHARS.test(string)) { return string; }
  return string.replace(BAD_CHARS, escapeChar);
}

export function hrefAllowed(href) {
  // escape single quotes
  href = href.replace(/'/g, "%27");

  // absolute urls
  if (/^(https?:)?\/\/[\w\.\-]+/i.test(href)) { return href; }
  // relative urls
  if (/^\/[\w\.\-]+/i.test(href)) { return href; }
  // anchors
  if (/^#[\w\.\-]+/i.test(href)) { return href; }
  // mailtos
  if (/^mailto:[\w\.\-@]+/i.test(href)) { return href; }
}

export function sanitize(text, whiteLister) {
  if (!text) return "";

  // Allow things like <3 and <_<
  text = text.replace(/<([^A-Za-z\/\!]|$)/g, "&lt;$1");

  const whiteList = whiteLister.getWhiteList();

  let hadIframe = false;
  let result = xss(text, {
    whiteList: whiteList.tagList,
    stripIgnoreTag: true,
    stripIgnoreTagBody: ['script', 'table'],
    onIgnoreTagAttr(tag, name, value) {
      hadIframe = hadIframe || tag === 'iframe';
      const forTag = whiteList.attrList[tag];
      if (forTag) {
        const forAttr = forTag[name];
        if ((forAttr && (forAttr.indexOf('*') !== -1 || forAttr.indexOf(value) !== -1)) ||
            (name.indexOf('data-') === 0 && forTag['data-*']) ||
            ((tag === 'a' && name === 'href') && hrefAllowed(value)) ||
            (tag === 'img' && name === 'src' && (/^data:image.*$/i.test(value) || hrefAllowed(value))) ||
            (tag === 'iframe' && name === 'src' && _validIframes.some(i => i.test(value)))) {
          return attr(name, value);
        }

        if (tag === 'iframe' && name === 'src') {
          return "-STRIP-";
        }

        const custom = whiteLister.getCustom();
        for (let i=0; i<custom.length; i++) {
          const fn = custom[i];
          if (fn(tag, name, value)) {
            return attr(name, value);
          }
        }
      }
    },
  });

  return result.replace(/\[removed\]/g, '')
               .replace(/\<iframe[^>]+\-STRIP\-[^>]*>[^<]*<\/iframe>/g, '')
               .replace(/&(?![#\w]+;)/g, '&amp;')
               .replace(/&#39;/g, "'")
               .replace(/ \/>/g, '>');
};

export function whiteListIframe(regexp) {
  _validIframes.push(regexp);
}

whiteListIframe(/^(https?:)?\/\/www\.google\.com\/maps\/embed\?.+/i);
whiteListIframe(/^(https?:)?\/\/www\.openstreetmap\.org\/export\/embed.html\?.+/i);
