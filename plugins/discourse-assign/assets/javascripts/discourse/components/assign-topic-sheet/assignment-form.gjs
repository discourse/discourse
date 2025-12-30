import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AssigneeRow from "./assignee-row";

export default class AssignmentForm extends Component {
  @service taskActions;

  @action
  async removeAssignee() {
    this.args.form.set("assignee", undefined);

    await this.taskActions.unassign(
      this.args.data.targetId,
      this.args.data.targetType
    );

    this.args.sheet.close();
  }

  <template>
    <div class="assign-sheet__nested-form">
      {{!-- {{#if @data.assignee}}
        <AssigneeRow @onPress={{this.removeAssignee}}>
          Unassign
          {{@data.assignee.username}}
        </AssigneeRow>
      {{/if}}

      <AssigneeRow
        @assignee={{@data.assignee}}
        @onPress={{@onShowAssigneesList}}
        @disclosureIndicatorIcon="chevron-right"
      >
        Choose assignee...
      </AssigneeRow> --}}

      <@form.Field @name="note" @title="note" @showTitle={{false}} as |field|>
        <field.Textarea placeholder="Optional note" class="--no-resize" />
      </@form.Field>
    </div>
  </template>
}
