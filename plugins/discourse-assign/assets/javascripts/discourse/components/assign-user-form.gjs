import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Assignment from "./assignment";

export default class AssignUserForm extends Component {
  @tracked showValidationErrors = false;

  constructor() {
    super(...arguments);

    this.args.formApi.submit = this.assign;
  }

  get assigneeIsEmpty() {
    return !this.args.model.username && !this.args.model.group_name;
  }

  @action
  async assign() {
    if (this.assigneeIsEmpty) {
      this.showValidationErrors = true;
      return;
    }

    await this.args.onSubmit();
  }

  <template>
    <Assignment
      @assignment={{@model}}
      @onSubmit={{this.assign}}
      @showValidationErrors={{this.showValidationErrors}}
    />
  </template>
}
