import { getURLWithCDN } from "discourse-common/lib/get-url";
import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";
import { next } from "@ember/runloop";
import Component from "@ember/component";
import UploadMixin from "discourse/mixins/upload";
import lightbox from "discourse/lib/lightbox";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Component.extend(UploadMixin, {
  classNames: ["image-uploader"],
  loadingLightbox: false,

  init() {
    this._super(...arguments);
    this._applyLightbox();
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
    next(() => {
      // get the gallery for current uploader. "lg-uid" is added by lightgallery
      const uid = this.element.getAttribute("lg-uid");
      const gallery = window.lgData[uid];
      // gallery.s is lightGallery settings for this gallery
      const gallerySettings = gallery.s;
      // disable zoom, title, and counter options since they're not needed here
      gallerySettings.getCaptionFromTitleOrAlt = false;
      gallerySettings.zoom = false;
      gallerySettings.counter = false;
      // 0 is index - because image uploader only has 1 image at a time
      gallery.build(0);
    });
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

      if (this.onUploadDeleted) {
        this.onUploadDeleted();
      }
    },
  },
});
