/**
  General utility functions

  @class Utilities
  @namespace Discourse
  @module Discourse
**/
Discourse.Utilities = {

  translateSize: function(size) {
    switch (size) {
      case 'tiny': return 20;
      case 'small': return 25;
      case 'medium': return 32;
      case 'large': return 45;
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

  // Create a badge like category link
  categoryLink: function(category) {
    if (!category) return "";

    var color = Em.get(category, 'color');
    var textColor = Em.get(category, 'text_color');
    var name = Em.get(category, 'name');
    var description = Em.get(category, 'description');

    // Build the HTML link
    var result = "<a href=\"" + Discourse.getURL("/category/") + Discourse.Category.slugFor(category) + "\" class=\"badge-category\" ";

    // Add description if we have it
    if (description) result += "title=\"" + Handlebars.Utils.escapeExpression(description) + "\" ";

    return result + "style=\"background-color: #" + color + "; color: #" + textColor + ";\">" + name + "</a>";
  },

  avatarUrl: function(username, size, template) {
    if (!username) return "";
    size = Discourse.Utilities.translateSize(size);
    var rawSize = (size * (window.devicePixelRatio || 1)).toFixed();
    if (template) return template.replace(/\{size\}/g, rawSize);
    return Discourse.getURL("/users/") + (username.toLowerCase()) + "/avatar/" + rawSize + "?__ws=" + (encodeURIComponent(Discourse.BaseUrl || ""));
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
    return Discourse.getURL("/users/" + username);
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
  },

  /**
    Validate a list of files to be uploaded

    @method validateFilesForUpload
    @param {Array} files The list of files we want to upload
  **/
  validateFilesForUpload: function(files) {
    if (files) {
      // can only upload one file at a time
      if (files.length > 1) {
        bootbox.alert(I18n.t('post.errors.too_many_uploads'));
        return false;
      } else if (files.length > 0) {
        var upload = files[0];
        // ensures that new users can upload image
        if (Discourse.User.current('trust_level') === 0 && Discourse.SiteSettings.newuser_max_images === 0) {
          bootbox.alert(I18n.t('post.errors.upload_not_allowed_for_new_user'));
          return false;
        }
        // if the image was pasted, sets its name to a default one
        if (upload instanceof Blob && !(upload instanceof File) && upload.type === "image/png") { upload.name = "blob.png"; }
        // check that the uploaded file is authorized
        if (!Discourse.Utilities.isAuthorizedUpload(upload)) {
          var extensions = Discourse.SiteSettings.authorized_extensions.replace(/\|/g, ", ");
          bootbox.alert(I18n.t('post.errors.upload_not_authorized', { authorized_extensions: extensions }));
          return false;
        }
        // check file size
        if (upload.size && upload.size > 0) {
          var fileSizeInKB = upload.size / 1024;
          if (fileSizeInKB > Discourse.SiteSettings.max_upload_size_kb) {
            bootbox.alert(I18n.t('post.errors.upload_too_large', { max_size_kb: Discourse.SiteSettings.max_upload_size_kb }));
            return false;
          }
          // everything is fine
          return true;
        }
      }
    }
    // there has been an error
    return false;
  },

  /**
    Check the extension of the file against the list of authorized extensions

    @method isAuthorizedUpload
    @param {File} files The file we want to upload
  **/
  isAuthorizedUpload: function(file) {
    var extensions = Discourse.SiteSettings.authorized_extensions;
    if (!extensions) return false;
    var regexp = new RegExp("\\.(" + extensions.replace(/\./g, "") + ")$", "i");
    return file && file.name ? file.name.match(regexp) : false;
  },

  /**
    Get the markdown template for an upload (either an image or an attachment)

    @method getUploadMarkdown
    @param {Upload} upload The upload we want the markdown from
  **/
  getUploadMarkdown: function(upload) {
    if (this.isAnImage(upload.original_filename)) {
      return '<img src="' + upload.url + '" width="' + upload.width + '" height="' + upload.height + '">';
    } else {
      return '<a class="attachment" href="' + upload.url + '">' + upload.original_filename + '</a><span class="size">(' + I18n.toHumanSize(upload.filesize) + ')</span>';
    }
  },

  /**
    Check whether the path is refering to an image

    @method isAnImage
    @param {String} path The path
  **/
  isAnImage: function(path) {
    return path && path.match(/\.(png|jpg|jpeg|gif|bmp|tif)$/i);
  }

};
