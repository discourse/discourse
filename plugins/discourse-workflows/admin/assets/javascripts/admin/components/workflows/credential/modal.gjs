import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq } from "discourse/truth-helpers";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import {
  fieldVisible,
  normalizeSchema,
  propertyLabel,
} from "../../../lib/workflows/property-engine";
import Field from "../configurators/field";

const CREDENTIAL_DATA_NAME_FIELD = "credential_data_name";

function credentialTypeDefinition(credentialTypes, type) {
  if (!type || !credentialTypes) {
    return null;
  }
  return credentialTypes.find((ct) => ct.identifier === type);
}

function credentialTypeSchema(credentialTypes, type) {
  const def = credentialTypeDefinition(credentialTypes, type);
  return def ? normalizeSchema(def.property_schema) : [];
}

export default class CredentialModal extends Component {
  @service workflowsNodeTypes;

  @tracked credentialTypes = null;

  constructor() {
    super(...arguments);
    this.#loadCredentialTypes();
  }

  get isEditing() {
    return !!this.args.model.credential;
  }

  get credentialSlot() {
    return this.args.model.credentialSlot;
  }

  get availableCredentialTypes() {
    if (this.isEditing || !this.credentialSlot) {
      return this.credentialTypes || [];
    }

    const allowedTypes = [
      this.credentialSlot.credential_types ||
        this.credentialSlot.credential_type,
    ]
      .flat()
      .filter(Boolean);

    return (this.credentialTypes || []).filter((credentialType) =>
      allowedTypes.includes(credentialType.identifier)
    );
  }

  get automaticCredentialType() {
    return this.credentialSlot && this.availableCredentialTypes.length === 1
      ? this.availableCredentialTypes[0].identifier
      : null;
  }

  get isLoading() {
    return this.credentialTypes === null;
  }

  get modalTitle() {
    if (this.isEditing) {
      return i18n("discourse_workflows.credentials.edit");
    }

    const slot = this.credentialSlot?.label || this.credentialSlot?.name;
    if (slot) {
      return i18n("discourse_workflows.credentials.add_for_slot", { slot });
    }

    return i18n("discourse_workflows.credentials.add");
  }

  get showTypePicker() {
    return (
      !this.isEditing &&
      (!this.credentialSlot || this.availableCredentialTypes.length > 1)
    );
  }

  get typeContextUnavailable() {
    return (
      !this.isEditing &&
      !!this.credentialSlot &&
      this.availableCredentialTypes.length === 0
    );
  }

  get typeOptions() {
    return this.availableCredentialTypes.map((ct) => ({
      value: ct.identifier,
      label: ct.display_name,
    }));
  }

  get formData() {
    const credential = this.args.model.credential;
    if (!credential) {
      return {
        name: "",
        credential_type: this.automaticCredentialType || "",
      };
    }

    return {
      ...(credential.data || {}),
      name: credential.name,
      credential_type: credential.credential_type,
      [CREDENTIAL_DATA_NAME_FIELD]: credential.data?.name,
    };
  }

  @action
  async handleSubmit(credentialTypes, data) {
    try {
      const schema = credentialTypeSchema(
        credentialTypes,
        data.credential_type
      );
      const credentialData = {};
      for (const field of schema) {
        const dataFieldName =
          field.name === "name" ? CREDENTIAL_DATA_NAME_FIELD : field.name;
        if (data[dataFieldName] !== undefined) {
          credentialData[field.name] = data[dataFieldName];
        }
      }

      await this.args.model.onSave({
        name: data.name,
        credential_type: data.credential_type,
        data: credentialData,
      });
      this.args.closeModal();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  async #loadCredentialTypes() {
    await this.workflowsNodeTypes.load();
    this.credentialTypes = this.workflowsNodeTypes.credentialTypes || [];
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @inline={{@model.inline}}
      @title={{this.modalTitle}}
    >
      <:body>
        <DConditionalLoadingSpinner @condition={{this.isLoading}}>
          <Form
            class="workflows-configurator-form"
            @data={{this.formData}}
            @onSubmit={{fn this.handleSubmit this.availableCredentialTypes}}
            as |form transientData|
          >
            <form.Field
              @format="full"
              @name="name"
              @title={{i18n "discourse_workflows.credentials.name"}}
              @type="input"
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
                @disabled={{true}}
                @format="full"
                @name="credential_type"
                @title={{i18n "discourse_workflows.credentials.type"}}
                @type="input"
                as |field|
              >
                <field.Control @disabled={{true}} />
              </form.Field>
            {{else if this.showTypePicker}}
              <form.Field
                @format="full"
                @name="credential_type"
                @title={{i18n "discourse_workflows.credentials.type"}}
                @type="select"
                @validation="required"
                as |field|
              >
                <field.Control
                  @includeNone={{i18n
                    "discourse_workflows.credentials.select_type"
                  }}
                  as |c|
                >
                  {{#each this.typeOptions as |option|}}
                    <c.Option
                      @value={{option.value}}
                    >{{option.label}}</c.Option>
                  {{/each}}
                </field.Control>
              </form.Field>
            {{/if}}

            {{#if this.typeContextUnavailable}}
              <div class="alert alert-error" role="alert">
                {{i18n "discourse_workflows.credentials.no_supported_types"}}
              </div>
            {{/if}}

            {{#each
              (credentialTypeSchema
                this.availableCredentialTypes transientData.credential_type
              )
              key="name"
              as |fieldSchema|
            }}
              {{#if (fieldVisible fieldSchema transientData)}}
                <Field
                  @configuration={{transientData}}
                  @fieldName={{if
                    (eq fieldSchema.name "name")
                    "credential_data_name"
                    fieldSchema.name
                  }}
                  @form={{form}}
                  @formApi={{form.api}}
                  @label={{propertyLabel
                    (credentialTypeDefinition
                      this.availableCredentialTypes
                      transientData.credential_type
                    )
                    fieldSchema.name
                  }}
                  @nodeDefinition={{credentialTypeDefinition
                    this.availableCredentialTypes
                    transientData.credential_type
                  }}
                  @schema={{fieldSchema}}
                />
              {{/if}}
            {{/each}}

            <form.Submit @disabled={{this.typeContextUnavailable}} />
          </Form>
        </DConditionalLoadingSpinner>
      </:body>
    </DModal>
  </template>
}
