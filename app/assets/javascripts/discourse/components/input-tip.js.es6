import { alias, not } from "@ember/object/computed";
import Component from "@ember/component";
import { iconHTML } from "discourse-common/lib/icon-library";

export default Component.extend({
  classNameBindings: [":tip", "good", "bad"],
  tipIcon: null,
  tipReason: null,

  bad: alias("validation.failed"),
  good: not("bad"),

  tipIconHTML() {
    let icon = iconHTML(this.good ? "check" : "times");
    return `${icon}`.htmlSafe();
  },

  didReceiveAttrs() {
    this._super(...arguments);
    let reason = this.get("validation.reason");
    if (reason) {
      this.set("tipIcon", this.tipIconHTML());
      this.set("tipReason", reason);
    } else {
      this.set("tipIcon", null);
      this.set("tipReason", null);
    }
  }
});
