import computed from "ember-addons/ember-computed-decorators";
import UploadMixin from "discourse/mixins/upload";
import lightbox from "discourse/lib/lightbox";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Ember.Component.extend(UploadMixin, {
  classNames: ["image-uploader"],

  init() {
    this._super(...arguments);
    this._applyLightbox();
  },

  willDestroyElement() {
    this._super(...arguments);
    $("a.lightbox").magnificPopup("close");
  },

  @computed("imageUrl")
  backgroundStyle(imageUrl) {
    if (Ember.isEmpty(imageUrl)) {
      return "".htmlSafe();
    }

    return `background-image: url(${imageUrl})`.htmlSafe();
  },

  @computed("imageUrl")
  imageBaseName(imageUrl) {
    if (Ember.isEmpty(imageUrl)) return;
    return imageUrl.split("/").slice(-1)[0];
  },

  @computed("backgroundStyle")
  hasBackgroundStyle(backgroundStyle) {
    return !Ember.isEmpty(backgroundStyle.string);
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
    Ember.run.next(() => this.$("a.lightbox").magnificPopup("open"));
  },

  _applyLightbox() {
    if (this.get("imageUrl")) Ember.run.next(() => lightbox(this.$()));
  },

  actions: {
    toggleLightbox() {
      if (this.get("imageFilename")) {
        this._openLightbox();
      } else {
        ajax(`/uploads/lookup-metadata`, {
          type: "POST",
          data: { url: this.get("imageUrl") }
        })
          .then(json => {
            this.setProperties({
              imageFilename: json.original_filename,
              imageFilesize: json.human_filesize,
              imageWidth: json.width,
              imageHeight: json.height
            });

            this._openLightbox();
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
