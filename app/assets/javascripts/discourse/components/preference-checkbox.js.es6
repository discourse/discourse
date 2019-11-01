import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";

export default Component.extend({
  classNames: ["controls"],

  @computed("labelKey")
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
