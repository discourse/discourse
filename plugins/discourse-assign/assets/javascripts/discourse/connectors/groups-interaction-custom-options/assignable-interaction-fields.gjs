import Component from "@glimmer/component";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

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

  <template>
    <div class="control-group">
      <label class="control-label">
        {{i18n "discourse_assign.admin.groups.manage.interaction.assign"}}
      </label>

      <label for="visibility">
        {{i18n
          "discourse_assign.admin.groups.manage.interaction.assignable_levels.title"
        }}
      </label>

      <ComboBox
        @name="alias"
        @valueProperty="value"
        @value={{this.assignableLevel}}
        @content={{this.assignableLevelOptions}}
        @onChange={{this.onChangeAssignableLevel}}
        class="groups-form-assignable-level"
      />
    </div>
  </template>
}
