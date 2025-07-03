import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { isBlank } from "@ember/utils";
import Group from "discourse/models/group";
import GroupChooser from "select-kit/components/group-chooser";
import BaseField from "./da-base-field";
import DAFieldDescription from "./da-field-description";
import DAFieldLabel from "./da-field-label";

export default class GroupsField extends BaseField {
  @tracked allGroups = [];

  constructor() {
    super(...arguments);

    Group.findAll({
      ignore_automatic: this.args.field.extra.ignore_automatic ?? false,
    }).then((groups) => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.allGroups = groups;
    });
  }

  get maximum() {
    return this.args.field.extra.maximum ?? 10;
  }

  @action
  setGroupField(groupIds) {
    if (isBlank(groupIds)) {
      groupIds = undefined;
    }

    this.mutValue(groupIds);
  }

  <template>
    <section class="field group-field">
      <div class="control-group">
        <DAFieldLabel @label={{@label}} @field={{@field}} />

        <div class="controls">
          <GroupChooser
            @content={{this.allGroups}}
            @value={{readonly @field.metadata.value}}
            @labelProperty="name"
            @onChange={{this.setGroupField}}
            @options={{hash maximum=this.maximum disabled=@field.isDisabled}}
          />

          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>
}
