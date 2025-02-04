import EmberObject, { action } from "@ember/object";
import { buildCategoryPanel } from "discourse/components/edit-category-panel";
import discourseComputed from "discourse/lib/decorators";

export default class EditCategoryImages extends buildCategoryPanel("images") {
  @discourseComputed("category.uploaded_background.url")
  backgroundImageUrl(uploadedBackgroundUrl) {
    return uploadedBackgroundUrl || "";
  }

  @discourseComputed("category.uploaded_background_dark.url")
  backgroundDarkImageUrl(uploadedBackgroundDarkUrl) {
    return uploadedBackgroundDarkUrl || "";
  }

  @discourseComputed("category.uploaded_logo.url")
  logoImageUrl(uploadedLogoUrl) {
    return uploadedLogoUrl || "";
  }

  @discourseComputed("category.uploaded_logo_dark.url")
  logoImageDarkUrl(uploadedLogoDarkUrl) {
    return uploadedLogoDarkUrl || "";
  }

  @action
  logoUploadDone(upload) {
    this._setFromUpload("category.uploaded_logo", upload);
  }

  @action
  logoUploadDeleted() {
    this._deleteUpload("category.uploaded_logo");
  }

  @action
  logoDarkUploadDone(upload) {
    this._setFromUpload("category.uploaded_logo_dark", upload);
  }

  @action
  logoDarkUploadDeleted() {
    this._deleteUpload("category.uploaded_logo_dark");
  }

  @action
  backgroundUploadDone(upload) {
    this._setFromUpload("category.uploaded_background", upload);
  }

  @action
  backgroundUploadDeleted() {
    this._deleteUpload("category.uploaded_background");
  }

  @action
  backgroundDarkUploadDone(upload) {
    this._setFromUpload("category.uploaded_background_dark", upload);
  }

  @action
  backgroundDarkUploadDeleted() {
    this._deleteUpload("category.uploaded_background_dark");
  }

  _deleteUpload(path) {
    this.set(
      path,
      EmberObject.create({
        id: null,
        url: null,
      })
    );
  }

  _setFromUpload(path, upload) {
    this.set(
      path,
      EmberObject.create({
        url: upload.url,
        id: upload.id,
      })
    );
  }
}
