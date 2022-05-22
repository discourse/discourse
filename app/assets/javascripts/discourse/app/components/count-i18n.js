import Component from "@ember/component";
import I18n from "I18n";
import { htmlSafe } from "@ember/template";

export default Component.extend({
  tagName: "span",
  rerenderTriggers: ["count", "suffix"],
  i18nCount: null,

  didReceiveAttrs() {
    this._super(...arguments);
    this.set(
      "i18nCount",
      htmlSafe(I18n.t(this.key + (this.suffix || ""), { count: this.count }))
    );
  },
});
