/*global Markdown:true */

/**
  Contains methods to help us with markdown formatting.

  @class Markdown
  @namespace Discourse
  @module Discourse
**/
Discourse.Markdown = {

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
    Creates a Markdown.Converter that we we can use for formatting

    @method markdownConverter
    @param {Object} opts the converting options
  **/
  markdownConverter: function(opts) {
    if (!opts) opts = {};

    var converter = new Markdown.Converter();
    var mentionLookup = opts.mentionLookup || Discourse.Mention.lookupCache;

    var quoteTemplate = null, urlsTemplate = null;

    // Before cooking callbacks
    converter.hooks.chain("preConversion", function(text) {
      // If a user puts text right up against a quote, make sure the spacing is equivalnt to a new line
      return text.replace(/\[\/quote\]/, "[/quote]\n");
    });

    converter.hooks.chain("preConversion", function(text) {
      Discourse.Markdown.trigger('beforeCook', { detail: text, opts: opts });
      return Discourse.Markdown.textResult || text;
    });

    // Extract quotes so their contents are not passed through markdown.
    converter.hooks.chain("preConversion", function(text) {
      var extracted = Discourse.BBCode.extractQuotes(text);
      quoteTemplate = extracted.template;
      return extracted.text;
    });

    // Extract urls in BBCode tags so they are not passed through markdown.
    converter.hooks.chain("preConversion", function(text) {
      var extracted = Discourse.BBCode.extractUrls(text);
      urlsTemplate = extracted.template;
      return extracted.text;
    });

    // Support autolinking of www.something.com
    converter.hooks.chain("preConversion", function(text) {
      return text.replace(/(^|[\s\n])(www\.[a-z\.\-\_\(\)\/\?\=\%0-9]+)/gim, function(full, _, rest) {
        return " <a href=\"http://" + rest + "\">" + rest + "</a>";
      });
    });

    // newline prediction in trivial cases
    var linebreaks = opts.traditional_markdown_linebreaks || Discourse.SiteSettings.traditional_markdown_linebreaks;
    if (!linebreaks) {
      converter.hooks.chain("preConversion", function(text) {
        return text.replace(/(^[\w<][^\n]*\n+)/gim, function(t) {
          if (t.match(/\n{2}/gim)) return t;
          return t.replace("\n", "  \n");
        });
      });
    }

    // github style fenced code
    converter.hooks.chain("preConversion", function(text) {
      return text.replace(/^`{3}(?:(.*$)\n)?([\s\S]*?)^`{3}/gm, function(wholeMatch, m1, m2) {
        var escaped = Handlebars.Utils.escapeExpression(m2);
        return "<pre><code class='" + (m1 || 'lang-auto') + "'>" + escaped + "</code></pre>";
      });
    });

    converter.hooks.chain("postConversion", function(text) {
      if (!text) return "";

      // don't do @username mentions inside <pre> or <code> blocks
      text = text.replace(/<(pre|code)>([\s\S](?!<(pre|code)>))*?@([\s\S](?!<(pre|code)>))*?<\/(pre|code)>/gi, function(m) {
        return m.replace(/@/g, '&#64;');
      });

      // add @username mentions, if valid; must be bounded on left and right by non-word characters
      text = text.replace(/(\W)(@[A-Za-z0-9][A-Za-z0-9_]{2,14})(?=\W)/g, function(x, pre, name) {
        if (mentionLookup(name.substr(1))) {
          return pre + "<a href='" + Discourse.getURL("/users/") + (name.substr(1).toLowerCase()) + "' class='mention'>" + name + "</a>";
        } else {
          return pre + "<span class='mention'>" + name + "</span>";
        }
      });

      // a primitive attempt at oneboxing, this regex gives me much eye sores
      text = text.replace(/(<li>)?((<p>|<br>)[\s\n\r]*)(<a href=["]([^"]+)[^>]*)>([^<]+<\/a>[\s\n\r]*(?=<\/p>|<br>))/gi, function() {
        // We don't onebox items in a list
        if (arguments[1]) return arguments[0];
        var url = arguments[5];
        var onebox;

        if (Discourse && Discourse.Onebox) {
          onebox = Discourse.Onebox.lookupCache(url);
        }
        if (onebox && onebox.trim().length > 0) {
          return arguments[2] + onebox;
        } else {
          return arguments[2] + arguments[4] + " class=\"onebox\" target=\"_blank\">" + arguments[6];
        }
      });

      return(text);
    });

    converter.hooks.chain("postConversion", function(text) {
      // reapply quotes
      if (quoteTemplate) { text = quoteTemplate(text); }
      // reapply urls
      if (urlsTemplate) { text = urlsTemplate(text); }
      // format with BBCode
      return Discourse.BBCode.format(text, opts);
    });

    if (opts.sanitize) {
      converter.hooks.chain("postConversion", function(text) {
        if (!window.sanitizeHtml) return "";
        return window.sanitizeHtml(text);
      });
    }
    return converter;
  }

};
RSVP.EventTarget.mixin(Discourse.Markdown);
