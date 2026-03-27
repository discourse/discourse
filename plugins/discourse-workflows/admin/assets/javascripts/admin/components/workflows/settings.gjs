import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ComboBox from "discourse/select-kit/components/combo-box";
import { i18n } from "discourse-i18n";

export default class WorkflowSettings extends Component {
  @service router;
  @service dialog;

  @tracked errorWorkflows = [];
  @tracked loadingErrorWorkflows = true;

  constructor() {
    super(...arguments);
    this.loadErrorWorkflows();
  }

  @cached
  get formData() {
    return {
      error_workflow_id: this.args.workflow.error_workflow_id,
    };
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
  async handleErrorWorkflowChange(value, { set, name }) {
    set(name, value);

    const previousValue = this.args.workflow.error_workflow_id;
    this.args.workflow.set("error_workflow_id", value);

    try {
      await ajax(
        `/admin/plugins/discourse-workflows/workflows/${this.args.workflow.id}.json`,
        {
          type: "PUT",
          data: {
            workflow: {
              name: this.args.workflow.name,
              error_workflow_id: value,
            },
          },
        }
      );
    } catch (e) {
      this.args.workflow.set("error_workflow_id", previousValue);
      set(name, previousValue);
      popupAjaxError(e);
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

  <template>
    <div class="workflows-settings">
      <Form @data={{this.formData}} as |form|>
        <form.Field
          @name="error_workflow_id"
          @title={{i18n "discourse_workflows.settings.error_workflow"}}
          @description={{i18n
            "discourse_workflows.settings.error_workflow_description"
          }}
          @type="custom"
          @onSet={{this.handleErrorWorkflowChange}}
          as |field|
        >
          {{#unless this.loadingErrorWorkflows}}
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
          {{/unless}}
        </form.Field>
      </Form>

      <section class="workflows-settings__section --danger">
        <h3 class="workflows-settings__section-title">{{i18n
            "discourse_workflows.settings.danger_zone"
          }}</h3>
        <p class="workflows-settings__section-description">{{i18n
            "discourse_workflows.settings.delete_description"
          }}</p>
        <DButton
          @action={{this.deleteWorkflow}}
          @icon="trash-can"
          @label="discourse_workflows.delete"
          class="btn-danger btn-small"
        />
      </section>
    </div>
  </template>
}
