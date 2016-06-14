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
  constructor(features) {
    features.default = true;

    this._featureKeys = Object.keys(features).filter(f => features[f]);
    this._key = this._featureKeys.join(':');
    this._features = features;
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
  'br',
  'p',
  'strong',
  'em',
  'blockquote',
  'div',
  'div.title',
  'div.quote-controls',
  'i',
  'b',
  'ul',
  'ol',
  'li',
  'small',
  'code',
  'span.mention',
  'span.hashtag',
  'span.excerpt',
  'aside.quote',
  'aside[data-*]',
  'a[name]',
  'a[target=_blank]',
  'a[rel=nofollow]',
  'a.attachment',
  'a.onebox',
  'a.mention',
  'a.mention-group',
  'a.hashtag',
  'a[name]',
  'a[data-bbcode]',
  'a[title]',
  'img[class]',
  'img[alt]',
  'img[title]',
  'img[width]',
  'img[height]',
  'pre',
  'hr',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'iframe',
  'iframe[height]',
  'iframe[width]',
  'iframe[frameborder]',
  'iframe[marginheight]',
  'iframe[marginwidth]',
]);
