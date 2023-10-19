import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

export default Component.extend({
  classNames: ["controls"],

  @discourseComputed("labelKey", "labelCount")
  label(labelKey, labelCount) {
    if (labelCount) {
      return I18n.t(labelKey, { count: labelCount });
    } else {
      return I18n.t(labelKey);
    }
  },

  change() {
    const warning = this.warning;

    if (warning && this.checked) {
      this.warning();
      return false;
    }

    return true;
  },
});
