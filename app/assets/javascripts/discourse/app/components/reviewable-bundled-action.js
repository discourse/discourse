import { alias, gt } from "@ember/object/computed";
import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { isRTL } from "discourse/lib/text-direction";

export default Component.extend({
  tagName: "",

  multiple: gt("bundle.actions.length", 1),
  first: alias("bundle.actions.firstObject"),

  @discourseComputed()
  placement() {
    const vertical = this.site.mobileView ? "top" : "bottom",
      horizontal = isRTL() ? "end" : "start";
    return `${vertical}-${horizontal}`;
  },

  actions: {
    performById(id) {
      this.attrs.performAction(this.get("bundle.actions").findBy("id", id));
    },

    perform(action) {
      this.attrs.performAction(action);
    },
  },
});
