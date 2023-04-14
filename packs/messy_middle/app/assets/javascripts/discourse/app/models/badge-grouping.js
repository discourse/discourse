import I18n from "I18n";
import RestModel from "discourse/models/rest";
import discourseComputed from "discourse-common/utils/decorators";

export default RestModel.extend({
  @discourseComputed("name")
  i18nNameKey() {
    return this.name.toLowerCase().replace(/\s/g, "_");
  },

  @discourseComputed("name")
  displayName() {
    const i18nKey = `badges.badge_grouping.${this.i18nNameKey}.name`;
    return I18n.t(i18nKey, { defaultValue: this.name });
  },
});
