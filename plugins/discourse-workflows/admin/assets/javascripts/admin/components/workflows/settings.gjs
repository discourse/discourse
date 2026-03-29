import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ComboBox from "discourse/select-kit/components/combo-box";
import UserChooser from "discourse/select-kit/components/user-chooser";
import { i18n } from "discourse-i18n";

export default class WorkflowSettings extends Component {
  @service router;
  @service dialog;
  @service toasts;

  @tracked errorWorkflows = [];
  @tracked loadingErrorWorkflows = true;

  formData = {
    run_as_username: this.args.workflow.run_as_username ?? "system",
    error_workflow_id: this.args.workflow.error_workflow_id,
  };

  constructor() {
    super(...arguments);
    this.loadErrorWorkflows();
  }

  async loadErrorWorkflows() {
    try {
      const result = await ajax(
        "/admin/plugins/discourse-workflows/workflows.json"
      );

      this.errorWorkflows = (result.workflows || [])
        .filter(
          (wf) =>
            wf.id !== this.args.workflow.id &&
            wf.nodes?.some((n) => n.type === "trigger:error")
        )
        .map((wf) => ({ id: wf.id, name: wf.name }));
    } finally {
      this.loadingErrorWorkflows = false;
    }
  }

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
              run_as_username: data.run_as_username?.[0] || "system",
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

      {{#unless this.loadingErrorWorkflows}}
        {{#if this.errorWorkflows.length}}
          <form.Field
            @name="error_workflow_id"
            @title={{i18n "discourse_workflows.settings.error_workflow"}}
            @description={{i18n
              "discourse_workflows.settings.error_workflow_description"
            }}
            @type="custom"
            @format="full"
            @onSet={{this.handleErrorWorkflowChange}}
            as |field|
          >
            <field.Control>
              <ComboBox
                @content={{this.errorWorkflows}}
                @value={{field.value}}
                @onChange={{field.set}}
                @options={{hash
                  none="discourse_workflows.settings.error_workflow_none"
                }}
              />
            </field.Control>
          </form.Field>
        {{else}}
          <form.Alert @type="info">
            {{i18n "discourse_workflows.settings.no_error_workflows_available"}}
          </form.Alert>
        {{/if}}
      {{/unless}}

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
