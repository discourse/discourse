import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { action } from "@ember/object";

export default Component.extend({
  hide: false,

  @discourseComputed("banner.html")
  content(bannerHtml) {
    const newDiv = document.createElement("div");
    newDiv.innerHTML = bannerHtml;
    newDiv.querySelectorAll("[id^='heading--']").forEach((el) => {
      el.removeAttribute("id");
    });
    return newDiv.innerHTML;
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

  @action
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
});
