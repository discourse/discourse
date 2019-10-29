import { next } from "@ember/runloop";
import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";
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

  willDestroyElement() {
    this._super(...arguments);
    const elem = $("a.lightbox");
    if (elem && typeof elem.magnificPopup === "function") {
      $("a.lightbox").magnificPopup("close");
    }
  },

  @computed("imageUrl", "placeholderUrl")
  showingPlaceholder(imageUrl, placeholderUrl) {
    return !imageUrl && placeholderUrl;
  },

  @computed("placeholderUrl")
  placeholderStyle(url) {
    if (Ember.isEmpty(url)) {
      return "".htmlSafe();
    }
    return `background-image: url(${url})`.htmlSafe();
  },

  @computed("imageUrl")
  imageCDNURL(url) {
    if (Ember.isEmpty(url)) {
      return "".htmlSafe();
    }

    return Discourse.getURLWithCDN(url);
  },

  @computed("imageCDNURL")
  backgroundStyle(url) {
    return `background-image: url(${url})`.htmlSafe();
  },

  @computed("imageUrl")
  imageBaseName(imageUrl) {
    if (Ember.isEmpty(imageUrl)) return;
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
      imageHeight: upload.height
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
    if (this.imageUrl) next(() => lightbox($(this.element)));
  },

  actions: {
    toggleLightbox() {
      if (this.imageFilename) {
        this._openLightbox();
      } else {
        this.set("loadingLightbox", true);

        ajax(`/uploads/lookup-metadata`, {
          type: "POST",
          data: { url: this.imageUrl }
        })
          .then(json => {
            this.setProperties({
              imageFilename: json.original_filename,
              imageFilesize: json.human_filesize,
              imageWidth: json.width,
              imageHeight: json.height
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
    }
  }
});
