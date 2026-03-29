import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import {
  getCachedNodeTypes,
  loadNodeTypes,
} from "../../../lib/workflows/node-types";
import {
  fieldVisible,
  normalizeSchema,
} from "../../../lib/workflows/property-engine";
import PropertyEngineField from "../configurators/property-engine-field";

export default class CredentialModal extends Component {
  @tracked credentialTypes = null;
  @tracked selectedType = this.args.model.credential?.credential_type || null;

  constructor() {
    super(...arguments);
    this.#loadCredentialTypes();
  }

  async #loadCredentialTypes() {
    let cached = getCachedNodeTypes();
    if (!cached) {
      await loadNodeTypes();
      cached = getCachedNodeTypes();
    }
    this.credentialTypes = cached?.credential_types || [];
  }

  get isEditing() {
    return !!this.args.model.credential;
  }

  get typeOptions() {
    return (this.credentialTypes || []).map((ct) => ({
      value: ct.identifier,
      label: ct.display_name,
    }));
  }

  get selectedTypeSchema() {
    if (!this.selectedType || !this.credentialTypes) {
      return [];
    }
    const type = this.credentialTypes.find(
      (ct) => ct.identifier === this.selectedType
    );
    return type ? normalizeSchema(type.configuration_schema) : [];
  }

  get formData() {
    const credential = this.args.model.credential;
    if (credential) {
      return {
        name: credential.name,
        credential_type: credential.credential_type,
        ...credential.data,
      };
    }
    return { name: "", credential_type: "" };
  }

  get nodeDefinition() {
    if (!this.selectedType || !this.credentialTypes) {
      return null;
    }
    return this.credentialTypes.find(
      (ct) => ct.identifier === this.selectedType
    );
  }

  @action
  onTypeChange(value, { set }) {
    set("credential_type", value);
    this.selectedType = value;
  }

  @action
  async handleSubmit(data) {
    try {
      const schemaFields = this.selectedTypeSchema.map((f) => f.name);
      const credentialData = {};
      for (const field of schemaFields) {
        if (data[field] !== undefined) {
          credentialData[field] = data[field];
        }
      }

      await this.args.model.onSave({
        name: data.name,
        credential_type: data.credential_type || this.selectedType,
        data: credentialData,
      });
      this.args.closeModal();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <DModal
      @title={{if
        this.isEditing
        (i18n "discourse_workflows.credentials.edit")
        (i18n "discourse_workflows.credentials.add")
      }}
      @closeModal={{@closeModal}}
    >
      <:body>
        <Form
          @data={{this.formData}}
          @onSubmit={{this.handleSubmit}}
          class="workflows-configurator-form"
          as |form|
        >
          <form.Field
            @name="name"
            @title={{i18n "discourse_workflows.credentials.name"}}
            @type="input"
            @format="full"
            @validation="required"
            as |field|
          >
            <field.Control
              placeholder={{i18n
                "discourse_workflows.credentials.name_placeholder"
              }}
            />
          </form.Field>

          {{#if this.isEditing}}
            <form.Field
              @name="credential_type"
              @title={{i18n "discourse_workflows.credentials.type"}}
              @type="input"
              @format="full"
              @disabled={{true}}
              as |field|
            >
              <field.Control @disabled={{true}} />
            </form.Field>
          {{else}}
            <form.Field
              @name="credential_type"
              @title={{i18n "discourse_workflows.credentials.type"}}
              @type="select"
              @format="full"
              @validation="required"
              @onSet={{this.onTypeChange}}
              as |field|
            >
              <field.Control
                @includeNone={{i18n
                  "discourse_workflows.credentials.select_type"
                }}
                as |c|
              >
                {{#each this.typeOptions as |option|}}
                  <c.Option @value={{option.value}}>{{option.label}}</c.Option>
                {{/each}}
              </field.Control>
            </form.Field>
          {{/if}}

          {{#each this.selectedTypeSchema as |fieldSchema|}}
            {{#if (fieldVisible fieldSchema this.formData)}}
              <PropertyEngineField
                @form={{form}}
                @formApi={{form.api}}
                @fieldName={{fieldSchema.name}}
                @schema={{fieldSchema}}
                @configuration={{this.formData}}
                @nodeDefinition={{this.nodeDefinition}}
              />
            {{/if}}
          {{/each}}

          <form.Submit />
        </Form>
      </:body>
    </DModal>
  </template>
}
