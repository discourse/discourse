/**
  General utility functions

  @class Utilities
  @namespace Discourse
  @module Discourse
**/
Discourse.Utilities = {

  IMAGE_EXTENSIONS: [".png", ".jpg", ".jpeg", ".gif", ".bmp", ".tif", ".tiff"],
  IS_AN_IMAGE_REGEXP: /\.(png|jpg|jpeg|gif|bmp|tif|tiff)$/i,

  translateSize: function(size) {
    switch (size) {
      case 'tiny': return 20;
      case 'small': return 25;
      case 'medium': return 32;
      case 'large': return 45;
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

  avatarUrl: function(template, size) {
    if (!template) { return ""; }
    var rawSize = Discourse.Utilities.getRawSize(Discourse.Utilities.translateSize(size));
    return template.replace(/\{size\}/g, rawSize);
  },

  getRawSize: function(size) {
    var pixelRatio = window.devicePixelRatio || 1;
    return pixelRatio >= 1.5 ? size * 2 : size;
  },

  avatarImg: function(options) {
    var size = Discourse.Utilities.translateSize(options.size);
    var url = Discourse.Utilities.avatarUrl(options.avatarTemplate, size);

    // We won't render an invalid url
    if (!url || url.length === 0) { return ""; }

    var classes = "avatar" + (options.extraClasses ? " " + options.extraClasses : "");
    var title = (options.title) ? " title='" + Handlebars.Utils.escapeExpression(options.title || "") + "'" : "";
    return "<img width='" + size + "' height='" + size + "' src='" + url + "' class='" + classes + "'" + title + ">";
  },

  tinyAvatar: function(avatarTemplate) {
    return Discourse.Utilities.avatarImg({avatarTemplate: avatarTemplate, size: 'tiny' });
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

    @method validateUploadedFiles
    @param {Array} files The list of files we want to upload
  **/
  validateUploadedFiles: function(files) {
    if (!files || files.length === 0) { return false; }

    // can only upload one file at a time
    if (files.length > 1) {
      bootbox.alert(I18n.t('post.errors.too_many_uploads'));
      return false;
    }

    var upload = files[0];

    // CHROME ONLY: if the image was pasted, sets its name to a default one
    if (upload instanceof Blob && !(upload instanceof File) && upload.type === "image/png") { upload.name = "blob.png"; }

    return Discourse.Utilities.validateUploadedFile(upload, Discourse.Utilities.isAnImage(upload.name) ? 'image' : 'attachment');
  },

  /**
    Validate a file to be uploaded

    @method validateUploadedFile
    @param {File} file The file to be uploaded
    @param {string} type The type of the upload (image, attachment)
    @returns true whenever the upload is valid
  **/
  validateUploadedFile: function(file, type) {
    // check that the uploaded file is authorized
    if (!Discourse.Utilities.isAuthorizedUpload(file)) {
      var extensions = Discourse.Utilities.authorizedExtensions();
      bootbox.alert(I18n.t('post.errors.upload_not_authorized', { authorized_extensions: extensions }));
      return false;
    }

    // ensures that new users can upload a file
    if (!Discourse.User.current().isAllowedToUploadAFile(type)) {
      bootbox.alert(I18n.t('post.errors.' + type + '_upload_not_allowed_for_new_user'));
      return false;
    }

    // check file size
    var fileSizeKB = file.size / 1024;
    var maxSizeKB = Discourse.SiteSettings['max_' + type + '_size_kb'];
    if (fileSizeKB > maxSizeKB) {
      bootbox.alert(I18n.t('post.errors.' + type + '_too_large', { max_size_kb: maxSizeKB }));
      return false;
    }

    // everything went fine
    return true;
  },

  /**
    Check the extension of the file against the list of authorized extensions

    @method isAuthorizedUpload
    @param {File} files The file we want to upload
  **/
  isAuthorizedUpload: function(file) {
    var extensions = Discourse.SiteSettings.authorized_extensions;
    var regexp = new RegExp("(" + extensions + ")$", "i");
    return file && file.name ? file.name.match(regexp) : false;
  },

  /**
    Get the markdown template for an upload (either an image or an attachment)

    @method getUploadMarkdown
    @param {Upload} upload The upload we want the markdown from
  **/
  getUploadMarkdown: function(upload) {
    if (Discourse.Utilities.isAnImage(upload.original_filename)) {
      return '<img src="' + upload.url + '" width="' + upload.width + '" height="' + upload.height + '">';
    } else {
      return '<a class="attachment" href="' + upload.url + '">' + upload.original_filename + '</a> (' + I18n.toHumanSize(upload.filesize) + ')';
    }
  },

  /**
    Check whether the path is refering to an image

    @method isAnImage
    @param {String} path The path
  **/
  isAnImage: function(path) {
    return Discourse.Utilities.IS_AN_IMAGE_REGEXP.test(path);
  },

  /**
    Determines whether we allow attachments or not

    @method allowsAttachments
  **/
  allowsAttachments: function() {
    return _.difference(Discourse.SiteSettings.authorized_extensions.split("|"), Discourse.Utilities.IMAGE_EXTENSIONS).length > 0;
  },

  authorizedExtensions: function() {
    return Discourse.SiteSettings.authorized_extensions.replace(/\|/g, ", ");
  },

  displayErrorForUpload: function(data) {
    // deal with meaningful errors first
    if (data.jqXHR) {
      switch (data.jqXHR.status) {
        // cancel from the user
        case 0: return;
        // entity too large, usually returned from the web server
        case 413:
          var maxSizeKB = Discourse.SiteSettings.max_image_size_kb;
          bootbox.alert(I18n.t('post.errors.image_too_large', { max_size_kb: maxSizeKB }));
          return;
        // the error message is provided by the server
        case 415: // media type not authorized
        case 422: // there has been an error on the server (mostly due to FastImage)
          bootbox.alert(data.jqXHR.responseText);
          return;
      }
    }
    // otherwise, display a generic error message
    bootbox.alert(I18n.t('post.errors.upload'));
  },

  /**
    Crop an image to be used as avatar.
    Simulate the "centered square thumbnail" generation done server-side.
    Uses only the first frame of animated gifs when they are disabled.

    @method cropAvatar
    @param {String} url The url of the avatar
    @param {String} fileType The file type of the uploaded file
    @returns {Ember.Deferred} a promise that will eventually be the cropped avatar.
  **/
  cropAvatar: function(url, fileType) {
    if (Discourse.SiteSettings.allow_animated_avatars && fileType === "image/gif") {
      // can't crop animated gifs... let the browser stretch the gif
      return Ember.RSVP.resolve(url);
    } else {
      return Ember.Deferred.promise(function(promise) {
        var image = document.createElement("img");
        // this event will be fired as soon as the image is loaded
        image.onload = function(e) {
          var img = e.target;
          // computes the dimension & position (x, y) of the largest square we can fit in the image
          var width = img.width, height = img.height, dimension, center, x, y;
          if (width <= height) {
            dimension = width;
            center = height / 2;
            x = 0;
            y = center - (dimension / 2);
          } else {
            dimension = height;
            center = width / 2;
            x = center - (dimension / 2);
            y = 0;
          }
          // set the size of the canvas to the maximum available size for avatars (browser will take care of downsizing the image)
          var canvas = document.createElement("canvas");
          var size = Discourse.Utilities.getRawSize(Discourse.Utilities.translateSize("huge"));
          canvas.height = canvas.width = size;
          // draw the image into the canvas
          canvas.getContext("2d").drawImage(img, x, y, dimension, dimension, 0, 0, size, size);
          // retrieve the image from the canvas
          promise.resolve(canvas.toDataURL(fileType));
        };
        // launch the onload event
        image.src = url;
      });
    }
  }

};
