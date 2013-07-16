/*global HANDLEBARS_TEMPLATES:true md5:true*/

/**
  Support for BBCode rendering

  @class BBCode
  @namespace Discourse
  @module Discourse
**/
Discourse.BBCode = {

  QUOTE_REGEXP: /\[quote=([^\]]*)\]((?:[\s\S](?!\[quote=[^\]]*\]))*?)\[\/quote\]/im,
  IMG_REGEXP: /\[img\]([\s\S]*?)\[\/img\]/i,
  URL_REGEXP: /\[url\]([\s\S]*?)\[\/url\]/i,
  URL_WITH_TITLE_REGEXP: /\[url=(.+?)\]([\s\S]*?)\[\/url\]/i,

  // Define our replacers
  replacers: {
    base: {
      withoutArgs: {
        "ol": function(_, content) { return "<ol>" + content + "</ol>"; },
        "li": function(_, content) { return "<li>" + content + "</li>"; },
        "ul": function(_, content) { return "<ul>" + content + "</ul>"; },
        "code": function(_, content) { return "<pre>" + content + "</pre>"; },
        "url": function(_, url) { return "<a href=\"" + url + "\">" + url + "</a>"; },
        "email": function(_, address) { return "<a href=\"mailto:" + address + "\">" + address + "</a>"; },
        "img": function(_, src) { return "<img src=\"" + src + "\">"; }
      },
      withArgs: {
        "url": function(_, href, title) { return "<a href=\"" + href + "\">" + title + "</a>"; },
        "email": function(_, address, title) { return "<a href=\"mailto:" + address + "\">" + title + "</a>"; },
        "color": function(_, color, content) {
          if (!/^(\#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?)|(aqua|black|blue|fuchsia|gray|green|lime|maroon|navy|olive|purple|red|silver|teal|white|yellow)$/.test(color)) {
            return content;
          }
          return "<span style=\"color: " + color + "\">" + content + "</span>";
        }
      }
    },

    // For HTML emails
    email: {
      withoutArgs: {
        "b": function(_, content) { return "<b>" + content + "</b>"; },
        "i": function(_, content) { return "<i>" + content + "</i>"; },
        "u": function(_, content) { return "<u>" + content + "</u>"; },
        "s": function(_, content) { return "<s>" + content + "</s>"; },
        "spoiler": function(_, content) { return "<span style='background-color: #000'>" + content + "</span>"; }
      },
      withArgs: {
        "size": function(_, size, content) { return "<span style=\"font-size: " + size + "px\">" + content + "</span>"; }
      }
    },

    // For sane environments that support CSS
    "default": {
      withoutArgs: {
        "b": function(_, content) { return "<span class='bbcode-b'>" + content + "</span>"; },
        "i": function(_, content) { return "<span class='bbcode-i'>" + content + "</span>"; },
        "u": function(_, content) { return "<span class='bbcode-u'>" + content + "</span>"; },
        "s": function(_, content) { return "<span class='bbcode-s'>" + content + "</span>"; },
        "spoiler": function(_, content) { return "<span class=\"spoiler\">" + content + "</span>";
        }
      },
      withArgs: {
        "size": function(_, size, content) { return "<span class=\"bbcode-size-" + size + "\">" + content + "</span>"; }
      }
    }
  },

  /**
    Apply a particular set of replacers

    @method apply
    @param {String} text The text we want to format
    @param {String} environment The environment in which this
  **/
  apply: function(text, environment) {
    var replacer = Discourse.BBCode.parsedReplacers()[environment];
    // apply all available replacers
    replacer.forEach(function(r) {
      text = text.replace(r.regexp, r.fn);
    });
    return text;
  },

  /**
    Lazy parse replacers

    @property parsedReplacers
  **/
  parsedReplacers: function() {
    if (this.parsed) return this.parsed;

    var result = {};

    _.each(Discourse.BBCode.replacers, function(rules, name) {

      var parsed = result[name] = [];

      _.each(_.extend(Discourse.BBCode.replacers.base.withoutArgs, rules.withoutArgs), function(val, tag) {
        parsed.push({ regexp: new RegExp("\\[" + tag + "\\]([\\s\\S]*?)\\[\\/" + tag + "\\]", "igm"), fn: val });
      });

      _.each(_.extend(Discourse.BBCode.replacers.base.withArgs, rules.withArgs), function(val, tag) {
        parsed.push({ regexp: new RegExp("\\[" + tag + "=?(.+?)\\]([\\s\\S]*?)\\[\\/" + tag + "\\]", "igm"), fn: val });
      });

    });

    this.parsed = result;
    return this.parsed;
  },

  /**
    Build the BBCode quote around the selected text

    @method buildQuoteBBCode
    @param {Discourse.Post} post The post we are quoting
    @param {String} contents The text selected
  **/
  buildQuoteBBCode: function(post, contents) {
    var contents_hashed, result, sansQuotes, stripped, stripped_hashed, tmp;
    if (!contents) contents = "";

    sansQuotes = contents.replace(this.QUOTE_REGEXP, '').trim();
    if (sansQuotes.length === 0) return "";

    result = "[quote=\"" + (post.get('username')) + ", post:" + (post.get('post_number')) + ", topic:" + (post.get('topic_id'));

    /* Strip the HTML from cooked */
    tmp = document.createElement('div');
    tmp.innerHTML = post.get('cooked');
    stripped = tmp.textContent || tmp.innerText;

    /*
      Let's remove any non alphanumeric characters as a kind of hash. Yes it's
      not accurate but it should work almost every time we need it to. It would be unlikely
      that the user would quote another post that matches in exactly this way.
    */
    stripped_hashed = stripped.replace(/[^a-zA-Z0-9]/g, '');
    contents_hashed = contents.replace(/[^a-zA-Z0-9]/g, '');

    /* If the quote is the full message, attribute it as such */
    if (stripped_hashed === contents_hashed) result += ", full:true";
    result += "\"]\n" + sansQuotes + "\n[/quote]\n\n";

    return result;
  },

  /**
    We want to remove urls in BBCode tags from a string before applying markdown
    to prevent them from being modified by markdown.
    This will return an object that contains:
      - a new version of the text with the urls replaced with unique ids
      - a `template()` function for reapplying them later.

    @method extractUrls
    @param {String} text The text inside which we want to replace urls
    @returns {Object} object containing the new string and template function
  **/
  extractUrls: function(text) {
    var result = { text: "" + text, replacements: [] };
    var replacements = [];
    var matches, key;

    _.each([Discourse.BBCode.IMG_REGEXP, Discourse.BBCode.URL_REGEXP, Discourse.BBCode.URL_WITH_TITLE_REGEXP], function(r) {
      while (matches = r.exec(result.text)) {
        key = md5(matches[0]);
        replacements.push({ key: key, value: matches[0] });
        result.text = result.text.replace(matches[0], key);
      }
    });

    result.template = function(input) {
      _.each(replacements, function(r) {
        input = input.replace(r.key, r.value);
      });
      return input;
    };

    return (result);
  },


  /**
    We want to remove quotes from a string before applying markdown to avoid
    weird stuff with newlines and such. This will return an object that
    contains a new version of the text with the quotes replaced with
    unique ids and `template()` function for reapplying them later.

    @method extractQuotes
    @param {String} text The text inside which we want to replace quotes
    @returns {Object} object containing the new string and template function
  **/
  extractQuotes: function(text) {
    var result = { text: "" + text, replacements: [] };
    var replacements = [];
    var matches, key;

    while (matches = Discourse.BBCode.QUOTE_REGEXP.exec(result.text)) {
      key = md5(matches[0]);
      replacements.push({
        key: key,
        value: matches[0],
        content: matches[2].trim()
      });
      result.text = result.text.replace(matches[0], key + "\n");
    }

    result.template = function(input) {
      _.each(replacements,function(r) {
        var val = r.value.trim();
        val = val.replace(r.content, r.content.replace(/\n/g, '<br>'));
        input = input.replace(r.key, val);
      });
      return input;
    };

    return (result);
  },

  /**
    Replace quotes with appropriate markup

    @method formatQuote
    @param {String} text The text inside which we want to replace quotes
    @param {Object} opts Rendering options
  **/
  formatQuote: function(text, opts) {
    var args, matches, params, paramsSplit, paramsString, templateName, username;

    var splitter = function(p,i) {
      if (i > 0) {
        var assignment = p.split(':');
        if (assignment[0] && assignment[1]) {
          return params.push({
            key: assignment[0],
            value: assignment[1].trim()
          });
        }
      }
    };

    while (matches = this.QUOTE_REGEXP.exec(text)) {
      paramsString = matches[1].replace(/\"/g, '');
      paramsSplit = paramsString.split(/\, */);
      params = [];
      _.each(paramsSplit, splitter);
      username = paramsSplit[0];

      // remove leading <br>s
      var content = matches[2].trim();

      // Arguments for formatting
      args = {
        username: I18n.t('user.said',{username: username}),
        params: params,
        quote: content,
        avatarImg: opts.lookupAvatar ? opts.lookupAvatar(username) : void 0
      };

      // Name of the template
      templateName = 'quote';
      if (opts && opts.environment) templateName = "quote_" + opts.environment;
      // Apply the template
      text = text.replace(matches[0], "</p>" + HANDLEBARS_TEMPLATES[templateName](args) + "<p>");
    }
    return text;
  },

  /**
    Format a text string using BBCode

    @method format
    @param {String} text The text we want to format
    @param {Object} opts Rendering options
  **/
  format: function(text, opts) {
    var environment = opts && opts.environment ? opts.environment : 'default';
    // Apply replacers for basic tags
    text = Discourse.BBCode.apply(text, environment);
    // Format
    text = Discourse.BBCode.formatQuote(text, opts);
    return text;
  }
};
