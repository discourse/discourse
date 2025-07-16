import Component from "@glimmer/component";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";

export default class AssignableInteractionFields extends Component {
  assignableLevelOptions = [
    { name: i18n("groups.alias_levels.nobody"), value: 0 },
    { name: i18n("groups.alias_levels.only_admins"), value: 1 },
    { name: i18n("groups.alias_levels.mods_and_admins"), value: 2 },
    { name: i18n("groups.alias_levels.members_mods_and_admins"), value: 3 },
    { name: i18n("groups.alias_levels.owners_mods_and_admins"), value: 4 },
    { name: i18n("groups.alias_levels.everyone"), value: 99 },
  ];

  get assignableLevel() {
    return this.args.outletArgs.model.get("assignable_level") || 0;
  }

  @action
  onChangeAssignableLevel(level) {
    this.args.outletArgs.model.set("assignable_level", level);
  }
}
