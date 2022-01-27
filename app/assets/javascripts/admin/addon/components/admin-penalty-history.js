import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  classNames: ["penalty-history"],

  @discourseComputed("user.penalty_counts.suspended")
  suspendedCountClass(count) {
    if (count > 0) {
      return "danger";
    }
    return "";
  },

  @discourseComputed("user.penalty_counts.silenced")
  silencedCountClass(count) {
    if (count > 0) {
      return "danger";
    }
    return "";
  },
});
