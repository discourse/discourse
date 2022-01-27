import Component from "@ember/component";
import { or } from "@ember/object/computed";
import UppyUploadMixin from "discourse/mixins/uppy-upload";
import discourseComputed, { on } from "discourse-common/utils/decorators";
import { getURLWithCDN } from "discourse-common/lib/get-url";
import { isEmpty } from "@ember/utils";
import lightbox from "discourse/lib/lightbox";
import { next } from "@ember/runloop";

export default Component.extend(UppyUploadMixin, {
  classNames: ["image-uploader"],
  uploadingOrProcessing: or("uploading", "processing"),

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
    next(() => lightbox(this.element, this.siteSettings));
  },

  @on("willDestroyElement")
  _closeOnRemoval() {
    if ($.magnificPopup?.instance) {
      $.magnificPopup.instance.close();
    }
  },

  actions: {
    toggleLightbox() {
      $(this.element.querySelector("a.lightbox"))?.magnificPopup("open");
    },

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
