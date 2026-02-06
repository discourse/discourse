import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import DSheet from "discourse/float-kit/components/d-sheet";
import DStack from "discourse/float-kit/components/d-stack";
import AssigneesList from "./assignees-list";
import AssignmentForm from "./assignment-form";
import AssignmentsList from "./assignments-list";

export default class AssignTopicSheet extends Component {
  @service taskActions;

  @tracked assignment = this.assignments[0];

  @cached
  get formData() {
    const data = {};

    data.targetId = this.assignment?.targetId;
    data.targetType = this.assignment?.targetType;
    data.assignee = undefined;
    data.note = this.assignment?.note;

    if (this.assignment?.username) {
      data.assignee = {
        username: this.assignment.username,
        avatar_template: this.assignment.avatar_template,
        is_user: true,
      };
    } else if (this.assignment?.groupName) {
      data.assignee = {
        name: this.assignment.groupName,
        is_group: true,
      };
    }

    return data;
  }

  get assignments() {
    return this.args.topic.assignments();
  }

  @action
  async unassign(assignment) {
    await this.taskActions.unassign(assignment.targetId, assignment.targetType);
  }

  @action
  async handleSubmit(data) {
    if (!data.assignee) {
      return;
    }

    const payload = {
      targetId: data.targetId,
      targetType: data.targetType,
      note: data.note,
    };

    if (data.assignee.is_user) {
      payload.username = data.assignee.username;
    }

    if (data.assignee.is_group) {
      payload.group_name = data.assignee.name;
    }

    await this.taskActions.putAssignment(payload);
  }

  @action
  async saveAndDismiss(form, dismiss) {
    await form.submit();
    dismiss?.();
  }

  @action
  onEditAssignment(presentEditSheet, assignment) {
    this.assignment = assignment;
    presentEditSheet?.();
  }

  <template>
    <DStack as |stack|>
      <stack.Trigger class="btn-default" @icon="user-plus">
        Assign
      </stack.Trigger>

      <stack.Content as |content|>
        <Form
          @data={{this.formData}}
          @onSubmit={{this.handleSubmit}}
          @noLayout={{true}}
          as |form data|
        >
          <DSheet.Header @sheet={{content.sheet}}>
            <:left as |Button|>
              <Button.Close />
            </:left>
            <:title>
              Assignments
            </:title>
          </DSheet.Header>

          <content.Stack as |editStack|>
            <AssignmentsList
              @assignments={{this.assignments}}
              @topic={{@topic}}
              @onEditAssignment={{fn this.onEditAssignment editStack.present}}
              @onRemoveAssignment={{this.unassign}}
            />

            <editStack.Content as |editContent|>
              <DSheet.Header @sheet={{editContent.sheet}}>
                <:left as |Button|>
                  <Button.Cancel />
                </:left>
                <:title>
                  Edit Assignment
                </:title>
                <:right as |Button|>
                  <Button @action={{fn this.saveAndDismiss form editContent.dismiss}}>
                    Save
                  </Button>
                </:right>
              </DSheet.Header>

              <editContent.Stack as |assigneesStack|>
                <AssignmentForm
                  @assignment={{this.assignment}}
                  @sheet={{editContent.sheet}}
                  @form={{form}}
                  @data={{data}}
                  @onShowAssigneesList={{assigneesStack.present}}
                />

                <assigneesStack.Content as |assigneesContent|>
                  <DSheet.Header @sheet={{assigneesContent.sheet}}>
                    <:left as |Button|>
                      <Button.Cancel />
                    </:left>
                    <:title>
                      Select Assignee
                    </:title>
                  </DSheet.Header>

                  <AssigneesList
                    @assignment={{this.assignment}}
                    @sheet={{assigneesContent.sheet}}
                    @form={{form}}
                    @data={{data}}
                  />
                </assigneesStack.Content>
              </editContent.Stack>
            </editStack.Content>
          </content.Stack>
        </Form>
      </stack.Content>
    </DStack>
  </template>
}
