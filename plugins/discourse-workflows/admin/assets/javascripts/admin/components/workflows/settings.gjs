import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import TimezoneInput from "discourse/select-kit/components/timezone-input";
import { i18n } from "discourse-i18n";
import ErrorWorkflowChooser from "./error-workflow-chooser";
import InUseDialog from "./in-use-dialog";

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
    await this.dialog.deleteConfirm({
      message: i18n("discourse_workflows.delete_confirm", {
        name: this.args.workflow.name,
      }),
      didConfirm: async () => {
        try {
          await this.args.workflow.destroyRecord();
          this.router.transitionTo(
            "adminPlugins.show.discourse-workflows.index"
          );
        } catch (e) {
          const body = e.jqXHR?.responseJSON;
          if (body?.type === "workflow_called_by_other_workflows") {
            this.dialog.alert({
              title: i18n("discourse_workflows.in_use_title"),
              bodyComponent: InUseDialog,
              bodyComponentModel: {
                description: i18n("discourse_workflows.in_use_description"),
                workflows: body.referencing_workflows,
                close: () => this.dialog.cancel(),
              },
            });
          } else {
            popupAjaxError(e);
          }
        }
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
      @onSet={{this.submitForm}}
      @data={{this.formData}}
      class="workflows-settings"
      as |form|
    >
      <form.Field
        @name="errorWorkflowId"
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

      <form.Field
        @name="timezone"
        @title={{i18n "discourse_workflows.settings.timezone"}}
        @description={{i18n
          "discourse_workflows.settings.timezone_description"
        }}
        @type="custom"
        @format="full"
        as |field|
      >
        <field.Control>
          <TimezoneInput @value={{field.value}} @onChange={{field.set}} />
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
