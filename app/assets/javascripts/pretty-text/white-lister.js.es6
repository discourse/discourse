const masterList = {};
const masterCallbacks = {};

const _whiteLists = {};
const _callbacks = {};

function concatUniq(src, elems) {
  src = src || [];
  if (!Array.isArray(elems)) {
    elems = [elems];
  }
  return src.concat(elems.filter(e => src.indexOf(e) === -1));
}

export default class WhiteLister {
  constructor(options) {
    options.features.default = true;

    this._featureKeys = Object.keys(options.features).filter(f => options.features[f]);
    this._key = this._featureKeys.join(':');
    this._features = options.features;
    this._options = options||{};
  }

  getCustom() {
    if (!_callbacks[this._key]) {
      const callbacks = [];
      this._featureKeys.forEach(f => {
        (masterCallbacks[f] || []).forEach(cb => callbacks.push(cb));
      });
      _callbacks[this._key] = callbacks;
    }

    return _callbacks[this._key];
  }

  getWhiteList() {
    if (!_whiteLists[this._key]) {
      const tagList = {};
      let attrList = {};

      // merge whitelists for these features
      this._featureKeys.forEach(f => {
        const info = masterList[f] || {};
        Object.keys(info).forEach(t => {
          tagList[t] = [];
          attrList[t] = attrList[t] || {};

          const attrs = info[t];
          Object.keys(attrs).forEach(a => attrList[t][a] = concatUniq(attrList[t][a], attrs[a]));
        });
      });

      _whiteLists[this._key] = { tagList, attrList };
    }
    return _whiteLists[this._key];
  }

  getAllowedHrefSchemes() {
    return this._options.allowedHrefSchemes || [];
  }
}

// Builds our object that represents whether something is sanitized for a particular feature.
export function whiteListFeature(feature, info) {
  const featureInfo = {};

  // we can supply a callback instead
  if (info.custom) {
    masterCallbacks[feature] = masterCallbacks[feature] || [];
    masterCallbacks[feature].push(info.custom);
    return;
  }

  if (typeof info === "string") { info = [info]; }

  (info || []).forEach(tag => {
    const classes = tag.split('.');
    const tagName = classes.shift();
    const m = /\[([^\]]+)]/.exec(tagName);
    if (m) {
      const [full, inside] = m;
      const stripped = tagName.replace(full, '');
      const vals = inside.split('=');

      featureInfo[stripped] = featureInfo[stripped] || {};
      if (vals.length === 2) {
        const [name, value] = vals;
        featureInfo[stripped][name] = value;
      } else {
        featureInfo[stripped][inside] = '*';
      }
    }

    featureInfo[tagName] = featureInfo[tagName] || {};
    if (classes.length) {
      featureInfo[tagName]['class'] = concatUniq(featureInfo[tagName]['class'], classes);
    }
  });

  masterList[feature] = featureInfo;
}

// Only add to `default` when you always want your whitelist to occur. In other words,
// don't change this for a plugin or a feature that can be disabled
whiteListFeature('default', [
  'a.attachment',
  'a.hashtag',
  'a.mention',
  'a.mention-group',
  'a.onebox',
  'a[data-bbcode]',
  'a[name]',
  'a[rel=nofollow]',
  'a[target=_blank]',
  'a[title]',
  'abbr[title]',
  'aside.quote',
  'aside[data-*]',
  'b',
  'big',
  'blockquote',
  'br',
  'code',
  'dd',
  'del',
  'div',
  'div.quote-controls',
  'div.title',
  'div[align]',
  'div[dir]',
  'dl',
  'dt',
  'em',
  'h1[id]',
  'h2[id]',
  'h3[id]',
  'h4[id]',
  'h5[id]',
  'h6[id]',
  'hr',
  'i',
  'iframe',
  'iframe[frameborder]',
  'iframe[height]',
  'iframe[marginheight]',
  'iframe[marginwidth]',
  'iframe[width]',
  'img[alt]',
  'img[class]',
  'img[height]',
  'img[title]',
  'img[width]',
  'ins',
  'kbd',
  'li',
  'ol',
  'p',
  'pre',
  's',
  'small',
  'span.excerpt',
  'span.hashtag',
  'span.mention',
  'strike',
  'strong',
  'sub',
  'sup',
  'ul',
]);
