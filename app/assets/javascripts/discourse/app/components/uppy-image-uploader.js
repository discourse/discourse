import Component from "@ember/component";
import UppyUploadMixin from "discourse/mixins/uppy-upload";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse-common/utils/decorators";
import { getURLWithCDN } from "discourse-common/lib/get-url";
import { isEmpty } from "@ember/utils";
import lightbox from "discourse/lib/lightbox";
import { next } from "@ember/runloop";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Component.extend(UppyUploadMixin, {
  classNames: ["image-uploader"],
  loadingLightbox: false,

  init() {
    this._super(...arguments);
    this._applyLightbox();
  },

  willDestroyElement() {
    this._super(...arguments);
    const elem = $("a.lightbox");
    if (elem && typeof elem.magnificPopup === "function") {
      $("a.lightbox").magnificPopup("close");
    }
  },

  @discourseComputed("imageUrl", "placeholderUrl")
  showingPlaceholder(imageUrl, placeholderUrl) {
    return !imageUrl && placeholderUrl;
  },

  @discourseComputed("placeholderUrl")
  placeholderStyle(url) {
    if (isEmpty(url)) {
      return "".htmlSafe();
    }
    return `background-image: url(${url})`.htmlSafe();
  },

  @discourseComputed("imageUrl")
  imageCDNURL(url) {
    if (isEmpty(url)) {
      return "".htmlSafe();
    }

    return getURLWithCDN(url);
  },

  @discourseComputed("imageCDNURL")
  backgroundStyle(url) {
    return `background-image: url(${url})`.htmlSafe();
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

  uploadDone(upload) {
    this.setProperties({
      imageUrl: upload.url,
      imageId: upload.id,
      imageFilesize: upload.human_filesize,
      imageFilename: upload.original_filename,
      imageWidth: upload.width,
      imageHeight: upload.height,
    });

    this._applyLightbox();

    if (this.onUploadDone) {
      this.onUploadDone(upload);
    }
  },

  _openLightbox() {
    next(() =>
      $(this.element.querySelector("a.lightbox")).magnificPopup("open")
    );
  },

  _applyLightbox() {
    if (this.imageUrl) {
      next(() => lightbox(this.element, this.siteSettings));
    }
  },

  actions: {
    toggleLightbox() {
      if (this.imageFilename) {
        this._openLightbox();
      } else {
        this.set("loadingLightbox", true);

        ajax(`/uploads/lookup-metadata`, {
          type: "POST",
          data: { url: this.imageUrl },
        })
          .then((json) => {
            this.setProperties({
              imageFilename: json.original_filename,
              imageFilesize: json.human_filesize,
              imageWidth: json.width,
              imageHeight: json.height,
            });

            this._openLightbox();
            this.set("loadingLightbox", false);
          })
          .catch(popupAjaxError);
      }
    },

    trash() {
      this.setProperties({ imageUrl: null, imageId: null });

      // uppy needs to be reset to allow for more uploads
      this._reset();

      if (this.onUploadDeleted) {
        this.onUploadDeleted();
      }
    },
  },
});
