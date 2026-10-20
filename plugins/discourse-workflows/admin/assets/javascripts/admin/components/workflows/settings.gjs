import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import TimezoneInput from "discourse/select-kit/components/timezone-input";
import { i18n } from "discourse-i18n";
import confirmDeleteWorkflow from "../../lib/workflows/confirm-delete-workflow.js";
import ErrorWorkflowChooser from "./error-workflow-chooser.js";

export default class WorkflowSettings extends Component {
  @service router;
  @service dialog;
  @service toasts;

  formData = {
    errorWorkflowId: this.args.workflow.errorWorkflowId,
    timezone: this.args.workflow.timezone || "UTC",
  };

  errorWorkflowContent =
    this.args.workflow.errorWorkflowId && this.args.workflow.errorWorkflowName
      ? [
          {
            id: this.args.workflow.errorWorkflowId,
            name: this.args.workflow.errorWorkflowName,
          },
        ]
      : [];

  @action
  async deleteWorkflow() {
    await confirmDeleteWorkflow(this.dialog, this.args.workflow, {
      onDeleted: () =>
        this.router.transitionTo("adminPlugins.show.discourse-workflows.index"),
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
              error_workflow_id: data.errorWorkflowId,
              timezone: data.timezone,
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
      class="workflows-settings"
      @data={{this.formData}}
      @onSet={{this.submitForm}}
      as |form|
    >
      <form.Field
        @description={{i18n
          "discourse_workflows.settings.error_workflow_description"
        }}
        @format="full"
        @name="errorWorkflowId"
        @title={{i18n "discourse_workflows.settings.error_workflow"}}
        @type="custom"
        as |field|
      >
        <field.Control>
          <ErrorWorkflowChooser
            @content={{this.errorWorkflowContent}}
            @onChange={{field.set}}
            @options={{hash
              none="discourse_workflows.settings.error_workflow_none"
              excludeWorkflowId=@workflow.id
            }}
            @value={{field.value}}
          />
        </field.Control>
      </form.Field>

      <form.Field
        @description={{i18n
          "discourse_workflows.settings.timezone_description"
        }}
        @format="full"
        @name="timezone"
        @title={{i18n "discourse_workflows.settings.timezone"}}
        @type="custom"
        as |field|
      >
        <field.Control>
          <TimezoneInput @onChange={{field.set}} @value={{field.value}} />
        </field.Control>
      </form.Field>

      <form.Emphasis
        @subtitle={{i18n "discourse_workflows.settings.delete_description"}}
        @title={{i18n "discourse_workflows.settings.danger_zone"}}
        @type="error"
      >
        <form.Actions>
          <form.Button
            class="btn-danger"
            @action={{this.deleteWorkflow}}
            @label="discourse_workflows.delete"
          />
        </form.Actions>
      </form.Emphasis>
    </Form>
  </template>
}
