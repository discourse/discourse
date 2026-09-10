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
  SETTING_FIELD_TYPE_VALUES,
  settingFieldTypeLabel,
} from "../../lib/workflows/setting-field-types";

const KEY_FORMAT_RE = /^[a-zA-Z_][a-zA-Z0-9_]*$/;

export default class WorkflowSettingFieldForm extends Component {
  @service router;

  @tracked choices = this.existingField?.type_options?.choices ?? [];

  get existingField() {
    if (!this.args.fieldId) {
      return null;
    }

    return this.args.workflow.settingFields.find(
      (field) => `${field.id}` === `${this.args.fieldId}`
    );
  }

  get formData() {
    const field = this.existingField;

    return {
      key: field?.key ?? "",
      label: field?.label ?? "",
      description: field?.description ?? "",
      field_type: field?.field_type ?? "string",
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
        title: i18n("discourse_workflows.settings.fields.field_key"),
        message: i18n(
          "discourse_workflows.settings.fields.field_key_format_error"
        ),
      });
      return;
    }

    const isDuplicate = this.args.workflow.settingFields.some(
      (field) => field.key === value && field.id !== this.existingField?.id
    );

    if (isDuplicate) {
      addError(name, {
        title: i18n("discourse_workflows.settings.fields.field_key"),
        message: i18n(
          "discourse_workflows.settings.fields.field_key_duplicate_error"
        ),
      });
    }
  }

  @action
  async handleSubmit(data) {
    const payload = {
      ...data,
      type_options: data.field_type === "enum" ? { choices: this.choices } : {},
    };

    try {
      const result = this.existingField
        ? await ajax(
            `/admin/plugins/discourse-workflows/workflows/${this.args.workflow.id}/setting-fields/${this.existingField.id}.json`,
            { type: "PUT", data: payload }
          )
        : await ajax(
            `/admin/plugins/discourse-workflows/workflows/${this.args.workflow.id}/setting-fields.json`,
            { type: "POST", data: payload }
          );

      this.args.workflow.settingFields = this.existingField
        ? this.args.workflow.settingFields.map((field) =>
            field.id === this.existingField.id
              ? result.workflow_setting_field
              : field
          )
        : [...this.args.workflow.settingFields, result.workflow_setting_field];

      this.args.workflow.setProperties({
        versionId: result.workflow.version_id,
        activeVersionId: result.workflow.active_version_id,
        hasUnpublishedChanges: result.workflow.has_unpublished_changes,
      });

      this.router.transitionTo(
        "adminPlugins.show.discourse-workflows.show.settings.fields.index",
        this.args.workflow.id
      );
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <Form
      class="workflows-setting-field-form"
      @data={{this.formData}}
      @onSubmit={{this.handleSubmit}}
      as |form transientData|
    >
      <form.Field
        @description={{trustHTML
          (i18n "discourse_workflows.settings.fields.field_key_description")
        }}
        @format="large"
        @name="key"
        @title={{i18n "discourse_workflows.settings.fields.field_key"}}
        @type="input"
        @validate={{this.validateKey}}
        @validation="required|length:1,100"
        as |field|
      >
        <field.Control />
      </form.Field>

      <form.Field
        @description={{i18n
          "discourse_workflows.settings.fields.field_label_description"
        }}
        @format="large"
        @name="label"
        @title={{i18n "discourse_workflows.settings.fields.field_label"}}
        @type="input"
        @validation="required|length:1,255"
        as |field|
      >
        <field.Control />
      </form.Field>

      <form.Field
        @description={{i18n
          "discourse_workflows.settings.fields.field_description_description"
        }}
        @format="large"
        @name="description"
        @title={{i18n "discourse_workflows.settings.fields.field_description"}}
        @type="textarea"
        @validation="length:,500"
        as |field|
      >
        <field.Control @height={{80}} />
      </form.Field>

      <form.Field
        @description={{i18n
          "discourse_workflows.settings.fields.field_type_description"
        }}
        @format="large"
        @name="field_type"
        @title={{i18n "discourse_workflows.settings.fields.field_type"}}
        @type="select"
        @validation="required"
        as |field|
      >
        <field.Control as |select|>
          {{#each SETTING_FIELD_TYPE_VALUES as |type|}}
            <select.Option @value={{type}}>
              {{settingFieldTypeLabel type}}
            </select.Option>
          {{/each}}
        </field.Control>
      </form.Field>

      {{#if (eq transientData.field_type "enum")}}
        <form.Container
          @description={{i18n
            "discourse_workflows.settings.fields.field_choices_description"
          }}
          @format="large"
          @title={{i18n "discourse_workflows.settings.fields.field_choices"}}
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
