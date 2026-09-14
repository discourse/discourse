import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { isBlank } from "@ember/utils";
import SimpleList from "discourse/admin/components/simple-list";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import {
  WORKFLOW_VARIABLE_TYPE_VALUES,
  workflowVariableTypeLabel,
} from "../../lib/workflows/variable-types";

const KEY_FORMAT_RE = /^[a-zA-Z_][a-zA-Z0-9_]*$/;

export default class WorkflowVariableForm extends Component {
  @service router;

  @tracked choices = this.existingVariable?.type_options?.choices ?? [];

  get existingVariable() {
    if (!this.args.variableId) {
      return null;
    }

    return this.args.workflow.variables.find(
      (variable) => `${variable.id}` === `${this.args.variableId}`
    );
  }

  get formData() {
    const variable = this.existingVariable;

    return {
      key: variable?.key ?? "",
      description: variable?.description ?? "",
      variable_type: variable?.variable_type ?? "string",
    };
  }

  get choicesJoined() {
    return this.choices.join("\n");
  }

  @action
  setChoices(values) {
    this.choices = values;
  }

  @action
  validateKey(name, value, { addError }) {
    if (isBlank(value)) {
      return;
    }

    if (!KEY_FORMAT_RE.test(value)) {
      addError(name, {
        title: i18n("discourse_workflows.workflow_variables.key"),
        message: i18n(
          "discourse_workflows.workflow_variables.key_format_error"
        ),
      });
      return;
    }

    const isDuplicate = this.args.workflow.variables.some(
      (variable) =>
        variable.key === value && variable.id !== this.existingVariable?.id
    );

    if (isDuplicate) {
      addError(name, {
        title: i18n("discourse_workflows.workflow_variables.key"),
        message: i18n(
          "discourse_workflows.workflow_variables.key_duplicate_error"
        ),
      });
    }
  }

  @action
  async handleSubmit(data) {
    const payload = {
      ...data,
      type_options:
        data.variable_type === "enum" ? { choices: this.choices } : {},
    };

    try {
      const result = this.existingVariable
        ? await ajax(
            `/admin/plugins/discourse-workflows/workflows/${this.args.workflow.id}/variables/${this.existingVariable.id}.json`,
            { type: "PUT", data: payload }
          )
        : await ajax(
            `/admin/plugins/discourse-workflows/workflows/${this.args.workflow.id}/variables.json`,
            { type: "POST", data: payload }
          );

      this.args.workflow.variables = this.existingVariable
        ? this.args.workflow.variables.map((variable) =>
            variable.id === this.existingVariable.id
              ? result.variable
              : variable
          )
        : [...this.args.workflow.variables, result.variable];

      this.args.workflow.setProperties({
        versionId: result.workflow.version_id,
        activeVersionId: result.workflow.active_version_id,
        hasUnpublishedChanges: result.workflow.has_unpublished_changes,
      });

      this.router.transitionTo(
        "adminPlugins.show.discourse-workflows.show.variables.manage",
        this.args.workflow.id
      );
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <Form
      class="workflows-variable-form"
      @data={{this.formData}}
      @onSubmit={{this.handleSubmit}}
      as |form transientData|
    >
      <form.Field
        @description={{trustHTML
          (i18n "discourse_workflows.workflow_variables.key_description")
        }}
        @format="large"
        @name="key"
        @title={{i18n "discourse_workflows.workflow_variables.key"}}
        @type="input"
        @validate={{this.validateKey}}
        @validation="required|length:1,100"
        as |field|
      >
        <field.Control />
      </form.Field>

      <form.Field
        @description={{i18n
          "discourse_workflows.workflow_variables.description_description"
        }}
        @format="large"
        @name="description"
        @title={{i18n "discourse_workflows.workflow_variables.description"}}
        @type="textarea"
        @validation="length:,500"
        as |field|
      >
        <field.Control @height={{80}} />
      </form.Field>

      <form.Field
        @description={{i18n
          "discourse_workflows.workflow_variables.type_description"
        }}
        @format="large"
        @name="variable_type"
        @title={{i18n "discourse_workflows.workflow_variables.type"}}
        @type="select"
        @validation="required"
        as |field|
      >
        <field.Control as |select|>
          {{#each WORKFLOW_VARIABLE_TYPE_VALUES as |type|}}
            <select.Option @value={{type}}>
              {{workflowVariableTypeLabel type}}
            </select.Option>
          {{/each}}
        </field.Control>
      </form.Field>

      {{#if (eq transientData.variable_type "enum")}}
        <form.Container
          @description={{i18n
            "discourse_workflows.workflow_variables.choices_description"
          }}
          @format="large"
          @title={{i18n "discourse_workflows.workflow_variables.choices"}}
        >
          <SimpleList
            @onChange={{this.setChoices}}
            @values={{this.choicesJoined}}
          />
        </form.Container>
      {{/if}}

      <form.Actions>
        <form.Submit />
      </form.Actions>
    </Form>
  </template>
}
