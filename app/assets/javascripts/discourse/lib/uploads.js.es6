import { isAppleDevice } from "discourse/lib/utilities";

function isGUID(value) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
    value
  );
}

export function markdownNameFromFileName(fileName) {
  let name = fileName.substr(0, fileName.lastIndexOf("."));

  if (isAppleDevice() && isGUID(name)) {
    name = I18n.t("upload_selector.default_image_alt_text");
  }

  return name.replace(/\[|\]|\|/g, "");
}

export function validateUploadedFiles(files, opts) {
  if (!files || files.length === 0) {
    return false;
  }

  if (files.length > 1) {
    bootbox.alert(I18n.t("post.errors.too_many_uploads"));
    return false;
  }

  const upload = files[0];

  // CHROME ONLY: if the image was pasted, sets its name to a default one
  if (typeof Blob !== "undefined" && typeof File !== "undefined") {
    if (
      upload instanceof Blob &&
      !(upload instanceof File) &&
      upload.type === "image/png"
    ) {
      upload.name = "image.png";
    }
  }

  opts = opts || {};
  opts.type = uploadTypeFromFileName(upload.name);

  return validateUploadedFile(upload, opts);
}

function validateUploadedFile(file, opts) {
  if (opts.skipValidation) return true;

  opts = opts || {};
  let user = opts.user;
  let staff = user && user.staff;

  if (!authorizesOneOrMoreExtensions(staff)) return false;

  const name = file && file.name;

  if (!name) {
    return false;
  }

  // check that the uploaded file is authorized
  if (opts.allowStaffToUploadAnyFileInPm && opts.isPrivateMessage) {
    if (staff) {
      return true;
    }
  }

  if (opts.imagesOnly) {
    if (!isImage(name) && !isAuthorizedImage(name, staff)) {
      bootbox.alert(
        I18n.t("post.errors.upload_not_authorized", {
          authorized_extensions: authorizedImagesExtensions(staff)
        })
      );
      return false;
    }
  } else if (opts.csvOnly) {
    if (!/\.csv$/i.test(name)) {
      bootbox.alert(I18n.t("user.invited.bulk_invite.error"));
      return false;
    }
  } else {
    if (!authorizesAllExtensions(staff) && !isAuthorizedFile(name, staff)) {
      bootbox.alert(
        I18n.t("post.errors.upload_not_authorized", {
          authorized_extensions: authorizedExtensions(staff)
        })
      );
      return false;
    }
  }

  if (!opts.bypassNewUserRestriction) {
    // ensures that new users can upload a file
    if (user && !user.isAllowedToUploadAFile(opts.type)) {
      bootbox.alert(
        I18n.t(`post.errors.${opts.type}_upload_not_allowed_for_new_user`)
      );
      return false;
    }
  }

  // everything went fine
  return true;
}

const IMAGES_EXTENSIONS_REGEX = /(png|jpe?g|gif|svg|ico)/i;

function extensionsToArray(exts) {
  return exts
    .toLowerCase()
    .replace(/[\s\.]+/g, "")
    .split("|")
    .filter(ext => ext.indexOf("*") === -1);
}

function extensions() {
  return extensionsToArray(Discourse.SiteSettings.authorized_extensions);
}

function staffExtensions() {
  return extensionsToArray(
    Discourse.SiteSettings.authorized_extensions_for_staff
  );
}

function imagesExtensions(staff) {
  let exts = extensions().filter(ext => IMAGES_EXTENSIONS_REGEX.test(ext));
  if (staff) {
    const staffExts = staffExtensions().filter(ext =>
      IMAGES_EXTENSIONS_REGEX.test(ext)
    );
    exts = _.union(exts, staffExts);
  }
  return exts;
}

function extensionsRegex() {
  return new RegExp("\\.(" + extensions().join("|") + ")$", "i");
}

function imagesExtensionsRegex(staff) {
  return new RegExp("\\.(" + imagesExtensions(staff).join("|") + ")$", "i");
}

function staffExtensionsRegex() {
  return new RegExp("\\.(" + staffExtensions().join("|") + ")$", "i");
}

function isAuthorizedFile(fileName, staff) {
  if (staff && staffExtensionsRegex().test(fileName)) {
    return true;
  }
  return extensionsRegex().test(fileName);
}

