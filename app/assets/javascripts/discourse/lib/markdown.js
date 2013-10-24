/*global Markdown:true BetterMarkdown:true */

/**
  Contains methods to help us with markdown formatting.

  @class Markdown
  @namespace Discourse
  @module Discourse
**/
Discourse.Markdown = {

  validClasses: {},

  /**
    Whitelists classes for sanitization

    @method whiteListClass
    @param {String} val The value to whitelist. Can supply more than one argument
  **/
  whiteListClass: function() {
    var args = Array.prototype.slice.call(arguments),
        validClasses = Discourse.Markdown.validClasses;

    args.forEach(function (a) {
      validClasses[a] = true;
    });
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
    if (!raw) return "";
    if (raw.length === 0) return "";

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
    @param {String} url Url to check
    @return {String} url to insert in the cooked content
  **/
  urlAllowed: function (url) {
    if(/^https?:\/\//.test(url)) { return url; }
    if(/^\/\/?[\w\.\-]+/.test(url)) { return url; }
  },

  /**
    Checks to see if a name, class or id is allowed in the cooked content

    @method nameIdClassAllowed
    @param {String} val The name, class or id to check
    @return {String} val the transformed name class or id
  **/
  nameIdClassAllowed: function(val) {
    if (Discourse.Markdown.validClasses[val]) { return val; }
  },


  /**
    Sanitize text using the sanitizer

    @method sanitize
    @param {String} text The text to sanitize
    @return {String} text The sanitized text
  **/
  sanitize: function(text) {
    if (!window.html_sanitize) return "";
    return window.html_sanitize(text, Discourse.Markdown.urlAllowed, Discourse.Markdown.nameIdClassAllowed);
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
        if (!text) return "";

        return text;
      }
    };
  }

};
RSVP.EventTarget.mixin(Discourse.Markdown);

Discourse.Markdown.whiteListClass("attachment");
