import { alias, not } from "@ember/object/computed";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { iconHTML } from "discourse-common/lib/icon-library";

export default Component.extend({
  classNameBindings: [":popup-tip", "good", "bad", "lastShownAt::hide"],
  attributeBindings: ["role"],
  animateAttribute: null,
  bouncePixels: 6,
  bounceDelay: 100,
  rerenderTriggers: ["validation.reason"],
  closeIcon: `${iconHTML("times-circle")}`.htmlSafe(),
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

  @observes("lastShownAt")
  bounce() {
    if (this.lastShownAt) {
      let $elem = $(this.element);
      if (!this.animateAttribute) {
        this.animateAttribute = $elem.css("left") === "auto" ? "right" : "left";
      }
      if (this.animateAttribute === "left") {
        this.bounceLeft($elem);
      } else {
        this.bounceRight($elem);
      }
    }
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

  bounceLeft($elem) {
    for (let i = 0; i < 5; i++) {
      $elem
        .animate({ left: "+=" + this.bouncePixels }, this.bounceDelay)
        .animate({ left: "-=" + this.bouncePixels }, this.bounceDelay);
    }
  },

  bounceRight($elem) {
    for (let i = 0; i < 5; i++) {
      $elem
        .animate({ right: "-=" + this.bouncePixels }, this.bounceDelay)
        .animate({ right: "+=" + this.bouncePixels }, this.bounceDelay);
    }
  },
});
