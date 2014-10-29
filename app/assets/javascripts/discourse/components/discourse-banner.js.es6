import VisibleComponent from "discourse/components/visible";

export default VisibleComponent.extend({

  visible: function () {
    var bannerKey = this.get("banner.key"),
        dismissedBannerKey = this.get("user.dismissed_banner_key") ||
                             Discourse.KeyValueStore.get("dismissed_banner_key");

    if (bannerKey) { bannerKey = parseInt(bannerKey, 10); }
    if (dismissedBannerKey) { dismissedBannerKey = parseInt(dismissedBannerKey, 10); }

    return bannerKey && dismissedBannerKey !== bannerKey;
  }.property("user.dismissed_banner_key", "banner.key"),

  actions: {
    dismiss: function () {
      if (this.get("user")) {
        this.get("user").dismissBanner(this.get("banner.key"));
      } else {
        this.set("visible", false);
        Discourse.KeyValueStore.set({ key: "dismissed_banner_key", value: this.get("banner.key") });
      }
    }
  },


});
