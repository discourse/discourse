import { computed } from "@ember/object";
import RestModel from "discourse/models/rest";
import { i18n } from "discourse-i18n";

export function badgeGroupingDisplayName(name) {
  const i18nKey = `badges.badge_grouping.${name.toLowerCase().replace(/\s/g, "_")}.name`;
  return i18n(i18nKey, { defaultValue: name });
}

export default class BadgeGrouping extends RestModel {
  @computed("name")
  get i18nNameKey() {
    return this.name.toLowerCase().replace(/\s/g, "_");
  }

  @computed("name")
  get displayName() {
    return badgeGroupingDisplayName(this.name);
  }
}
