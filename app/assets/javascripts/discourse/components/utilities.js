/**
  General utility functions

  @class Utilities
  @namespace Discourse
  @module Discourse
**/
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

  // Create a badge like category link
  categoryLink: function(category) {
    var color, textColor, name, description, result;
    if (!category) return "";

    color = Em.get(category, 'color');
    textColor = Em.get(category, 'text_color');
    name = Em.get(category, 'name');
    description = Em.get(category, 'description');

    // Build the HTML link
    result = "<a href=\"" + Discourse.getURL("/category/") + this.categoryUrlId(category) + "\" class=\"badge-category\" ";

    // Add description if we have it
    if (description) result += "title=\"" + description + "\" ";

    return result + "style=\"background-color: #" + color + "; color: #" + textColor + ";\">" + name + "</a>";
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

  tinyAvatar: function(username) {
    return Discourse.Utilities.avatarImg({ username: username, size: 'tiny' });
  },

  postUrl: function(slug, topicId, postNumber) {
    var url;
    url = Discourse.getURL("/t/");
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
   // see:  http://stackoverflow.com/questions/46155/validate-email-address-in-javascript
   var re;
    re = /^[a-zA-Z0-9!#$%&'*+\/=?\^_`{|}~\-]+(?:\.[a-zA-Z0-9!#$%&'\*+\/=?\^_`{|}~\-]+)*@(?:[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?\.)+[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?$/;
    return re.test(email);
  },

  selectedText: function() {
    var html = '';

    if (typeof window.getSelection !== "undefined") {
        var sel = window.getSelection();
        if (sel.rangeCount) {
            var container = document.createElement("div");
            for (var i = 0, len = sel.rangeCount; i < len; ++i) {
                container.appendChild(sel.getRangeAt(i).cloneContents());
            }
            html = container.innerHTML;
        }
    } else if (typeof document.selection !== "undefined") {
        if (document.selection.type === "Text") {
            html = document.selection.createRange().htmlText;
        }
    }

    // Strip out any .click elements from the HTML before converting it to text
    var div = document.createElement('div');
    div.innerHTML = html;
    $('.clicks', $(div)).remove();
    var text = div.textContent || div.innerText || "";

    return String(text).trim();
  },

  // Determine the position of the caret in an element
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

  // Set the caret's position
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
  }

};
