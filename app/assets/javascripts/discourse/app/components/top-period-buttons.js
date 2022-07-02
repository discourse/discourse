import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "",

  @discourseComputed("period")
  periods(period) {
    return this.site.get("periods").filter((p) => p !== period);
  },

  actions: {
    changePeriod(p) {
      this.action(p);
    },
  },
});
