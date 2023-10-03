import BaseField from "./da-base-field";
import Group from "discourse/models/group";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import DAFieldLabel from "./da-field-label";
import DAFieldDescription from "./da-field-description";
import GroupChooser from "select-kit/components/group-chooser";
import { hash } from "@ember/helper";

export default class GroupField extends BaseField {
  <template>
    <section class="field group-field">
      <div class="control-group">
        <DAFieldLabel @label={{@label}} @field={{@field}} />

        <div class="controls">
          <GroupChooser
            @content={{this.allGroups}}
            @value={{@field.metadata.value}}
            @labelProperty="name"
            @onChange={{this.setGroupField}}
            @options={{hash maximum=1 disabled=@field.isDisabled}}
          />

          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>

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

  @action
  setGroupField(groupIds) {
    this.mutValue(groupIds?.firstObject);
  }
}
