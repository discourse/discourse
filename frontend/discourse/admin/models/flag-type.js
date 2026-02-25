import { computed } from "@ember/object";
import RestModel from "discourse/models/rest";
import { i18n } from "discourse-i18n";

export default class FlagType extends RestModel {
  @computed("id")
  get name() {
    return i18n(`admin.flags.summary.action_type_${this.id}`, { count: 1 });
  }
}
