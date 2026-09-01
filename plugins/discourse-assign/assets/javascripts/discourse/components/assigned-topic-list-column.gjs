import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AssignActionsDropdown from "./assign-actions-dropdown";

export default class AssignedTopicListColumn extends Component {
  @service taskActions;
  @service router;

  @action
  async unassign(targetId, targetType = "Topic") {
    await this.taskActions.unassign(targetId, targetType);
    this.router.refresh();
  }

  @action
  reassign(topic) {
    this.taskActions.showAssignModal(topic, {
      onSuccess: () => this.router.refresh(),
    });
  }

  <template>
    {{#if @topic.assigned_to_user}}
      <AssignActionsDropdown
        @assignee={{@topic.assigned_to_user.username}}
        @reassign={{this.reassign}}
        @topic={{@topic}}
        @unassign={{this.unassign}}
      />
    {{else if @topic.assigned_to_group}}
      <AssignActionsDropdown
        @assignee={{@topic.assigned_to_group.name}}
        @group={{true}}
        @reassign={{this.reassign}}
        @topic={{@topic}}
        @unassign={{this.unassign}}
      />
    {{else}}
      <AssignActionsDropdown @topic={{@topic}} @unassign={{this.unassign}} />
    {{/if}}
  </template>
}
