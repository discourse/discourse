export default Ember.Component.extend({
  visible: function() {
    var bannerKey = this.get("banner.key"),
      dismissedBannerKey =
        this.get("user.dismissed_banner_key") ||
        this.keyValueStore.get("dismissed_banner_key");

    if (bannerKey) {
      bannerKey = parseInt(bannerKey, 10);
    }
    if (dismissedBannerKey) {
      dismissedBannerKey = parseInt(dismissedBannerKey, 10);
    }

    return !this.get("hide") && bannerKey && dismissedBannerKey !== bannerKey;
  }.property("user.dismissed_banner_key", "banner.key", "hide"),

  actions: {
    dismiss() {
      if (this.get("user")) {
        this.get("user").dismissBanner(this.get("banner.key"));
      } else {
        this.set("visible", false);
        this.keyValueStore.set({
          key: "dismissed_banner_key",
          value: this.get("banner.key")
        });
      }
    }
  }
});
