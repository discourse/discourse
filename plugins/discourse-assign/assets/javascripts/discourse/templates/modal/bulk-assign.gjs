import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import AssignUserForm from "../../components/assign-user-form";

export default RouteTemplate(
  <template>
    <div>
      <AssignUserForm
        @model={{@controller.model}}
        @onSubmit={{@controller.assign}}
        @formApi={{@controller.formApi}}
      />
    </div>

    <div>
      <DButton
        class="btn-primary"
        @action={{@controller.formApi.submit}}
        @label={{if
          @controller.model.reassign
          "discourse_assign.reassign.title"
          "discourse_assign.assign_modal.assign"
        }}
      />
    </div>
  </template>
);
