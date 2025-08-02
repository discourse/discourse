import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import Assignment from "./assignment";

export default class TopicAssignments extends Component {
  @tracked selectedAssignment = this.args.assignments.find((a) => a.id === 0);

  get assignmentOptions() {
    return this.args.assignments.map((a) => this.#toComboBoxOption(a));
  }

  @action
  selectAssignment(id) {
    this.selectedAssignment = this.args.assignments.find((a) => a.id === id);
  }

  #toComboBoxOption(assignment) {
    const option = { id: assignment.id };
    if (assignment.targetType === "Topic") {
      option.name = i18n("edit_assignments_modal.topic");
    } else {
      option.name = `${i18n("edit_assignments_modal.post")} #${
        assignment.postNumber
      }`;
    }
    return option;
  }

  <template>
    <div class="control-group target">
      <label>{{i18n "discourse_assign.assign_modal.assignment_label"}}</label>
      <ComboBox
        @value={{this.selectedAssignment.id}}
        @content={{this.assignmentOptions}}
        @onChange={{this.selectAssignment}}
      />
    </div>
    <Assignment
      @assignment={{this.selectedAssignment}}
      @onSubmit={{@onSubmit}}
      @showValidationErrors={{false}}
    />
  </template>
}