function isAuthorizedImage(fileName, staff) {
  return imagesExtensionsRegex(staff).test(fileName);
}

export function authorizedExtensions(staff) {
  const exts = staff ? [...extensions(), ...staffExtensions()] : extensions();
  return exts.filter(ext => ext.length > 0).join(", ");
}

function authorizedImagesExtensions(staff) {
  return authorizesAllExtensions(staff)
    ? "png, jpg, jpeg, gif, svg, ico"
    : imagesExtensions(staff).join(", ");
}

export function authorizesAllExtensions(staff) {
  return (
    Discourse.SiteSettings.authorized_extensions.indexOf("*") >= 0 ||
    (Discourse.SiteSettings.authorized_extensions_for_staff.indexOf("*") >= 0 &&
      staff)
  );
}

export function authorizesOneOrMoreExtensions(staff) {
  if (authorizesAllExtensions(staff)) return true;

  return (
    Discourse.SiteSettings.authorized_extensions.split("|").filter(ext => ext)
      .length > 0
  );
}

export function authorizesOneOrMoreImageExtensions(staff) {
  if (authorizesAllExtensions(staff)) return true;
  return imagesExtensions(staff).length > 0;
}

export function isImage(path) {
  return /\.(png|jpe?g|gif|svg|ico)$/i.test(path);
}

export function isVideo(path) {
  return /\.(mov|mp4|webm|m4v|3gp|ogv|avi|mpeg|ogv)$/i.test(path);
}

export function isAudio(path) {
  return /\.(mp3|og[ga]|opus|wav|m4[abpr]|aac|flac)$/i.test(path);
}

function uploadTypeFromFileName(fileName) {
  return isImage(fileName) ? "image" : "attachment";
}

export function allowsImages(staff) {
  return (
    authorizesAllExtensions(staff) ||
    IMAGES_EXTENSIONS_REGEX.test(authorizedExtensions(staff))
  );
}

export function allowsAttachments(staff) {
  return (
    authorizesAllExtensions(staff) ||
    authorizedExtensions(staff).split(", ").length >
      imagesExtensions(staff).length
  );
}

export function uploadIcon(staff) {
  return allowsAttachments(staff) ? "upload" : "far-image";
}

function imageMarkdown(upload) {
  return `![${markdownNameFromFileName(upload.original_filename)}|${
    upload.thumbnail_width
  }x${upload.thumbnail_height}](${upload.short_url || upload.url})`;
}

function playableMediaMarkdown(upload, type) {
  return `![${markdownNameFromFileName(upload.original_filename)}|${type}](${
    upload.short_url
  })`;
}

function attachmentMarkdown(upload) {
  return `[${upload.original_filename}|attachment](${
    upload.short_url
  }) (${I18n.toHumanSize(upload.filesize)})`;
}

export function getUploadMarkdown(upload) {
  if (isImage(upload.original_filename)) {
    return imageMarkdown(upload);
  } else if (isAudio(upload.original_filename)) {
    return playableMediaMarkdown(upload, "audio");
  } else if (isVideo(upload.original_filename)) {
    return playableMediaMarkdown(upload, "video");
  } else {
    return attachmentMarkdown(upload);
  }
}

export function displayErrorForUpload(data) {
  if (data.jqXHR) {
    switch (data.jqXHR.status) {
      // cancelled by the user
      case 0:
        return;

      // entity too large, usually returned from the web server
      case 413:
        const type = uploadTypeFromFileName(data.files[0].name);
        const max_size_kb = Discourse.SiteSettings[`max_${type}_size_kb`];
        bootbox.alert(I18n.t("post.errors.file_too_large", { max_size_kb }));
        return;

      // the error message is provided by the server
      case 422:
        if (data.jqXHR.responseJSON.message) {
          bootbox.alert(data.jqXHR.responseJSON.message);
        } else {
          bootbox.alert(data.jqXHR.responseJSON.errors.join("\n"));
        }
        return;
    }
  } else if (data.errors && data.errors.length > 0) {
    bootbox.alert(data.errors.join("\n"));
    return;
  }
  // otherwise, display a generic error message
  bootbox.alert(I18n.t("post.errors.upload"));
}
