import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  hide: false,

  @discourseComputed("banner.html")
  content(bannerHtml) {
    const $div = $("<div>");
    $div.append(bannerHtml);
    $div.find("[id^='heading--']").removeAttr("id");
    return $div.html();
  },

  @discourseComputed("user.dismissed_banner_key", "banner.key", "hide")
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
      if (this.user) {
        this.user.dismissBanner(this.get("banner.key"));
      } else {
        this.set("hide", true);
        this.keyValueStore.set({
          key: "dismissed_banner_key",
          value: this.get("banner.key"),
        });
      }
    },
  },
});
