import EmberObject from "@ember/object";
import { buildCategoryPanel } from "discourse/components/edit-category-panel";
import { default as computed } from "ember-addons/ember-computed-decorators";

export default buildCategoryPanel("images").extend({
  @computed("category.uploaded_background.url")
  backgroundImageUrl(uploadedBackgroundUrl) {
    return uploadedBackgroundUrl || "";
  },

  @computed("category.uploaded_logo.url")
  logoImageUrl(uploadedLogoUrl) {
    return uploadedLogoUrl || "";
  },

  actions: {
    logoUploadDone(upload) {
      this._setFromUpload("category.uploaded_logo", upload);
    },

    logoUploadDeleted() {
      this._deleteUpload("category.uploaded_logo");
    },

    backgroundUploadDone(upload) {
      this._setFromUpload("category.uploaded_background", upload);
    },

    backgroundUploadDeleted() {
      this._deleteUpload("category.uploaded_background");
    }
  },

  _deleteUpload(path) {
    this.set(
      path,
      EmberObject.create({
        id: null,
        url: null
      })
    );
  },

  _setFromUpload(path, upload) {
    this.set(
      path,
      EmberObject.create({
        url: upload.url,
        id: upload.id
      })
    );
  }
});
