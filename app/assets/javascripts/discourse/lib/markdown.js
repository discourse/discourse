/**
  Contains methods to help us with markdown formatting.

  @class Markdown
  @namespace Discourse
  @module Discourse
**/

/**
 * An object mapping from HTML tag names to an object mapping the valid
 * attributes on that tag to an array of permitted values.
 *
 * The permitted values can be strings or regexes.
 *
 * The pseduo-attribute 'data-*' can be used to validate any data-foo
 * attributes without any specified validations.
 *
 * Code can insert into this map by calling Discourse.Markdown.whiteListTag().
 *
 * Example:
 *
 * <pre><code>
 * {
 *   a: {
 *     href: ['*'],
 *     data-mention-id: [/^\d+$/],
 *     ...
 *   },
 *   code: {
 *     class: ['ada', 'haskell', 'c', 'cpp', ... ]
 *   },
 *   ...
 * }
 * </code></pre>
 *
 * @private
 */
var _validTags = {};
/**
 * Classes valid on all elements. Map from class name to 'true'.
 * @private
 */
var _validClasses = {};
var _validIframes = [];
var _decoratedCaja = false;

function validateAttribute(tagName, attribName, value) {
  var tag = _validTags[tagName];

  // Handle classes
  if (attribName === "class") {
    if (_validClasses[value]) { return value; }
  }

  if (attribName.indexOf('data-') === 0) {
    // data-* catch-all validators
    if (tag && tag['data-*'] && !tag[attribName]) {
      var permitted = tag['data-*'];
      if (permitted && (
            permitted.indexOf(value) !== -1 ||
            permitted.indexOf('*') !== -1 ||
            ((permitted instanceof RegExp) && permitted.test(value)))
        ) { return value; }
    }
  }

  if (tag) {
    var attrs = tag[attribName];
    if (attrs && (attrs.indexOf(value) !== -1 ||
                  attrs.indexOf('*') !== -1) ||
                  _.any(attrs, function(r) { return (r instanceof RegExp) && r.test(value); })
        ) { return value; }
  }

  // return undefined;
}

function anchorRegexp(regex) {
  if (/^\^.*\$$/.test(regex.source)) {
    return regex; // already anchored
  }

  var flags = "";
  if (regex.global) {
    if (typeof console !== 'undefined') {
      console.warn("attribute validation regex should not be global");
    }
  }

  if (regex.ignoreCase) { flags += "i"; }
  if (regex.multiline) { flags += "m"; }
  if (regex.sticky) { throw "Invalid attribute validation regex - cannot be sticky"; }

  return new RegExp("^" + regex.source + "$", flags);
}

