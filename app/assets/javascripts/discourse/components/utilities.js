/*global sanitizeHtml:true Markdown:true */

(function() {
  var baseUrl, site;

  baseUrl = null;

  site = null;

  Discourse.Utilities = {
    translateSize: function(size) {
      switch (size) {
        case 'tiny':
          size = 20;
          break;
        case 'small':
          size = 25;
          break;
        case 'medium':
          size = 32;
          break;
        case 'large':
          size = 45;
      }
      return size;
    },
    categoryUrlId: function(category) {
      var id, slug;
      if (!category) {
        return "";
      }
      id = Em.get(category, 'id');
      slug = Em.get(category, 'slug');
      if ((!slug) || slug.isBlank()) {
        return "" + id + "-category";
      }
      return slug;
    },
    /* Create a badge like category link
    */

    categoryLink: function(category) {
      var color, name;
      if (!category) {
        return "";
      }
      color = Em.get(category, 'color');
      name = Em.get(category, 'name');
      return "<a href=\"/category/" + 
             (this.categoryUrlId(category)) + 
             "\" class=\"badge-category excerptable\" data-excerpt-size=\"medium\" style=\"background-color: #" + color + "\">" + 
             name + "</a>";
    },
    avatarUrl: function(username, size, template) {
      var rawSize;
      if (!username) {
        return "";
      }
      size = Discourse.Utilities.translateSize(size);
      rawSize = (size * (window.devicePixelRatio || 1)).toFixed();
      if (template) {
        return template.replace(/\{size\}/g, rawSize);
      }
      return "/users/" + (username.toLowerCase()) + "/avatar/" + rawSize + "?__ws=" + (encodeURIComponent(Discourse.BaseUrl || ""));
    },
    avatarImg: function(options) {
      var extraClasses, size, title, url;
      size = Discourse.Utilities.translateSize(options.size);
      title = options.title || "";
      extraClasses = options.extraClasses || "";
      url = Discourse.Utilities.avatarUrl(options.username, options.size, options.avatarTemplate);
      return "<img width='" + size + "' height='" + size + "' src='" + url + "' class='avatar " + 
              (extraClasses || "") + "' title='" + (Handlebars.Utils.escapeExpression(title || "")) + "'>";
    },
    postUrl: function(slug, topicId, postNumber) {
      var url;
      url = "/t/";
      if (slug) {
        url += slug + "/";
      }
      url += topicId;
      if (postNumber > 1) {
        url += "/" + postNumber;
      }
      return url;
    },
    emailValid: function(email) {
      /* see:  http://stackoverflow.com/questions/46155/validate-email-address-in-javascript
      */

      var re;
      re = /^[a-zA-Z0-9!#$%&'*+\/=?\^_`{|}~\-]+(?:\.[a-zA-Z0-9!#$%&'\*+\/=?\^_`{|}~\-]+)*@(?:[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?\.)+[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?$/;
      return re.test(email);
    },
    selectedText: function() {
      var t;
      t = '';
      if (window.getSelection) {
        t = window.getSelection().toString();
      } else if (document.getSelection) {
        t = document.getSelection().toString();
      } else if (document.selection) {
        t = document.selection.createRange().text;
      }
      return String(t).trim();
    },
    /* Determine the position of the caret in an element
    */

    caretPosition: function(el) {
      var r, rc, re;
      if (el.selectionStart) {
        return el.selectionStart;
      }
      if (document.selection) {
        el.focus();
        r = document.selection.createRange();
        if (!r) return 0;
        
        re = el.createTextRange();
        rc = re.duplicate();
        re.moveToBookmark(r.getBookmark());
        rc.setEndPoint('EndToStart', re);
        return rc.text.length;
      }
      return 0;
    },
    /* Set the caret's position
    */

    setCaretPosition: function(ctrl, pos) {
      var range;
      if (ctrl.setSelectionRange) {
        ctrl.focus();
        ctrl.setSelectionRange(pos, pos);
        return;
      }
      if (ctrl.createTextRange) {
        range = ctrl.createTextRange();
        range.collapse(true);
        range.moveEnd('character', pos);
        range.moveStart('character', pos);
        return range.select();
      }
    },
    markdownConverter: function(opts) {
      var converter, mentionLookup,
        _this = this;
      converter = new Markdown.Converter();
      if (opts) {
        mentionLookup = opts.mentionLookup;
      }
      mentionLookup = mentionLookup || Discourse.Mention.lookupCache;
      /* Before cooking callbacks
      */

      converter.hooks.chain("preConversion", function(text) {
        _this.trigger('beforeCook', {
          detail: text,
          opts: opts
        });
        return _this.textResult || text;
      });
      /* Support autolinking of www.something.com
      */

      converter.hooks.chain("preConversion", function(text) {
        return text.replace(/(^|[\s\n])(www\.[a-z\.\-\_\(\)\/\?\=\%0-9]+)/gim, function(full, _, rest) {
          return " <a href=\"http://" + rest + "\">" + rest + "</a>";
        });
      });
      /* newline prediction in trivial cases
      */

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
      /* github style fenced code
      */

      converter.hooks.chain("preConversion", function(text) {
        return text.replace(/^`{3}(?:(.*$)\n)?([\s\S]*?)^`{3}/gm, function(wholeMatch, m1, m2) {
          var escaped;
          escaped = Handlebars.Utils.escapeExpression(m2);
          return "<pre><code class='" + (m1 || 'lang-auto') + "'>" + escaped + "</code></pre>";
        });
      });
      converter.hooks.chain("postConversion", function(text) {
        if (!text) {
          return "";
        }
        /* don't to mention voodoo in pres
        */

        text = text.replace(/<pre>([\s\S]*@[\s\S]*)<\/pre>/gi, function(wholeMatch, inner) {
          return "<pre>" + (inner.replace(/@/g, '&#64;')) + "</pre>";
        });
        /* Add @mentions of names
        */

        text = text.replace(/([\s\t>,:'|";\]])(@[A-Za-z0-9_-|\.]*[A-Za-z0-9_-|]+)(?=[\s\t<\!:|;',"\?\.])/g, function(x, pre, name) {
          if (mentionLookup(name.substr(1))) {
            return "" + pre + "<a href='/users/" + (name.substr(1).toLowerCase()) + "' class='mention'>" + name + "</a>";
          } else {
            return "" + pre + "<span class='mention'>" + name + "</span>";
          }
        });
        /* a primitive attempt at oneboxing, this regex gives me much eye sores
        */

        text = text.replace(/(<li>)?((<p>|<br>)[\s\n\r]*)(<a href=["]([^"]+)[^>]*)>([^<]+<\/a>[\s\n\r]*(?=<\/p>|<br>))/gi, function() {
          /* We don't onebox items in a list
          */

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
    },
    /* Takes raw input and cooks it to display nicely (mostly markdown)
    */

    cook: function(raw, opts) {
      if (!opts) opts = {};
      
      // Make sure we've got a string
      if (!raw) return "";
      
      if (raw.length === 0) return "";
      
      this.converter = this.markdownConverter(opts);
      return this.converter.makeHtml(raw);
    }
  };

  RSVP.EventTarget.mixin(Discourse.Utilities);

}).call(this);
