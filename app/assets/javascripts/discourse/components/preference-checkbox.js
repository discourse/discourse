import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";

export default Component.extend({
  classNames: ["controls"],

  @discourseComputed("labelKey")
  label(labelKey) {
    return I18n.t(labelKey);
  },

  change() {
    const warning = this.warning;

    if (warning && this.checked) {
      this.warning();
      return false;
    }

    return true;
  }
});
