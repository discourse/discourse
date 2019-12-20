import { reads, not } from "@ember/object/computed";
import Component from "@ember/component";
import { iconHTML } from "discourse-common/lib/icon-library";

export default Component.extend({
  tipIcon: null,
  tipReason: null,
  tagName: "",
  bad: reads("validation.failed"),
  good: not("bad"),

  tipIconHTML() {
    return iconHTML(this.good ? "check" : "times").htmlSafe();
  },

  didReceiveAttrs() {
    this._super(...arguments);

    const tipReason = this.get("validation.reason");
    if (tipReason) {
      this.setProperties({
        tipIcon: this.tipIconHTML(),
        tipReason
      });
    } else {
      this.setProperties({
        tipIcon: null,
        tipReason: null
      });
    }
  }
});
