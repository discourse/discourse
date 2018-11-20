import { buildCategoryPanel } from "discourse/components/edit-category-panel";
import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";

export default buildCategoryPanel("images").extend({
  @computed("category.uploaded_background.url")
  backgroundImageUrl(uploadedBackgroundUrl) {
    return uploadedBackgroundUrl || "";
  },

  @computed("category.uploaded_background.id")
  backgroundImageId(uploadedBackgroundId) {
    return uploadedBackgroundId || null;
  },

  @computed("category.uploaded_logo.url")
  logoImageUrl(uploadedLogoUrl) {
    return uploadedLogoUrl || "";
  },

  @computed("category.uploaded_logo.id")
  logoImageId(uploadedLogoId) {
    return uploadedLogoId || null;
  },

  @observes("backgroundImageUrl", "backgroundImageId")
  _setBackgroundUpload() {
    this.set(
      "category.uploaded_background",
      Ember.Object.create({
        id: this.get("backgroundImageId"),
        url: this.get("backgroundImageUrl")
      })
    );
  },

  @observes("logoImageUrl", "logoImageId")
  _setLogoUpload() {
    this.set(
      "category.uploaded_logo",
      Ember.Object.create({
        id: this.get("logoImageId"),
        url: this.get("logoImageUrl")
      })
    );
  }
});
