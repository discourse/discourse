/*global sanitizeHtml:true Markdown:true */

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
  **/
  cook: function(raw, opts) {
    if (!opts) opts = {};

    // Make sure we've got a string
    if (!raw) return "";
    if (raw.length === 0) return "";

    this.converter = this.markdownConverter(opts);
    return this.converter.makeHtml(raw);
  },

  /**
    Creates a new markdown editor

    @method createNewMarkdownEditor
    @param {Markdown.Converter} markdownConverter the converter object
    @param {String} idPostfix
    @param {Object} options the options for the markdown editor
  **/
  createNewMarkdownEditor: function(markdownConverter, idPostfix, options) {
    options = options || {};
    options.strings = {
      bold: I18n.t("js.composer.bold_title") + " <strong> Ctrl+B",
      boldexample: I18n.t("js.composer.bold_text"),

      italic: I18n.t("js.composer.italic_title") + " <em> Ctrl+I",
      italicexample: I18n.t("js.composer.italic_text"),

      link: I18n.t("js.composer.link_title") + " <a> Ctrl+L",
      linkdescription: "enter link description here",
      linkdialog: "<p><b>" + I18n.t("js.composer.link_dialog_title") + "</b></p><p>http://example.com/ \"" +
          I18n.t("js.composer.link_optional_text") + "\"</p>",

      quote: I18n.t("js.composer.quote_title") + " <blockquote> Ctrl+Q",
      quoteexample: I18n.t("js.composer.quote_text"),

      code: I18n.t("js.composer.code_title") + " <pre><code> Ctrl+K",
      codeexample: I18n.t("js.composer.code_text"),

      image: I18n.t("js.composer.image_title") + " <img> Ctrl+G",
      imagedescription: I18n.t("js.composer.image_description"),
      imagedialog: "<p><b>" + I18n.t("js.composer.image_dialog_title") + "</b></p><p>http://example.com/images/diagram.jpg \"" +
          I18n.t("js.composer.image_optional_text") + "\"<br><br>" + I18n.t("js.composer.image_hosting_hint") + "</p>",

      olist: I18n.t("js.composer.olist_title") + " <ol> Ctrl+O",
      ulist: I18n.t("js.composer.ulist_title") + " <ul> Ctrl+U",
      litem: I18n.t("js.compser.list_item"),

      heading: I18n.t("js.composer.heading_title") + " <h1>/<h2> Ctrl+H",
      headingexample: I18n.t("js.composer.heading_text"),

      hr: I18n.t("js.composer_hr_title") + " <hr> Ctrl+R",

      undo: I18n.t("js.composer.undo_title") + " - Ctrl+Z",
      redo: I18n.t("js.composer.redo_title") + " - Ctrl+Y",
      redomac: I18n.t("js.composer.redo_title") + " - Ctrl+Shift+Z",

      help: I18n.t("js.composer.help")
    };

    return new Markdown.Editor(markdownConverter, idPostfix, options);
  },

  /**
    Creates a Markdown.Converter that we we can use for formatting

    @method markdownConverter
    @param {Object} opts the converting options
  **/
  markdownConverter: function(opts) {
    var converter, mentionLookup,
      _this = this;
    converter = new Markdown.Converter();
    if (opts) {
      mentionLookup = opts.mentionLookup;
    }
    mentionLookup = mentionLookup || Discourse.Mention.lookupCache;

    // Before cooking callbacks
    converter.hooks.chain("preConversion", function(text) {
      _this.trigger('beforeCook', {
        detail: text,
        opts: opts
      });
      return _this.textResult || text;
    });

    // Support autolinking of www.something.com
    converter.hooks.chain("preConversion", function(text) {
      return text.replace(/(^|[\s\n])(www\.[a-z\.\-\_\(\)\/\?\=\%0-9]+)/gim, function(full, _, rest) {
        return " <a href=\"http://" + rest + "\">" + rest + "</a>";
      });
    });

    // newline prediction in trivial cases
    if (!Discourse.SiteSettings.traditional_markdown_linebreaks) {
      converter.hooks.chain("preConversion", function(text) {
        return text.replace(/(^[\w<][^\n]*\n+)/gim, function(t) {
          if (t.match(/\n{2}/gim)) {
            return t;
          }
          return t.replace("\n", "  \n");
        });
      });
    }

    // github style fenced code
    converter.hooks.chain("preConversion", function(text) {
      return text.replace(/^`{3}(?:(.*$)\n)?([\s\S]*?)^`{3}/gm, function(wholeMatch, m1, m2) {
        var escaped;
        escaped = Handlebars.Utils.escapeExpression(m2);
        return "<pre><code class='" + (m1 || 'lang-auto') + "'>" + escaped + "</code></pre>";
      });
    });

    converter.hooks.chain("postConversion", function(text) {
      if (!text) return "";

      // don't to mention voodoo in pres
      text = text.replace(/<pre>([\s\S]*@[\s\S]*)<\/pre>/gi, function(wholeMatch, inner) {
        return "<pre>" + (inner.replace(/@/g, '&#64;')) + "</pre>";
      });

      // Add @mentions of names
      text = text.replace(/([\s\t>,:'|";\]])(@[A-Za-z0-9_-|\.]*[A-Za-z0-9_-|]+)(?=[\s\t<\!:|;',"\?\.])/g, function(x, pre, name) {
        if (mentionLookup(name.substr(1))) {
          return "" + pre + "<a href='/users/" + (name.substr(1).toLowerCase()) + "' class='mention'>" + name + "</a>";
        } else {
          return "" + pre + "<span class='mention'>" + name + "</span>";
        }
      });

      // a primitive attempt at oneboxing, this regex gives me much eye sores
      text = text.replace(/(<li>)?((<p>|<br>)[\s\n\r]*)(<a href=["]([^"]+)[^>]*)>([^<]+<\/a>[\s\n\r]*(?=<\/p>|<br>))/gi, function() {
        // We don't onebox items in a list
        var onebox, url;
        if (arguments[1]) {
          return arguments[0];
        }
        url = arguments[5];
        if (Discourse && Discourse.Onebox) {
          onebox = Discourse.Onebox.lookupCache(url);
        }
        if (onebox && !onebox.isBlank()) {
          return arguments[2] + onebox;
        } else {
          return arguments[2] + arguments[4] + " class=\"onebox\" target=\"_blank\">" + arguments[6];
        }
      });

      return(text);
    });

    converter.hooks.chain("postConversion", function(text) {
      return Discourse.BBCode.format(text, opts);
    });

    if (opts.sanitize) {
      converter.hooks.chain("postConversion", function(text) {
        if (!window.sanitizeHtml) {
          return "";
        }
        return sanitizeHtml(text);
      });
    }
    return converter;
  }

};
RSVP.EventTarget.mixin(Discourse.Markdown);
