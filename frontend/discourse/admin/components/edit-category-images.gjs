import EmberObject, { action, computed } from "@ember/object";
import { buildCategoryPanel } from "discourse/admin/components/edit-category-panel";
import PluginOutlet from "discourse/components/plugin-outlet";
import UppyImageUploader from "discourse/components/uppy-image-uploader";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";

export default class EditCategoryImages extends buildCategoryPanel("images") {
  @computed("category.uploaded_background.url")
  get backgroundImageUrl() {
    return this.category?.uploaded_background?.url || "";
  }

  @computed("category.uploaded_background_dark.url")
  get backgroundDarkImageUrl() {
    return this.category?.uploaded_background_dark?.url || "";
  }

  @computed("category.uploaded_logo.url")
  get logoImageUrl() {
    return this.category?.uploaded_logo?.url || "";
  }

  @computed("category.uploaded_logo_dark.url")
  get logoImageDarkUrl() {
    return this.category?.uploaded_logo_dark?.url || "";
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

  <template>
    <section class="field category-logo">
      <label>{{i18n "category.logo"}}</label>
      <UppyImageUploader
        @imageUrl={{this.logoImageUrl}}
        @onUploadDone={{this.logoUploadDone}}
        @onUploadDeleted={{this.logoUploadDeleted}}
        @type="category_logo"
        @id="category-logo-uploader"
        class="no-repeat contain-image"
      />
      <div class="category-logo-description">
        {{i18n "category.logo_description"}}
      </div>
    </section>

    <section class="field category-logo">
      <label>{{i18n "category.logo_dark"}}</label>
      <UppyImageUploader
        @imageUrl={{this.logoImageDarkUrl}}
        @onUploadDone={{this.logoDarkUploadDone}}
        @onUploadDeleted={{this.logoDarkUploadDeleted}}
        @type="category_logo_dark"
        @id="category-dark-logo-uploader"
        class="no-repeat contain-image"
      />
      <div class="category-logo-description">
        {{i18n "category.logo_description"}}
      </div>
    </section>

    <section class="field category-background-image">
      <label>{{i18n "category.background_image"}}</label>
      <UppyImageUploader
        @imageUrl={{this.backgroundImageUrl}}
        @onUploadDone={{this.backgroundUploadDone}}
        @onUploadDeleted={{this.backgroundUploadDeleted}}
        @type="category_background"
        @id="category-background-uploader"
      />
    </section>

    <section class="field category-background-image">
      <label>{{i18n "category.background_image_dark"}}</label>
      <UppyImageUploader
        @imageUrl={{this.backgroundDarkImageUrl}}
        @onUploadDone={{this.backgroundDarkUploadDone}}
        @onUploadDeleted={{this.backgroundDarkUploadDeleted}}
        @type="category_background_dark"
        @id="category-dark-background-uploader"
      />
    </section>

    <PluginOutlet
      @name="category-custom-images"
      @outletArgs={{lazyHash category=this.category}}
    />
  </template>
}
