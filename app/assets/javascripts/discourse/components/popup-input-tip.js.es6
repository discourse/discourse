import { alias, not } from "@ember/object/computed";
import Component from "@ember/component";
import { iconHTML } from "discourse-common/lib/icon-library";
import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";
import { bufferedRender } from "discourse-common/lib/buffered-render";

export default Component.extend(
  bufferedRender({
    classNameBindings: [":popup-tip", "good", "bad", "lastShownAt::hide"],
    animateAttribute: null,
    bouncePixels: 6,
    bounceDelay: 100,
    rerenderTriggers: ["validation.reason"],

    click() {
      this.set("shownAt", null);
      this.set("validation.lastShownAt", null);
    },

    bad: alias("validation.failed"),
    good: not("bad"),

    @computed("shownAt", "validation.lastShownAt")
    lastShownAt(shownAt, lastShownAt) {
      return shownAt || lastShownAt;
    },

    @observes("lastShownAt")
    bounce() {
      if (this.lastShownAt) {
        var $elem = $(this.element);
        if (!this.animateAttribute) {
          this.animateAttribute =
            $elem.css("left") === "auto" ? "right" : "left";
        }
        if (this.animateAttribute === "left") {
          this.bounceLeft($elem);
        } else {
          this.bounceRight($elem);
        }
      }
    },

    buildBuffer(buffer) {
      const reason = this.get("validation.reason");
      if (!reason) {
        return;
      }

      buffer.push(
        `<span class='close'>${iconHTML("times-circle")}</span>${reason}`
      );
    },

    bounceLeft($elem) {
      for (var i = 0; i < 5; i++) {
        $elem
          .animate({ left: "+=" + this.bouncePixels }, this.bounceDelay)
          .animate({ left: "-=" + this.bouncePixels }, this.bounceDelay);
      }
    },

    bounceRight($elem) {
      for (var i = 0; i < 5; i++) {
        $elem
          .animate({ right: "-=" + this.bouncePixels }, this.bounceDelay)
          .animate({ right: "+=" + this.bouncePixels }, this.bounceDelay);
      }
    }
  })
);
