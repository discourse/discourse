/*global HANDLEBARS_TEMPLATES:true*/

(function() {

  Discourse.BBCode = {
    QUOTE_REGEXP: /\[quote=([^\]]*)\]([\s\S]*?)\[\/quote\]/im,
    /* Define our replacers
    */

    replacers: {
      base: {
        withoutArgs: {
          "ol": function(_, content) {
            return "<ol>" + content + "</ol>";
          },
          "li": function(_, content) {
            return "<li>" + content + "</li>";
          },
          "ul": function(_, content) {
            return "<ul>" + content + "</ul>";
          },
          "code": function(_, content) {
            return "<pre>" + content + "</pre>";
          },
          "url": function(_, url) {
            return "<a href=\"" + url + "\">" + url + "</a>";
          },
          "email": function(_, address) {
            return "<a href=\"mailto:" + address + "\">" + address + "</a>";
          },
          "img": function(_, src) {
            return "<img src=\"" + src + "\">";
          }
        },
        withArgs: {
          "url": function(_, href, title) {
            return "<a href=\"" + href + "\">" + title + "</a>";
          },
          "email": function(_, address, title) {
            return "<a href=\"mailto:" + address + "\">" + title + "</a>";
          },
          "color": function(_, color, content) {
            if (!/^(\#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?)|(aqua|black|blue|fuchsia|gray|green|lime|maroon|navy|olive|purple|red|silver|teal|white|yellow)$/.test(color)) {
              return content;
            }
            return "<span style=\"color: " + color + "\">" + content + "</span>";
          }
        }
      },
      /* For HTML emails
      */

      email: {
        withoutArgs: {
          "b": function(_, content) {
            return "<b>" + content + "</b>";
          },
          "i": function(_, content) {
            return "<i>" + content + "</i>";
          },
          "u": function(_, content) {
            return "<u>" + content + "</u>";
          },
          "s": function(_, content) {
            return "<s>" + content + "</s>";
          },
          "spoiler": function(_, content) {
            return "<span style='background-color: #000'>" + content + "</span>";
          }
        },
        withArgs: {
          "size": function(_, size, content) {
            return "<span style=\"font-size: " + size + "px\">" + content + "</span>";
          }
        }
      },
      /* For sane environments that support CSS
      */

      "default": {
        withoutArgs: {
          "b": function(_, content) {
            return "<span class='bbcode-b'>" + content + "</span>";
          },
          "i": function(_, content) {
            return "<span class='bbcode-i'>" + content + "</span>";
          },
          "u": function(_, content) {
            return "<span class='bbcode-u'>" + content + "</span>";
          },
          "s": function(_, content) {
            return "<span class='bbcode-s'>" + content + "</span>";
          },
          "spoiler": function(_, content) {
            return "<span class=\"spoiler\">" + content + "</span>";
          }
        },
        withArgs: {
          "size": function(_, size, content) {
            return "<span class=\"bbcode-size-" + size + "\">" + content + "</span>";
          }
        }
      }
    },

    /* Apply a particular set of replacers */
    apply: function(text, environment) {
      var replacer;
      replacer = Discourse.BBCode.parsedReplacers()[environment];

      replacer.forEach(function(r) {
        text = text.replace(r.regexp, r.fn);
      });
      return text;
    },

    parsedReplacers: function() {
      var result;
      if (this.parsed) {
        return this.parsed;
      }
      result = {};
      Object.keys(Discourse.BBCode.replacers, function(name, rules) {
        var parsed;
        parsed = result[name] = [];
        Object.keys(Object.merge(Discourse.BBCode.replacers.base.withoutArgs, rules.withoutArgs), function(tag, val) {
          return parsed.push({
            regexp: new RegExp("\\[" + tag + "\\]([\\s\\S]*?)\\[\\/" + tag + "\\]", "igm"),
            fn: val
          });
        });
        return Object.keys(Object.merge(Discourse.BBCode.replacers.base.withArgs, rules.withArgs), function(tag, val) {
          return parsed.push({
            regexp: new RegExp("\\[" + tag + "=?(.+?)\\]([\\s\\S]*?)\\[\\/" + tag + "\\]", "igm"),
            fn: val
          });
        });
      });
      this.parsed = result;
      return this.parsed;
    },

    buildQuoteBBCode: function(post, contents) {
      var contents_hashed, result, sansQuotes, stripped, stripped_hashed, tmp;
      if (!contents) contents = "";

      sansQuotes = contents.replace(this.QUOTE_REGEXP, '').trim();
      if (sansQuotes.length === 0) return "";

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
      result = "[quote=\"" + (post.get('username')) + ", post:" + (post.get('post_number')) + ", topic:" + (post.get('topic_id'));

      /* If the quote is the full message, attribute it as such */
      if (stripped_hashed === contents_hashed) {
        result += ", full:true";
      }
      result += "\"]\n" + sansQuotes + "\n[/quote]\n\n";
      return result;
    },

    formatQuote: function(text, opts) {

      /* Replace quotes with appropriate markup */
      var args, matches, params, paramsSplit, paramsString, templateName, username;
      while (matches = this.QUOTE_REGEXP.exec(text)) {
        paramsString = matches[1];
        paramsString = paramsString.replace(/\"/g, '');
        paramsSplit = paramsString.split(/\, */);
        params = [];
        paramsSplit.each(function(p, i) {
          var assignment;
          if (i > 0) {
            assignment = p.split(':');
            if (assignment[0] && assignment[1]) {
              return params.push({
                key: assignment[0],
                value: assignment[1].trim()
              });
            }
          }
        });
        username = paramsSplit[0];

        /* Arguments for formatting */
        args = {
          username: username,
          params: params,
          quote: matches[2].trim(),
          avatarImg: opts.lookupAvatar ? opts.lookupAvatar(username) : void 0
        };
        templateName = 'quote';
        if (opts && opts.environment) {
          templateName = "quote_" + opts.environment;
        }
        text = text.replace(matches[0], "</p>" + HANDLEBARS_TEMPLATES[templateName](args) + "<p>");
      }
      return text;
    },
    format: function(text, opts) {
      var environment;
      if (opts && opts.environment) environment = opts.environment;
      if (!environment) environment = 'default';

      text = Discourse.BBCode.apply(text, environment);
      // Add quotes
      text = Discourse.BBCode.formatQuote(text, opts);
      return text;
    }
  };

}).call(this);
