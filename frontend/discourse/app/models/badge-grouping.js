import { computed } from "@ember/object";
import RestModel from "discourse/models/rest";
import { i18n } from "discourse-i18n";

export default class BadgeGrouping extends RestModel {
  @computed("name")
  get i18nNameKey() {
    return this.name.toLowerCase().replace(/\s/g, "_");
  }

  @computed("name")
  get displayName() {
    const i18nKey = `badges.badge_grouping.${this.i18nNameKey}.name`;
    return i18n(i18nKey, { defaultValue: this.name });
  }
}
