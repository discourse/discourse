import UploadMixin from "discourse/mixins/upload";

export default Ember.Component.extend(UploadMixin, {
  type: "emoji",
  uploadUrl: "/admin/customize/emojis",

  hasName: Ember.computed.notEmpty("name"),
  addDisabled: Ember.computed.not("hasName"),

  data: function() {
    return Ember.isBlank(this.get("name")) ? {} : { name: this.get("name") };
  }.property("name"),

  validateUploadedFilesOptions() {
    return { imagesOnly: true };
  },

  uploadDone(upload) {
    this.set("name", null);
    this.done(upload);
  }
});
