import { default as computed } from "ember-addons/ember-computed-decorators";
import UploadMixin from "discourse/mixins/upload";

export default Ember.Component.extend(UploadMixin, {
  type: "emoji",
  uploadUrl: "/admin/customize/emojis",
  hasName: Ember.computed.notEmpty("name"),
  addDisabled: Ember.computed.not("hasName"),

  @computed("hasName", "name")
  data(hasName, name) {
    return hasName ? { name } : {};
  },

  validateUploadedFilesOptions() {
    return { imagesOnly: true };
  },

  uploadDone(upload) {
    this.set("name", null);
    this.done(upload);
  }
});
