import Component from "@glimmer/component";
import { action } from "@ember/object";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import DButton from "discourse/components/d-button";
import AssignUserForm from "../assign-user-form";

export default class AssignUser extends Component {
  model = new TrackedObject({});

  // `submit` property will be mutated by the `AssignUserForm` component
  formApi = {
    submit() {},
  };

  @action
  async assign() {
    return this.args.performAndRefresh({
      type: "assign",
      username: this.model.username,
      status: this.model.status,
      note: this.model.note,
    });
  }

  <template>
    <div>
      <AssignUserForm
        @model={{this.model}}
        @onSubmit={{this.assign}}
        @formApi={{this.formApi}}
      />
    </div>

    <div>
      <DButton
        class="btn-primary"
        @action={{this.formApi.submit}}
        @label={{if
          this.model.reassign
          "discourse_assign.reassign.title"
          "discourse_assign.assign_modal.assign"
        }}
      />
    </div>
  </template>
}
