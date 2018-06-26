export default Ember.Controller.extend({
  loadingFlags: null,
  user: null,

  onShow() {
    this.set("loadingFlags", true);
    this.store
      .findAll("flagged-post", {
        filter: "without_custom",
        user_id: this.get("model.id")
      })
      .then(result => {
        this.set("loadingFlags", false);
        console.log(result);
        this.set("flaggedPosts", result);
      });
  }
});
