import discourseComputed from "discourse-common/utils/decorators";
import { siteDir, isRTL, isLTR } from "discourse/lib/text-direction";

export default Ember.TextField.extend({
  attributeBindings: [
    "autocorrect",
    "autocapitalize",
    "autofocus",
    "maxLength",
    "dir"
  ],

  @discourseComputed
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

  @discourseComputed("placeholderKey")
  placeholder: {
    get() {
      if (this._placeholder) return this._placeholder;
      return this.placeholderKey ? I18n.t(this.placeholderKey) : "";
    },
    set(value) {
      return (this._placeholder = value);
    }
  }
});
