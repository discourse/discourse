import { alias, not } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";

export default Component.extend({
  classNameBindings: [":popup-tip", "good", "bad", "lastShownAt::hide"],
  attributeBindings: ["role"],
  rerenderTriggers: ["validation.reason"],
  tipReason: null,

  @discourseComputed("bad")
  role(bad) {
    if (bad) {
      return "alert";
    }
  },

  click() {
    this.set("shownAt", null);
    this.set("validation.lastShownAt", null);
  },

  bad: alias("validation.failed"),
  good: not("bad"),

  @discourseComputed("shownAt", "validation.lastShownAt")
  lastShownAt(shownAt, lastShownAt) {
    return shownAt || lastShownAt;
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