Discourse.Markdown = {

  /**
    Add to the attribute whitelist for a certain HTML tag.

    @param {String} tagName tag to whitelist the attr for
    @param {String} attribName attr to whitelist for the tag
    @param {String | RegExp} [value] whitelisted value for the attribute
  **/
  whiteListTag: function(tagName, attribName, value) {
    if (value instanceof RegExp) {
      value = anchorRegexp(value);
    }
    _validTags[tagName] = _validTags[tagName] || {};
    _validTags[tagName][attribName] = _validTags[tagName][attribName] || [];
    _validTags[tagName][attribName].push(value || '*');
  },

  /**
    Whitelists more classes for sanitization.

    @param {...String} var_args Classes to whitelist
    @method whiteListClass
  **/
  whiteListClass: function() {
    var args = Array.prototype.slice.call(arguments);
    args.forEach(function (a) { _validClasses[a] = true; });
  },

  /**
    Whitelists iframes for sanitization

    @method whiteListIframe
    @param {Regexp} regexp The regexp to whitelist.
  **/
  whiteListIframe: function(regexp) {
    _validIframes.push(regexp);
  },

  /**
    Convert a raw string to a cooked markdown string.

    @method cook
    @param {String} raw the raw string we want to apply markdown to
    @param {Object} opts the options for the rendering
    @return {String} the cooked markdown string
  **/
  cook: function(raw, opts) {
    if (!opts) opts = {};

    // Make sure we've got a string
    if (!raw || raw.length === 0) return "";

    return this.markdownConverter(opts).makeHtml(raw);
  },

  /**
    Checks to see if a URL is allowed in the cooked content

    @method urlAllowed
    @param {String} uri Url to check
    @param {Number} effect ignored
    @param {Number} ltype ignored
    @param {Object} hints an object with hints, used to check if this url is from an iframe
    @return {String} url to insert in the cooked content
  **/
  urlAllowed: function (uri, effect, ltype, hints) {
    var url = typeof(uri) === "string" ? uri : uri.toString();

    // escape single quotes
    url = url.replace(/'/g, "%27");

    // whitelist some iframe only
    if (hints && hints.XML_TAG === "iframe" && hints.XML_ATTR === "src") {
      for (var i = 0, length = _validIframes.length; i < length; i++) {
        if(_validIframes[i].test(url)) { return url; }
      }
      return;
    }

    // absolute urls
    if(/^(https?:)?\/\/[\w\.\-]+/i.test(url)) { return url; }
    // relative urls
    if(/^\/[\w\.\-]+/i.test(url)) { return url; }
    // anchors
    if(/^#[\w\.\-]+/i.test(url)) { return url; }
    // mailtos
    if(/^mailto:[\w\.\-@]+/i.test(url)) { return url; }
  },

  /**
    Sanitize text using the sanitizer

    @method sanitize
    @param {String} text The text to sanitize
    @return {String} text The sanitized text
  **/
  sanitize: function(text) {
    if (!window.html_sanitize || !text) return "";

    // Allow things like <3 and <_<
    text = text.replace(/<([^A-Za-z\/\!]|$)/g, "&lt;$1");

    // The first time, let's add some more whitelisted tags
    if (!_decoratedCaja) {

      // Add anything whitelisted to the list of elements if it's not in there already.
      var elements = window.html4.ELEMENTS;
      Object.keys(_validTags).forEach(function(t) {
        if (!elements[t]) {
          elements[t] = 0;
        }
      });

      _decoratedCaja = true;
    }

    return window.html_sanitize(text, Discourse.Markdown.urlAllowed, validateAttribute);
  },

  /**
    Creates a Markdown.Converter that we we can use for formatting

    @method markdownConverter
    @param {Object} opts the converting options
  **/
  markdownConverter: function(opts) {
    if (!opts) opts = {};

    return {
      makeHtml: function(text) {
        text = Discourse.Dialect.cook(text, opts);
        return !text ? "" : text;
      }
    };
  }

};

RSVP.EventTarget.mixin(Discourse.Markdown);

Discourse.Markdown.whiteListTag('a', 'class', 'attachment');
Discourse.Markdown.whiteListTag('a', 'class', 'onebox');
Discourse.Markdown.whiteListTag('a', 'class', 'mention');
Discourse.Markdown.whiteListTag('a', 'class', 'mention-group');
Discourse.Markdown.whiteListTag('a', 'class', 'hashtag');

Discourse.Markdown.whiteListTag('a', 'target', '_blank');
Discourse.Markdown.whiteListTag('a', 'rel', 'nofollow');
Discourse.Markdown.whiteListTag('a', 'data-bbcode');
Discourse.Markdown.whiteListTag('a', 'name');

Discourse.Markdown.whiteListTag('img', 'src', /^data:image.*$/i);

Discourse.Markdown.whiteListTag('div', 'class', 'title');
Discourse.Markdown.whiteListTag('div', 'class', 'quote-controls');

Discourse.Markdown.whiteListTag('span', 'class', 'mention');
Discourse.Markdown.whiteListTag('span', 'class', 'hashtag');
Discourse.Markdown.whiteListTag('aside', 'class', 'quote');
Discourse.Markdown.whiteListTag('aside', 'data-*');

Discourse.Markdown.whiteListTag('span', 'bbcode-b');
Discourse.Markdown.whiteListTag('span', 'bbcode-i');
Discourse.Markdown.whiteListTag('span', 'bbcode-u');
Discourse.Markdown.whiteListTag('span', 'bbcode-s');

// used for pinned topics
Discourse.Markdown.whiteListTag('span', 'class', 'excerpt');

Discourse.Markdown.whiteListIframe(/^(https?:)?\/\/www\.google\.com\/maps\/embed\?.+/i);
Discourse.Markdown.whiteListIframe(/^(https?:)?\/\/www\.openstreetmap\.org\/export\/embed.html\?.+/i);
