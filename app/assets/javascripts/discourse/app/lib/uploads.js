import deprecated from "discourse/lib/deprecated";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import { humanizeList } from "discourse/lib/text";
import { isAppleDevice } from "discourse/lib/utilities";
import I18n, { i18n } from "discourse-i18n";

function isGUID(value) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
    value
  );
}

// original string `![image|foo=bar|690x220, 50%|bar=baz](upload://1TjaobgKObzpU7xRMw2HuUc87vO.png "image title")`
// group 1 `image|foo=bar`
// group 2 `690x220`
// group 3 `, 50%`
// group 4 '|bar=baz'
// group 5 'upload://1TjaobgKObzpU7xRMw2HuUc87vO.png "image title"'

// Notes:
// Group 3 is optional. group 4 can match images with or without a markdown title.
// All matches are whitespace tolerant as long it's still valid markdown.
// If the image is inside a code block, we'll ignore it `(?!(.*`))`.
export const IMAGE_MARKDOWN_REGEX =
  /!\[(.*?)\|(\d{1,4}x\d{1,4})(,\s*\d{1,3}%)?(.*?)\]\((upload:\/\/.*?)\)(?!(.*`))/g;

// This wrapper simplifies unit testing the dialog service
export const dialog = {
  alert(msg) {
    const dg = getOwnerWithFallback(this).lookup("service:dialog");
    dg.alert(msg);
  },
};

export function markdownNameFromFileName(fileName) {
  let name = fileName.slice(0, fileName.lastIndexOf("."));

  if (isAppleDevice() && isGUID(name)) {
    name = i18n("upload_selector.default_image_alt_text");
  }

  return name.replace(/\[|\]|\|/g, "");
}

export function validateUploadedFiles(files, opts) {
  if (!files || files.length === 0) {
    return false;
  }

  if (files.length > 1) {
    dialog.alert(i18n("post.errors.too_many_uploads"));
    return false;
  }

  const upload = files[0];
  return validateUploadedFile(upload, opts);
}

export function validateUploadedFile(file, opts) {
  // CHROME ONLY: if the image was pasted, sets its name to a default one
  if (typeof Blob !== "undefined" && typeof File !== "undefined") {
    if (
      file instanceof Blob &&
      !(file instanceof File) &&
      file.type === "image/png"
    ) {
      file.name = "image.png";
    }
  }

  opts = opts || {};
  opts.type = uploadTypeFromFileName(file.name);

  if (opts.skipValidation) {
    return true;
  }

  let user = opts.user;
  let staff = user && user.staff;

  if (!authorizesOneOrMoreExtensions(staff, opts.siteSettings)) {
    dialog.alert(i18n("post.errors.no_uploads_authorized"));
    return false;
  }

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
    if (!isImage(name) && !isAuthorizedImage(name, staff, opts.siteSettings)) {
      dialog.alert(
        i18n("post.errors.upload_not_authorized", {
          authorized_extensions: authorizedImagesExtensions(
            staff,
            opts.siteSettings
          ),
        })
      );
      return false;
    }
  } else if (opts.csvOnly) {
    if (!/\.csv$/i.test(name)) {
      dialog.alert(i18n("user.invited.bulk_invite.error"));
      return false;
    }
  } else {
    if (
      !authorizesAllExtensions(staff, opts.siteSettings) &&
      !isAuthorizedFile(name, staff, opts.siteSettings)
    ) {
      dialog.alert(
        i18n("post.errors.upload_not_authorized", {
          authorized_extensions: authorizedExtensions(
            staff,
            opts.siteSettings
          ).join(", "),
        })
      );
      return false;
    }
  }

  if (!opts.bypassNewUserRestriction) {
    // ensures that new users can upload a file
    if (user && !user.isAllowedToUploadAFile(opts.type)) {
      dialog.alert(
        i18n(`post.errors.${opts.type}_upload_not_allowed_for_new_user`)
      );
      return false;
    }
  }

  if (file.size === 0) {
    /* eslint-disable no-console */
    console.warn("File with a 0 byte size detected, cancelling upload.", file);
    dialog.alert(i18n("post.errors.file_size_zero"));
    return false;
  }

  // everything went fine
  return true;
}

function extensionsToArray(exts) {
  return exts
    .toLowerCase()
    .replace(/[\s\.]+/g, "")
    .split("|")
    .filter((ext) => !ext.includes("*"));
}

function extensions(siteSettings) {
  return extensionsToArray(siteSettings.authorized_extensions);
}

function staffExtensions(siteSettings) {
  return extensionsToArray(siteSettings.authorized_extensions_for_staff);
}

function imagesExtensions(staff, siteSettings) {
  let exts = extensions(siteSettings).filter((ext) => isImage(`.${ext}`));
  if (staff) {
    const staffExts = staffExtensions(siteSettings).filter((ext) =>
      isImage(`.${ext}`)
    );
    exts = exts.concat(staffExts);
  }
  return exts;
}

function isAuthorizedFile(fileName, staff, siteSettings) {
  if (
    staff &&
    new RegExp(
      "\\.(" + staffExtensions(siteSettings).join("|") + ")$",
      "i"
    ).test(fileName)
  ) {
    return true;
  }

  return new RegExp(
    "\\.(" + extensions(siteSettings).join("|") + ")$",
    "i"
  ).test(fileName);
}

function isAuthorizedImage(fileName, staff, siteSettings) {
  return new RegExp(
    "\\.(" + imagesExtensions(staff, siteSettings).join("|") + ")$",
    "i"
  ).test(fileName);
}

export function authorizedExtensions(staff, siteSettings) {
  const exts = staff
    ? [...extensions(siteSettings), ...staffExtensions(siteSettings)]
    : extensions(siteSettings);
  return exts.filter((ext) => ext.length > 0);
}

function authorizedImagesExtensions(staff, siteSettings) {
  return authorizesAllExtensions(staff, siteSettings)
    ? "png, jpg, jpeg, gif, svg, ico, heic, heif, webp, avif"
    : imagesExtensions(staff, siteSettings).join(", ");
}

export function authorizesAllExtensions(staff, siteSettings) {
  return (
    siteSettings.authorized_extensions.includes("*") ||
    (siteSettings.authorized_extensions_for_staff.includes("*") && staff)
  );
}

export function authorizesOneOrMoreExtensions(staff, siteSettings) {
  if (authorizesAllExtensions(staff, siteSettings)) {
    return true;
  }

  return (
    siteSettings.authorized_extensions.split("|").filter((ext) => ext).length >
      0 ||
    (siteSettings.authorized_extensions_for_staff
      .split("|")
      .filter((ext) => ext).length > 0 &&
      staff)
  );
}

export function authorizesOneOrMoreImageExtensions(staff, siteSettings) {
  if (authorizesAllExtensions(staff, siteSettings)) {
    return true;
  }
  return imagesExtensions(staff, siteSettings).length > 0;
}

export function isImage(path) {
  return /\.(png|webp|jpe?g|gif|svg|ico|heic|heif|avif)$/i.test(path);
}

export function isVideo(path) {
  return /\.(mov|mp4|webm|m4v|3gp|ogv|avi|mpeg)$/i.test(path);
}

export function isAudio(path) {
  return /\.(mp3|og[ga]|opus|wav|m4[abpr]|aac|flac)$/i.test(path);
}

export function isBackup(path) {
  return /^\w[\w\.-]*-v\d+\.(tar\.gz)$/i.test(path);
}

function uploadTypeFromFileName(fileName) {
  return isImage(fileName)
    ? "image"
    : isBackup(fileName)
    ? "backup"
    : "attachment";
}

export function allowsImages(staff, siteSettings) {
  return (
    authorizesAllExtensions(staff, siteSettings) ||
    authorizedExtensions(staff, siteSettings).some((ext) => isImage(`.${ext}`))
  );
}

export function allowsAttachments(staff, siteSettings) {
  return (
    authorizesAllExtensions(staff, siteSettings) ||
    authorizedExtensions(staff, siteSettings).length >
      imagesExtensions(staff, siteSettings).length
  );
}

export function uploadIcon(staff, siteSettings) {
  return allowsAttachments(staff, siteSettings) ? "upload" : "far-image";
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

export function displayErrorForBulkUpload(errors) {
  const fileNames = humanizeList(errors.mapBy("fileName"));

  dialog.alert(i18n("post.errors.upload", { file_name: fileNames }));
}

export function displayErrorForUpload(data, siteSettings, fileName) {
  if (!fileName) {
    deprecated(
      "Calling displayErrorForUpload without a fileName is deprecated and will be removed in a future version.",
      { id: "discourse.uploads.display-error-for-upload" }
    );
    fileName = data.files[0].name;
  }

  if (data.jqXHR) {
    const didError = displayErrorByResponseStatus(
      data.jqXHR.status,
      data.jqXHR.responseJSON,
      fileName,
      siteSettings
    );
    if (didError) {
      return;
    }
  } else if (data.responseText && data.status) {
    let parsedBody = data.responseText;
    if (typeof parsedBody === "string") {
      try {
        parsedBody = JSON.parse(parsedBody);
      } catch {
        // ignore
      }
    }
    const didError = displayErrorByResponseStatus(
      data.status,
      parsedBody,
      fileName,
      siteSettings
    );
    if (didError) {
      return;
    }
  } else if (data.errors && data.errors.length > 0) {
    dialog.alert(data.errors.join("\n"));
    return;
  }

  // otherwise, display a generic error message
  dialog.alert(i18n("post.errors.upload", { file_name: fileName }));
}

function displayErrorByResponseStatus(status, body, fileName, siteSettings) {
  switch (status) {
    // didn't get headers from server, or browser refuses to tell us
    case 0:
      dialog.alert(i18n("post.errors.upload", { file_name: fileName }));
      return true;

    // entity too large, usually returned from the web server
    case 413:
      const type = uploadTypeFromFileName(fileName);
      if (type === "backup") {
        dialog.alert(i18n("post.errors.backup_too_large"));
      } else {
        const max_size_kb = siteSettings[`max_${type}_size_kb`];
        dialog.alert(
          i18n("post.errors.file_too_large_humanized", {
            max_size: I18n.toHumanSize(max_size_kb * 1024),
          })
        );
      }
      return true;

    // the error message is provided by the server
    case 422:
      if (body.message) {
        dialog.alert(body.message);
      } else {
        dialog.alert(body.errors.join("\n"));
      }
      return true;
  }

  return;
}

export function bindFileInputChangeListener(element, fileCallbackFn) {
  function changeListener(event) {
    const files = Array.from(event.target.files);
    files.forEach((file) => {
      fileCallbackFn(file);
    });
  }
  element.addEventListener("change", changeListener);
  return changeListener;
}
