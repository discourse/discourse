import UploadMixin from "discourse/mixins/upload";

export default Em.Component.extend(UploadMixin, {
  classNames: ["image-uploader"],

  backgroundStyle: function() {
    const imageUrl = this.get("imageUrl");
    if (Em.isNone(imageUrl)) { return; }
    return ("background-image: url(" + imageUrl + ")").htmlSafe();
  }.property("imageUrl"),

  uploadDone(upload) {
    this.set("imageUrl", upload.url);
  },

  actions: {
    trash() {
      this.set("imageUrl", null);
    }
  }
});
