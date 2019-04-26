import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  @computed("user.dismissed_banner_key", "banner.key", "hide")
  visible(dismissedBannerKey, bannerKey, hide) {
    dismissedBannerKey =
      dismissedBannerKey || this.keyValueStore.get("dismissed_banner_key");

    if (bannerKey) {
      bannerKey = parseInt(bannerKey, 10);
    }
    if (dismissedBannerKey) {
      dismissedBannerKey = parseInt(dismissedBannerKey, 10);
    }

    return !hide && bannerKey && dismissedBannerKey !== bannerKey;
  },

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
