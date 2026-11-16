import { computed } from "@ember/object";
import RestModel from "discourse/models/rest";
import { i18n } from "discourse-i18n";

export interface FlagTypeFields {
  id?: number | string;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface FlagType extends FlagTypeFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class FlagType extends RestModel {
  @computed("id")
  get name(): string {
    return i18n(`admin.flags.summary.action_type_${this.id}`, { count: 1 });
  }
}
