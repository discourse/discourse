import UploadMixin from "discourse/mixins/upload";

export default Em.Component.extend(UploadMixin, {
  type: "emoji",
  uploadUrl: "/admin/customize/emojis",

  hasName: Em.computed.notEmpty("name"),
  addDisabled: Em.computed.not("hasName"),

  data: function() {
    return Ember.isBlank(this.get("name")) ? {} : { name: this.get("name") };
  }.property("name"),

  validateUploadedFilesOptions() {
    return { imagesOnly: true };
  },

  uploadDone(upload) {
    this.set("name", null);
    this.sendAction("done", upload);
  }
});
