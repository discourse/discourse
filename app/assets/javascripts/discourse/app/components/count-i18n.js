import Component from "@ember/component";
import I18n from "I18n";
import { htmlSafe } from "@ember/template";

export default Component.extend({
  tagName: "span",
  i18nCount: null,

  didReceiveAttrs() {
    this._super(...arguments);

    let fullKey = this.key + (this.suffix || "");
    if (
      this.currentUser?.new_new_view_enabled &&
      fullKey === "topic_count_new"
    ) {
      fullKey = "topic_count_latest";
    }
    this.set("i18nCount", htmlSafe(I18n.t(fullKey, { count: this.count })));
  },
});
