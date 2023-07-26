import Component from "@ember/component";
import { action } from "@ember/object";
import { or } from "@ember/object/computed";
import UppyUploadMixin from "discourse/mixins/uppy-upload";
import discourseComputed, { on } from "discourse-common/utils/decorators";
import { getURLWithCDN } from "discourse-common/lib/get-url";
import { isEmpty } from "@ember/utils";
import {
  cleanupLightboxes,
  default as lightbox,
  setupLightboxes,
} from "discourse/lib/lightbox";
import { next } from "@ember/runloop";
import { htmlSafe } from "@ember/template";
import { authorizesOneOrMoreExtensions } from "discourse/lib/uploads";
import I18n from "I18n";

export default Component.extend(UppyUploadMixin, {
  classNames: ["image-uploader"],
  disabled: or("notAllowed", "uploading", "processing"),

  @discourseComputed("siteSettings.enable_experimental_lightbox")
  experimentalLightboxEnabled(experimentalLightboxEnabled) {
    return experimentalLightboxEnabled;
  },

  @discourseComputed("disabled", "notAllowed")
  disabledReason(disabled, notAllowed) {
    if (disabled && notAllowed) {
      return I18n.t("post.errors.no_uploads_authorized");
    }
  },

  @discourseComputed(
    "currentUser.staff",
    "siteSettings.{authorized_extensions,authorized_extensions_for_staff}"
  )
  notAllowed() {
    return !authorizesOneOrMoreExtensions(
      this.currentUser?.staff,
      this.siteSettings
    );
  },

  @discourseComputed("imageUrl", "placeholderUrl")
  showingPlaceholder(imageUrl, placeholderUrl) {
    return !imageUrl && placeholderUrl;
  },

  @discourseComputed("placeholderUrl")
  placeholderStyle(url) {
    if (isEmpty(url)) {
      return htmlSafe("");
    }
    return htmlSafe(`background-image: url(${url})`);
  },

  @discourseComputed("imageUrl")
  imageCDNURL(url) {
    if (isEmpty(url)) {
      return htmlSafe("");
    }

    return getURLWithCDN(url);
  },

  @discourseComputed("imageCDNURL")
  backgroundStyle(url) {
    return htmlSafe(`background-image: url(${url})`);
  },

  @discourseComputed("imageUrl")
  imageBaseName(imageUrl) {
    if (isEmpty(imageUrl)) {
      return;
    }
    return imageUrl.split("/").slice(-1)[0];
  },

  validateUploadedFilesOptions() {
    return { imagesOnly: true };
  },

  _uppyReady() {
    this._onPreProcessComplete(() => {
      this.set("processing", false);
    });
  },

  uploadDone(upload) {
    this.setProperties({
      imageFilesize: upload.human_filesize,
      imageFilename: upload.original_filename,
      imageWidth: upload.width,
      imageHeight: upload.height,
    });

    // the value of the property used for imageUrl should be set
    // in this callback. this should be done in cases where imageUrl
    // is bound to a computed property of the parent component.
    if (this.onUploadDone) {
      this.onUploadDone(upload);
    } else {
      this.set("imageUrl", upload.url);
    }
  },

  @on("didRender")
  _applyLightbox() {
    if (this.experimentalLightboxEnabled) {
      setupLightboxes({
        container: this.element,
        selector: ".lightbox",
      });
    } else {
      next(() => lightbox(this.element, this.siteSettings));
    }
  },

  @on("willDestroyElement")
  _closeOnRemoval() {
    if (this.experimentalLightboxEnabled) {
      cleanupLightboxes();
    } else {
      if ($.magnificPopup?.instance) {
        $.magnificPopup.instance.close();
      }
    }
  },

  @action
  toggleLightbox() {
    $(this.element.querySelector("a.lightbox"))?.magnificPopup("open");
  },

  actions: {
    trash() {
      // uppy needs to be reset to allow for more uploads
      this._reset();

      // the value of the property used for imageUrl should be cleared
      // in this callback. this should be done in cases where imageUrl
      // is bound to a computed property of the parent component.
      if (this.onUploadDeleted) {
        this.onUploadDeleted();
      } else {
        this.setProperties({ imageUrl: null });
      }
    },
  },
});
