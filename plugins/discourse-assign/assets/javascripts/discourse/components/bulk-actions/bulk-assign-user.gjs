import Component from "@glimmer/component";
import { action } from "@ember/object";
import { trackedObject } from "@ember/reactive/collections";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import AssignUserForm from "discourse/plugins/discourse-assign/discourse/components/assign-user-form";

export default class BulkActionsAssignUser extends Component {
  model = trackedObject({});

  formApi = {
    submit() {},
  };

  @action
  async assign(performAndRefreshCallback) {
    return performAndRefreshCallback({
      type: "assign",
      username: this.model.username,
      status: this.model.status,
      note: this.model.note,
    });
  }

  @action
  performRegistration() {
    this.args.onRegisterAction?.(this.assign.bind(this));
  }

  <template>
    <span {{didInsert this.performRegistration}}></span>
    <AssignUserForm
      @model={{this.model}}
      @onSubmit={{this.assign}}
      @formApi={{this.formApi}}
    />
  </template>
}
