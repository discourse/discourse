
var discourseEscape = {
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  '"': "&quot;",
  "'": "&#x27;",
  '`': '&#x60;'
};
var discourseBadChars = /[&<>"'`]/g;
var discoursePossible = /[&<>"'`]/;

function discourseEscapeChar(chr) {
  return discourseEscape[chr];
}
Discourse.Utilities = {

  translateSize: function(size) {
    switch (size) {
      case 'tiny': return 20;
      case 'small': return 25;
      case 'medium': return 32;
      case 'large': return 45;
      case 'extra_large': return 60;
      case 'huge': return 120;
    }
    return size;
  },

  /**
    Allows us to supply bindings without "binding" to a helper.
  **/
  normalizeHash: function(hash, hashTypes) {
    for (var prop in hash) {
      if (hashTypes[prop] === 'ID') {
        hash[prop + 'Binding'] = hash[prop];
        delete hash[prop];
      }
    }
  },

  // Handlebars no longer allows spaces in its `escapeExpression` code which makes it
  // unsuitable for many of Discourse's uses. Use `Handlebars.Utils.escapeExpression`
  // when escaping an attribute in HTML, otherwise this one will do.
  escapeExpression: function(string) {
    // don't escape SafeStrings, since they're already safe
    if (string instanceof Handlebars.SafeString) {
      return string.toString();
    } else if (string == null) {
      return "";
    } else if (!string) {
      return string + '';
    }

    // Force a string conversion as this will be done by the append regardless and
    // the regex test will do this transparently behind the scenes, causing issues if
    // an object's to string has escaped characters in it.
    string = "" + string;

    if(!discoursePossible.test(string)) { return string; }
    return string.replace(discourseBadChars, discourseEscapeChar);
  },

  avatarUrl: function(template, size) {
    if (!template) { return ""; }
    var rawSize = Discourse.Utilities.getRawSize(Discourse.Utilities.translateSize(size));
    return template.replace(/\{size\}/g, rawSize);
  },

  getRawSize: function(size) {
    var pixelRatio = window.devicePixelRatio || 1;
    return size * Math.min(3, Math.max(1, Math.round(pixelRatio)));
  },

  avatarImg: function(options) {
    var size = Discourse.Utilities.translateSize(options.size);
    var url = Discourse.Utilities.avatarUrl(options.avatarTemplate, size);

    // We won't render an invalid url
    if (!url || url.length === 0) { return ""; }

    var classes = "avatar" + (options.extraClasses ? " " + options.extraClasses : "");
    var title = (options.title) ? " title='" + Handlebars.Utils.escapeExpression(options.title || "") + "'" : "";

    return "<img alt='' width='" + size + "' height='" + size + "' src='" + Discourse.getURLWithCDN(url) + "' class='" + classes + "'" + title + ">";
  },

  tinyAvatar: function(avatarTemplate, options) {
    return Discourse.Utilities.avatarImg(_.merge({avatarTemplate: avatarTemplate, size: 'tiny' }, options));
  },

  postUrl: function(slug, topicId, postNumber) {
    var url = Discourse.getURL("/t/");
    if (slug) {
      url += slug + "/";
    } else {
      url += 'topic/';
    }
    url += topicId;
    if (postNumber > 1) {
      url += "/" + postNumber;
    }
    return url;
  },

  userUrl: function(username) {
    return Discourse.getURL("/users/" + username.toLowerCase());
  },

  emailValid: function(email) {
    // see:  http://stackoverflow.com/questions/46155/validate-email-address-in-javascript
    var re = /^[a-zA-Z0-9!#$%&'*+\/=?\^_`{|}~\-]+(?:\.[a-zA-Z0-9!#$%&'\*+\/=?\^_`{|}~\-]+)*@(?:[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?\.)+[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?$/;
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
    var $div = $(div);
    // Find all emojis and replace with its title attribute.
    $div.find('img.emoji').replaceWith(function() { return this.title; });
    $('.clicks', $div).remove();
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
  },

  validateUploadedFiles: function(files, bypassNewUserRestriction) {
    if (!files || files.length === 0) { return false; }

    if (files.length > 1) {
      bootbox.alert(I18n.t('post.errors.too_many_uploads'));
      return false;
    }

    var upload = files[0];

    // CHROME ONLY: if the image was pasted, sets its name to a default one
    if (typeof Blob !== "undefined" && typeof File !== "undefined") {
      if (upload instanceof Blob && !(upload instanceof File) && upload.type === "image/png") { upload.name = "blob.png"; }
    }

    var type = Discourse.Utilities.isAnImage(upload.name) ? 'image' : 'attachment';

    return Discourse.Utilities.validateUploadedFile(upload, type, bypassNewUserRestriction);
  },

  validateUploadedFile: function(file, type, bypassNewUserRestriction) {
    // check that the uploaded file is authorized
    if (!Discourse.Utilities.authorizesAllExtensions() &&
        !Discourse.Utilities.isAuthorizedUpload(file)) {
      var extensions = Discourse.Utilities.authorizedExtensions();
      bootbox.alert(I18n.t('post.errors.upload_not_authorized', { authorized_extensions: extensions }));
      return false;
    }

    if (!bypassNewUserRestriction) {
      // ensures that new users can upload a file
      if (!Discourse.User.current().isAllowedToUploadAFile(type)) {
        bootbox.alert(I18n.t('post.errors.' + type + '_upload_not_allowed_for_new_user'));
        return false;
      }
    }

    // everything went fine
    return true;
  },

  authorizesAllExtensions: function() {
    return Discourse.SiteSettings.authorized_extensions.indexOf("*") >= 0;
  },

  isAuthorizedUpload: function(file) {
    if (file && file.name) {
      var extensions = _.chain(Discourse.SiteSettings.authorized_extensions.split("|"))
                        .reject(function(extension) { return extension.indexOf("*") >= 0; })
                        .map(function(extension) { return (extension.indexOf(".") === 0 ? extension.substring(1) : extension).replace(".", "\\."); })
                        .value();
      return new RegExp("\\.(" + extensions.join("|") + ")$", "i").test(file.name);
    }
    return false;
  },

  authorizedExtensions: function() {
    return _.chain(Discourse.SiteSettings.authorized_extensions.split("|"))
            .reject(function(extension) { return extension.indexOf("*") >= 0; })
            .map(function(extension) { return extension.toLowerCase(); })
            .value()
            .join(", ");
  },

  getUploadMarkdown: function(upload) {
    if (Discourse.Utilities.isAnImage(upload.original_filename)) {
      return '<img src="' + upload.url + '" width="' + upload.width + '" height="' + upload.height + '">';
    } else {
      return '<a class="attachment" href="' + upload.url + '">' + upload.original_filename + '</a> (' + I18n.toHumanSize(upload.filesize) + ')';
    }
  },

  getUploadPlaceholder: function() {
    return "[" + I18n.t("uploading") + "]() ";
  },

  isAnImage: function(path) {
    return (/\.(png|jpe?g|gif|bmp|tiff?|svg|webp)$/i).test(path);
  },

  allowsImages: function() {
    return Discourse.Utilities.authorizesAllExtensions() ||
           (/(png|jpe?g|gif|bmp|tiff?|svg|webp)/i).test(Discourse.Utilities.authorizedExtensions());
  },

  allowsAttachments: function() {
    return Discourse.Utilities.authorizesAllExtensions() ||
           !(/((png|jpe?g|gif|bmp|tiff?|svg|webp)(,\s)?)+$/i).test(Discourse.Utilities.authorizedExtensions());
  },

  displayErrorForUpload: function(data) {
    // deal with meaningful errors first
    if (data.jqXHR) {
      switch (data.jqXHR.status) {
        // cancelled by the user
        case 0: return;

        // entity too large, usually returned from the web server
        case 413:
          var maxSizeKB = 10 * 1024; // 10 MB
          bootbox.alert(I18n.t('post.errors.file_too_large', { max_size_kb: maxSizeKB }));
          return;

        // the error message is provided by the server
        case 422:
          if (data.jqXHR.responseJSON.message) {
            bootbox.alert(data.jqXHR.responseJSON.message);
          } else {
            bootbox.alert(data.jqXHR.responseJSON.join("\n"));
          }
          return;
      }
    } else if (data.errors && data.errors.length > 0) {
      bootbox.alert(data.errors.join("\n"));
      return;
    }
    // otherwise, display a generic error message
    bootbox.alert(I18n.t('post.errors.upload'));
  },

  defaultHomepage: function() {
    // the homepage is the first item of the 'top_menu' site setting
    return Discourse.SiteSettings.top_menu.split("|")[0].split(",")[0];
  }

};
