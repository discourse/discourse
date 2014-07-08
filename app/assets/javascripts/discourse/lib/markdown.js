/*global Markdown:true BetterMarkdown:true */

/**
  Contains methods to help us with markdown formatting.

  @class Markdown
  @namespace Discourse
  @module Discourse
**/
var _validClasses = {},
    _validIframes = [],
    _validTags = {};

function validateAttribute(tagName, attribName, value) {
  var tag = _validTags[tagName];

  // Handle classes
  if (attribName === "class") {
    if (_validClasses[value]) { return value; }

    if (tag) {
      var classes = tag['class'];
      if (classes && (classes.indexOf(value) !== -1 || classes.indexOf('*') !== -1)) {
        return value;
      }
    }
  } else if (attribName.indexOf('data-') === 0) {
    // data-* attributes
    if (tag) {
      var allowed = tag[attribName] || tag['data-*'];
      if (allowed === value || allowed.indexOf('*') !== -1) { return value; }
    }
  }

  if (tag) {
    var attrs = tag[attribName];
    if (attrs && (attrs.indexOf(value) !== -1 ||
                  attrs.indexOf('*') !== -1) ||
                  _.any(attrs,function(r){return (r instanceof RegExp) && value.search(r) >= 0;})
        ) { return value; }
  }
}

Discourse.Markdown = {

  /**
    Whitelist class for only a certain tag

    @param {String} tagName to whitelist
    @param {String} attribName to whitelist
    @param {String} value to whitelist
  **/
  whiteListTag: function(tagName, attribName, value) {
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
    Creates a new pagedown markdown editor, supplying i18n translations.

    @method createEditor
    @param {Object} converterOptions custom options for our markdown converter
    @return {Markdown.Editor} the editor instance
  **/
  createEditor: function(converterOptions) {
    if (!converterOptions) converterOptions = {};

    // By default we always sanitize content in the editor
    converterOptions.sanitize = true;

    var markdownConverter = Discourse.Markdown.markdownConverter(converterOptions);

    var editorOptions = {
      strings: {
        bold: I18n.t("composer.bold_title") + " <strong> Ctrl+B",
        boldexample: I18n.t("composer.bold_text"),

        italic: I18n.t("composer.italic_title") + " <em> Ctrl+I",
        italicexample: I18n.t("composer.italic_text"),

        link: I18n.t("composer.link_title") + " <a> Ctrl+L",
        linkdescription: I18n.t("composer.link_description"),
        linkdialog: "<p><b>" + I18n.t("composer.link_dialog_title") + "</b></p><p>http://example.com/ \"" +
            I18n.t("composer.link_optional_text") + "\"</p>",

        quote: I18n.t("composer.quote_title") + " <blockquote> Ctrl+Q",
        quoteexample: I18n.t("composer.quote_text"),

        code: I18n.t("composer.code_title") + " <pre><code> Ctrl+K",
        codeexample: I18n.t("composer.code_text"),

        image: I18n.t("composer.upload_title") + " - Ctrl+G",
        imagedescription: I18n.t("composer.upload_description"),

        olist: I18n.t("composer.olist_title") + " <ol> Ctrl+O",
        ulist: I18n.t("composer.ulist_title") + " <ul> Ctrl+U",
        litem: I18n.t("composer.list_item"),

        heading: I18n.t("composer.heading_title") + " <h1>/<h2> Ctrl+H",
        headingexample: I18n.t("composer.heading_text"),

        hr: I18n.t("composer.hr_title") + " <hr> Ctrl+R",

        undo: I18n.t("composer.undo_title") + " - Ctrl+Z",
        redo: I18n.t("composer.redo_title") + " - Ctrl+Y",
        redomac: I18n.t("composer.redo_title") + " - Ctrl+Shift+Z",

        help: I18n.t("composer.help")
      }
    };

    return new Markdown.Editor(markdownConverter, undefined, editorOptions);
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
    Checks to see if a name, class or id is allowed in the cooked content

    @method nameIdClassAllowed
    @param {String} tagName to check
    @param {String} attribName to check
    @param {String} value to check
  **/


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
Discourse.Markdown.whiteListTag('a', 'target', '_blank');
Discourse.Markdown.whiteListTag('a', 'class', 'onebox');
Discourse.Markdown.whiteListTag('a', 'class', 'mention');

Discourse.Markdown.whiteListTag('a', 'data-bbcode');

Discourse.Markdown.whiteListTag('div', 'class', 'title');
Discourse.Markdown.whiteListTag('div', 'class', 'quote-controls');
Discourse.Markdown.whiteListTag('code', 'class', '*');
Discourse.Markdown.whiteListTag('span', 'class', 'mention');
Discourse.Markdown.whiteListTag('span', 'class', 'spoiler');
Discourse.Markdown.whiteListTag('div', 'class', 'spoiler');
Discourse.Markdown.whiteListTag('aside', 'class', 'quote');
Discourse.Markdown.whiteListTag('aside', 'data-*');

Discourse.Markdown.whiteListTag('span', 'bbcode-b');
Discourse.Markdown.whiteListTag('span', 'bbcode-i');
Discourse.Markdown.whiteListTag('span', 'bbcode-u');
Discourse.Markdown.whiteListTag('span', 'bbcode-s');

Discourse.Markdown.whiteListTag('span', 'class', /bbcode-size-\d+/);

Discourse.Markdown.whiteListIframe(/^(https?:)?\/\/www\.google\.com\/maps\/embed\?.+/i);
