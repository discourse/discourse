import { computed } from "@ember/object";
import RestModel from "discourse/models/rest";
import { i18n } from "discourse-i18n";

export function badgeGroupingDisplayName(name: string): string {
  const i18nKey = `badges.badge_grouping.${name.toLowerCase().replace(/\s/g, "_")}.name`;
  return i18n(i18nKey, { defaultValue: name });
}

/** Serialized grouping data, plus the edit modal's optional row state. */
export interface BadgeGroupingFields {
  id: number;
  name: string;
  description: string | null;
  position: number;
  system: boolean;
  editing?: boolean;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface BadgeGrouping extends BadgeGroupingFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class BadgeGrouping extends RestModel {
  @computed("name")
  get i18nNameKey(): string {
    return this.name.toLowerCase().replace(/\s/g, "_");
  }

  @computed("name")
  get displayName(): string {
    return badgeGroupingDisplayName(this.name);
  }
}
