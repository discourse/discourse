import Component from "@glimmer/component";
import { action } from "@ember/object";
import PluginOutlet from "discourse/components/plugin-outlet";
import UppyImageUploader from "discourse/components/uppy-image-uploader";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";

export default class EditCategoryImages extends Component {
  get category() {
    return this.args.category;
  }

  get form() {
    return this.args.form;
  }

  get transientData() {
    return this.args.transientData;
  }

  get backgroundImageUrl() {
    return this.transientData?.uploaded_background?.url ?? "";
  }

  get backgroundDarkImageUrl() {
    return this.transientData?.uploaded_background_dark?.url ?? "";
  }

  get logoImageUrl() {
    return this.transientData?.uploaded_logo?.url ?? "";
  }

  get logoImageDarkUrl() {
    return this.transientData?.uploaded_logo_dark?.url ?? "";
  }

  get panelClass() {
    const isActive = this.args.selectedTab === "images" ? "active" : "";
    return `edit-category-tab edit-category-tab-images ${isActive}`;
  }

  @action
  logoUploadDone(upload) {
    this.form.set("uploaded_logo", { url: upload.url, id: upload.id });
  }

  @action
  logoUploadDeleted() {
    this.form.set("uploaded_logo", { id: null, url: null });
  }

  @action
  logoDarkUploadDone(upload) {
    this.form.set("uploaded_logo_dark", { url: upload.url, id: upload.id });
  }

  @action
  logoDarkUploadDeleted() {
    this.form.set("uploaded_logo_dark", { id: null, url: null });
  }

  @action
  backgroundUploadDone(upload) {
    this.form.set("uploaded_background", { url: upload.url, id: upload.id });
  }

  @action
  backgroundUploadDeleted() {
    this.form.set("uploaded_background", { id: null, url: null });
  }

  @action
  backgroundDarkUploadDone(upload) {
    this.form.set("uploaded_background_dark", {
      url: upload.url,
      id: upload.id,
    });
  }

  @action
  backgroundDarkUploadDeleted() {
    this.form.set("uploaded_background_dark", { id: null, url: null });
  }

  <template>
    <div class={{this.panelClass}}>
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
    </div>
  </template>
}
