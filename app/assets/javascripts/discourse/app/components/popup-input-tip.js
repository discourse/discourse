import { not, or, reads } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { htmlSafe } from "@ember/template";
import { inject as service } from "@ember/service";

export default Component.extend({
  composer: service(),
  tagName: "a",
  classNameBindings: [":popup-tip", "good", "bad", "lastShownAt::hide"],
  attributeBindings: ["role", "ariaLabel", "tabindex"],
  tipReason: null,
  lastShownAt: or("shownAt", "validation.lastShownAt"),
  bad: reads("validation.failed"),
  good: not("bad"),
  tabindex: "0",

  @discourseComputed("bad")
  role(bad) {
    if (bad) {
      return "alert";
    }
  },

  @discourseComputed("validation.reason")
  ariaLabel(reason) {
    return reason?.replace(/(<([^>]+)>)/gi, "");
  },

  dismiss() {
    this.set("shownAt", null);
    this.composer.clearLastValidatedAt();
    this.element.previousElementSibling?.focus();
  },

  click() {
    this.dismiss();
  },

  keyDown(event) {
    if (event.key === "Enter") {
      this.dismiss();
    }
  },

  didReceiveAttrs() {
    this._super(...arguments);
    let reason = this.get("validation.reason");
    if (reason) {
      this.set("tipReason", htmlSafe(`${reason}`));
    } else {
      this.set("tipReason", null);
    }
  },
});
