import { computed } from "@ember/object";
import RestModel from "discourse/models/rest";
import { i18n } from "discourse-i18n";

export default class GroupHistory extends RestModel {
  @computed("action")
  get actionTitle() {
    return i18n(`group_histories.actions.${this.action}`);
  }
}
