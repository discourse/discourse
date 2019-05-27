import computed from "ember-addons/ember-computed-decorators";
import RestModel from "discourse/models/rest";

export default RestModel.extend({
  @computed("name")
  i18nNameKey() {
    return this.name
      .toLowerCase()
      .replace(/\s/g, "_");
  },

  @computed("name")
  displayName() {
    const i18nKey = `badges.badge_grouping.${this.i18nNameKey}.name`;
    return I18n.t(i18nKey, { defaultValue: this.name });
  }
});
