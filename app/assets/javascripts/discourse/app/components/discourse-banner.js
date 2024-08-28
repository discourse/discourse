import Component from "@ember/component";
import { action } from "@ember/object";
import { readOnly } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";

export default class DiscourseBanner extends Component {
  hide = false;

  @readOnly("site.banner") banner;

  @discourseComputed("banner.html")
  content(bannerHtml) {
    const newDiv = document.createElement("div");
    newDiv.innerHTML = bannerHtml;
    newDiv.querySelectorAll("[id^='heading--']").forEach((el) => {
      el.removeAttribute("id");
    });
    return newDiv.innerHTML;
  }

  @discourseComputed("currentUser.dismissed_banner_key", "banner.key", "hide")
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
  }

  @action
  dismiss() {
    if (this.currentUser) {
      this.currentUser.dismissBanner(this.get("banner.key"));
    } else {
      this.set("hide", true);
      this.keyValueStore.set({
        key: "dismissed_banner_key",
        value: this.get("banner.key"),
      });
    }
  }

  didInsertElement() {
    super.didInsertElement(...arguments);
    this.appEvents.trigger("decorate-non-stream-cooked-element", this.element);
  }
}
