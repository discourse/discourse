import { alias, not, or } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { getOwner } from "discourse-common/lib/get-owner";

export default Component.extend({
  classNameBindings: [":popup-tip", "good", "bad", "lastShownAt::hide"],
  attributeBindings: ["role"],
  rerenderTriggers: ["validation.reason"],
  tipReason: null,
  lastShownAt: or("shownAt", "validation.lastShownAt"),
  bad: alias("validation.failed"),
  good: not("bad"),

  @discourseComputed("bad")
  role(bad) {
    if (bad) {
      return "alert";
    }
  },

  click() {
    this.set("shownAt", null);
    const composer = getOwner(this).lookup("controller:composer");
    composer.clearLastValidatedAt();
  },

  didReceiveAttrs() {
    this._super(...arguments);
    let reason = this.get("validation.reason");
    if (reason) {
      this.set("tipReason", `${reason}`.htmlSafe());
    } else {
      this.set("tipReason", null);
    }
  },
});
