import { escape } from 'pretty-text/sanitizer';

export function translateSize(size) {
  switch (size) {
    case 'tiny': return 20;
    case 'small': return 25;
    case 'medium': return 32;
    case 'large': return 45;
    case 'extra_large': return 60;
    case 'huge': return 120;
  }
  return size;
}

export function escapeExpression(string) {
  // don't escape SafeStrings, since they're already safe
  if (string instanceof Handlebars.SafeString) {
    return string.toString();
  }

  return escape(string);
}

export function avatarUrl(template, size) {
  if (!template) { return ""; }
  const rawSize = getRawSize(translateSize(size));
  return template.replace(/\{size\}/g, rawSize);
}

export function getRawSize(size) {
  const pixelRatio = window.devicePixelRatio || 1;
  return size * Math.min(3, Math.max(1, Math.round(pixelRatio)));
}

export function avatarImg(options, getURL) {
  getURL = getURL || Discourse.getURLWithCDN;

  const size = translateSize(options.size);
  const url = avatarUrl(options.avatarTemplate, size);

  // We won't render an invalid url
  if (!url || url.length === 0) { return ""; }

  const classes = "avatar" + (options.extraClasses ? " " + options.extraClasses : "");
  const title = (options.title) ? " title='" + escapeExpression(options.title || "") + "'" : "";

  return "<img alt='' width='" + size + "' height='" + size + "' src='" + getURL(url) + "' class='" + classes + "'" + title + ">";
}

export function tinyAvatar(avatarTemplate, options) {
  return avatarImg(_.merge({avatarTemplate: avatarTemplate, size: 'tiny' }, options));
}

export function postUrl(slug, topicId, postNumber) {
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
}

export function userUrl(username) {
  return Discourse.getURL("/users/" + username.toLowerCase());
}

export function emailValid(email) {
  // see:  http://stackoverflow.com/questions/46155/validate-email-address-in-javascript
  var re = /^[a-zA-Z0-9!#$%&'*+\/=?\^_`{|}~\-]+(?:\.[a-zA-Z0-9!#$%&'\*+\/=?\^_`{|}~\-]+)*@(?:[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?\.)+[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?$/;
  return re.test(email);
}

export function selectedText() {
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
}

// Determine the row and col of the caret in an element
export function caretRowCol(el) {
  var cp = caretPosition(el);
  var rows = el.value.slice(0, cp).split("\n");
  var rowNum = rows.length;

  var colNum = cp - rows.splice(0, rowNum - 1).reduce(function(sum, row) {
    return sum + row.length + 1;
  }, 0);

  return { rowNum: rowNum, colNum: colNum};
}

// Determine the position of the caret in an element
export function caretPosition(el) {
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
}

// Set the caret's position
export function setCaretPosition(ctrl, pos) {
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

export function validateUploadedFiles(files, bypassNewUserRestriction) {
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

  var type = uploadTypeFromFileName(upload.name);

  return validateUploadedFile(upload, type, bypassNewUserRestriction);
}

export function validateUploadedFile(file, type, bypassNewUserRestriction) {
  // check that the uploaded file is authorized
  if (!authorizesAllExtensions() &&
      !isAuthorizedUpload(file)) {
    var extensions = authorizedExtensions();
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
}

export function uploadTypeFromFileName(fileName) {
  return isAnImage(fileName) ? 'image' : 'attachment';
}

export function authorizesAllExtensions() {
  return Discourse.SiteSettings.authorized_extensions.indexOf("*") >= 0;
}

export function isAuthorizedUpload(file) {
  if (file && file.name) {
    var extensions = _.chain(Discourse.SiteSettings.authorized_extensions.split("|"))
      .reject(function(extension) { return extension.indexOf("*") >= 0; })
      .map(function(extension) { return (extension.indexOf(".") === 0 ? extension.substring(1) : extension).replace(".", "\\."); })
      .value();
    return new RegExp("\\.(" + extensions.join("|") + ")$", "i").test(file.name);
  }
  return false;
}

export function authorizedExtensions() {
  return _.chain(Discourse.SiteSettings.authorized_extensions.split("|"))
    .reject(function(extension) { return extension.indexOf("*") >= 0; })
    .map(function(extension) { return extension.toLowerCase(); })
    .value()
    .join(", ");
}

export function uploadLocation(url) {
  if (Discourse.CDN) {
    url = Discourse.getURLWithCDN(url);
    return url.startsWith('//') ? 'http:' + url : url;
  } else if (Discourse.SiteSettings.enable_s3_uploads) {
    return 'https:' + url;
  } else {
    var protocol = window.location.protocol + '//',
      hostname = window.location.hostname,
      port = ':' + window.location.port;
    return protocol + hostname + port + url;
  }
}

export function getUploadMarkdown(upload) {
  if (isAnImage(upload.original_filename)) {
    return '<img src="' + upload.url + '" width="' + upload.width + '" height="' + upload.height + '">';
  } else if (!Discourse.SiteSettings.prevent_anons_from_downloading_files && (/\.(mov|mp4|webm|ogv|mp3|ogg|wav|m4a)$/i).test(upload.original_filename)) {
    // is Audio/Video
    return uploadLocation(upload.url);
  } else {
    return '<a class="attachment" href="' + upload.url + '">' + upload.original_filename + '</a> (' + I18n.toHumanSize(upload.filesize) + ')\n';
  }
}

export function isAnImage(path) {
  return (/\.(png|jpe?g|gif|bmp|tiff?|svg|webp|ico)$/i).test(path);
}

export function allowsImages() {
  return authorizesAllExtensions() ||
    (/(png|jpe?g|gif|bmp|tiff?|svg|webp|ico)/i).test(authorizedExtensions());
}

export function allowsAttachments() {
  return authorizesAllExtensions() ||
    !(/((png|jpe?g|gif|bmp|tiff?|svg|web|ico)(,\s)?)+$/i).test(authorizedExtensions());
}

export function displayErrorForUpload(data) {
  // deal with meaningful errors first
  if (data.jqXHR) {
    switch (data.jqXHR.status) {
      // cancelled by the user
      case 0: return;

              // entity too large, usually returned from the web server
      case 413:
              var type = uploadTypeFromFileName(data.files[0].name);
              var maxSizeKB = Discourse.SiteSettings['max_' + type + '_size_kb'];
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
}

export function defaultHomepage() {
  // the homepage is the first item of the 'top_menu' site setting
  return Discourse.SiteSettings.top_menu.split("|")[0].split(",")[0];
}

// This prevents a mini racer crash
export default {};
