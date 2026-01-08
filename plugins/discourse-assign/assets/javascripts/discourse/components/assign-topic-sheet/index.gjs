import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
// import { guidFor } from "@ember/object/internals";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import Form from "discourse/components/form";
import DSheet from "discourse/float-kit/components/d-sheet";
import TrackedMediaQuery from "discourse/lib/tracked-media-query";
import AssigneesList from "./assignees-list";
import AssignmentForm from "./assignment-form";
import AssignmentsList from "./assignments-list";

export default class AssignTopicSheet extends Component {
  @service taskActions;

  @tracked sheetPresented = false;
  @tracked nestedSheetPresented = false;

  @tracked assignment = this.assignments[0];

  largeViewport = new TrackedMediaQuery("(min-width: 700px)");

  componentId = "test"; //guidFor(this);

  willDestroy() {
    super.willDestroy(...arguments);
    this.largeViewport.teardown();
  }

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
    } else if (this.assignment?.name) {
      data.assignee = {
        name: this.assignment.name,
        is_group: true,
      };
    }

    return data;
  }

  get tracks() {
    return this.largeViewport.matches ? "right" : "bottom";
  }

  get assignments() {
    return this.args.topic.assignments();
  }

  @action
  async assign() {
    await this.taskActions.putAssignment(this.assignment);
  }

  @action
  async unassign() {
    await this.taskActions.unassign(
      this.assignment.targetId,
      this.assignment.targetType
    );
  }

  get stackingAnimation() {
    return this.tracks === "right"
      ? {
          translateX: ({ progress }) =>
            progress <= 1
              ? progress * -10 + "px"
              : `calc(-12.5px + 2.5px * ${progress})`,
          scale: [1, 0.933],
          transformOrigin: "0 50%",
        }
      : {
          translateY: ({ progress }) =>
            progress <= 1
              ? progress * -10 + "px"
              : `calc(-12.5px + 2.5px * ${progress})`,
          scale: [1, 0.933],
          transformOrigin: "50% 0",
        };
  }

  @action
  async onSelectAssignee(assignee) {
    if (!assignee) {
      await this.unassign();
      this.sheetPresented = false;
      return;
    }

    let name;
    if (assignee.isGroup) {
      name = assignee.name;
    } else {
      name = assignee.username;
    }

    if (this.taskActions.allowedGroupsForAssignment.includes(name)) {
      this.assignment.username = null;
      this.assignment.avatar_template = null;
      this.assignment.group_name = name;
    } else {
      this.assignment.username = name;
      this.assignment.avatar_template = assignee.avatar_template;
      this.assignment.group_name = null;
    }
    this.assignment.isEdited = true;

    this.nestedSheetPresented = false;
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

    this.sheetPresented = false;
  }

  @action
  onSelectAssignment(assignment) {
    this.assignment = assignment;
  }

  @action
  onSheetPresentedChange(presented) {
    this.sheetPresented = presented;

    if (!presented) {
      this.assignment = null;
    }
  }

  get selectedAssigneeName() {
    if (!this.selectedAssignee) {
      return "";
    }
    return this.selectedAssignee.isUser
      ? this.selectedAssignee.username
      : this.selectedAssignee.name;
  }

  <template>
    <DSheet.Stack.Root as |stack|>
      <DSheet.Root
        @presented={{this.sheetPresented}}
        @onPresentedChange={{this.onSheetPresentedChange}}
        @componentId={{this.componentId}}
        @forComponent={{stack.stackId}}
        as |sheet|
      >
        <DButton
          class="btn-default"
          @action={{fn (mut this.sheetPresented) true}}
          @icon="user-plus"
          @translatedLabel="Assign"
        />

        <DSheet.Portal @sheet={{sheet}}>
          <DSheet.View
            class="assign-sheet__view"
            @swipeOvershoot={{false}}
            @sheet={{sheet}}
            @tracks={{this.tracks}}
            @inertOutside={{false}}
            ...attributes
          >
            <DSheet.Content
              @stackingAnimation={{this.stackingAnimation}}
              class="assign-sheet__content"
              @sheet={{sheet}}
            >
              <div class="assign-sheet__inner-content">
                <Form
                  @data={{this.formData}}
                  @onSubmit={{this.handleSubmit}}
                  @noLayout={{true}}
                  as |form data|
                >
                  <DSheet.Header @sheet={{sheet}}>
                    <:left as |Button|>
                      <Button.Close />
                    </:left>
                    <:title>
                      Assign
                    </:title>
                    <:right as |Button|>
                      <Button @action={{form.submit}}>Save</Button>
                    </:right>
                  </DSheet.Header>

                  <AssigneesList
                    @assignment={{this.assignment}}
                    @form={{form}}
                    @data={{data}}
                  />

                  {{#if this.assignment}}
                    <AssignmentForm
                      @sheet={{sheet}}
                      @form={{form}}
                      @data={{data}}
                      @onShowAssigneesList={{fn
                        (mut this.nestedSheetPresented)
                        true
                      }}
                      @onSelectAssignee={{this.onSelectAssignee}}
                    />
                  {{else}}
                    <AssignmentsList
                      @assignments={{this.assignments}}
                      @onSelectAssignment={{this.onSelectAssignment}}
                    />
                  {{/if}}

                  <DSheet.Root
                    @presented={{this.nestedSheetPresented}}
                    @onPresentedChange={{fn (mut this.nestedSheetPresented)}}
                    @forComponent={{stack.stackId}}
                    as |nestedSheet|
                  >
                    <DSheet.Portal @sheet={{nestedSheet}}>
                      <DSheet.View
                        class="assign-sheet__view"
                        @sheet={{nestedSheet}}
                        @tracks={{this.tracks}}
                        @inertOutside={{false}}
                      >
                        <DSheet.Content
                          @sheet={{nestedSheet}}
                          @stackingAnimation={{this.stackingAnimation}}
                          class="assign-sheet__content"
                        >
                          <div
                            class="assign-sheet__inner-content assign-sheet__inner-content--nested"
                          >
                            <DSheet.Header @sheet={{nestedSheet}}>
                              <:left as |Button|>
                                <Button.Cancel />
                              </:left>
                              <:title>
                                Assign
                              </:title>
                              <:right as |Button|>
                                <Button
                                  @action={{fn
                                    this.assign
                                    this.selectedAssignee
                                  }}
                                />
                              </:right>
                            </DSheet.Header>

                            <AssigneesList
                              @assignment={{this.assignment}}
                              @sheet={{nestedSheet}}
                              @form={{form}}
                              @data={{data}}
                            />
                          </div>
                        </DSheet.Content>
                      </DSheet.View>
                    </DSheet.Portal>
                  </DSheet.Root>
                </Form>
              </div>

            </DSheet.Content>
          </DSheet.View>
        </DSheet.Portal>
      </DSheet.Root>
    </DSheet.Stack.Root>
  </template>
}
