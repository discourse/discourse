import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import UserChooser from "discourse/select-kit/components/user-chooser";
import { i18n } from "discourse-i18n";
import ErrorWorkflowChooser from "./error-workflow-chooser";

export default class WorkflowSettings extends Component {
  @service router;
  @service dialog;
  @service toasts;

  formData = {
    run_as_username: this.args.workflow.run_as_username ?? "system",
    error_workflow_id: this.args.workflow.error_workflow_id,
  };

  errorWorkflowContent =
    this.args.workflow.error_workflow_id &&
    this.args.workflow.error_workflow_name
      ? [
          {
            id: this.args.workflow.error_workflow_id,
            name: this.args.workflow.error_workflow_name,
          },
        ]
      : [];

  @action
  async deleteWorkflow() {
    await this.dialog.deleteConfirm({
      message: i18n("discourse_workflows.delete_confirm", {
        name: this.args.workflow.name,
      }),
      didConfirm: async () => {
        await this.args.workflow.destroyRecord();
        this.router.transitionTo("adminPlugins.show.discourse-workflows.index");
      },
    });
  }

  @action
  async submitForm(name, value, data) {
    try {
      await ajax(
        `/admin/plugins/discourse-workflows/workflows/${this.args.workflow.id}.json`,
        {
          type: "PUT",
          data: {
            workflow: {
              name: this.args.workflow.name,
              run_as_username: Array.isArray(data.run_as_username)
                ? data.run_as_username[0] || "system"
                : data.run_as_username || "system",
              error_workflow_id: data.error_workflow_id,
            },
          },
        }
      );

      this.toasts.success({
        duration: "short",
        data: { message: i18n("discourse_workflows.settings.saved") },
      });
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <Form
      @onSet={{this.submitForm}}
      @data={{this.formData}}
      class="workflows-settings"
      as |form|
    >
      <form.Field
        @name="run_as_username"
        @title={{i18n "discourse_workflows.settings.run_as"}}
        @description={{i18n "discourse_workflows.settings.run_as_description"}}
        @type="custom"
        @format="full"
        as |field|
      >
        <field.Control>
          <UserChooser
            @value={{field.value}}
            @onChange={{field.set}}
            @options={{hash maximum=1 excludeCurrentUser=false}}
          />
        </field.Control>
      </form.Field>

      <form.Field
        @name="error_workflow_id"
        @title={{i18n "discourse_workflows.settings.error_workflow"}}
        @description={{i18n
          "discourse_workflows.settings.error_workflow_description"
        }}
        @type="custom"
        @format="full"
        as |field|
      >
        <field.Control>
          <ErrorWorkflowChooser
            @content={{this.errorWorkflowContent}}
            @value={{field.value}}
            @onChange={{field.set}}
            @options={{hash
              none="discourse_workflows.settings.error_workflow_none"
              excludeWorkflowId=@workflow.id
            }}
          />
        </field.Control>
      </form.Field>

      <form.Emphasis
        @title={{i18n "discourse_workflows.settings.danger_zone"}}
        @subtitle={{i18n "discourse_workflows.settings.delete_description"}}
        @type="error"
      >
        <form.Actions>
          <form.Button
            @label="discourse_workflows.delete"
            @action={{this.deleteWorkflow}}
            class="btn-danger"
          />
        </form.Actions>
      </form.Emphasis>
    </Form>
  </template>
}
