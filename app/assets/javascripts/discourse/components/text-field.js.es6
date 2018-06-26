import computed from "ember-addons/ember-computed-decorators";
import { siteDir, isRTL, isLTR } from "discourse/lib/text-direction";

export default Ember.TextField.extend({
  attributeBindings: [
    "autocorrect",
    "autocapitalize",
    "autofocus",
    "maxLength",
    "dir"
  ],

  @computed
  dir() {
    if (this.siteSettings.support_mixed_text_direction) {
      let val = this.value;
      if (val) {
        return isRTL(val) ? "rtl" : "ltr";
      } else {
        return siteDir();
      }
    }
  },

  keyUp(event) {
    this._super(event);

    if (this.siteSettings.support_mixed_text_direction) {
      let val = this.value;
      if (isRTL(val)) {
        this.set("dir", "rtl");
      } else if (isLTR(val)) {
        this.set("dir", "ltr");
      } else {
        this.set("dir", siteDir());
      }
    }
  },

  @computed("placeholderKey")
  placeholder(placeholderKey) {
    return placeholderKey ? I18n.t(placeholderKey) : "";
  }
});
