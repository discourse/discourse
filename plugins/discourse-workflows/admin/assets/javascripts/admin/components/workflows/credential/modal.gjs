import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { service } from "@ember/service";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import {
  fieldVisible,
  normalizeSchema,
} from "../../../lib/workflows/property-engine";
import Field from "../configurators/field";

function credentialTypeDefinition(credentialTypes, type) {
  if (!type || !credentialTypes) {
    return null;
  }
  return credentialTypes.find((ct) => ct.identifier === type);
}

function credentialTypeSchema(credentialTypes, type) {
  const def = credentialTypeDefinition(credentialTypes, type);
  return def ? normalizeSchema(def.configuration_schema) : [];
}

export default class CredentialModal extends Component {
  @service workflowsNodeTypes;

  @tracked credentialTypes = null;

  constructor() {
    super(...arguments);
    this.#loadCredentialTypes();
  }

  async #loadCredentialTypes() {
    await this.workflowsNodeTypes.load();
    this.credentialTypes = this.workflowsNodeTypes.credentialTypes || [];
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

  async handleSubmit(credentialTypes, data) {
    try {
      const schema = credentialTypeSchema(
        credentialTypes,
        data.credential_type
      );
      const credentialData = {};
      for (const field of schema) {
        if (data[field.name] !== undefined) {
          credentialData[field.name] = data[field.name];
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
          @onSubmit={{fn this.handleSubmit this.credentialTypes}}
          class="workflows-configurator-form"
          as |form transientData|
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

          {{#each
            (credentialTypeSchema
              this.credentialTypes transientData.credential_type
            )
            key="name"
            as |fieldSchema|
          }}
            {{#if (fieldVisible fieldSchema transientData)}}
              <Field
                @form={{form}}
                @formApi={{form.api}}
                @fieldName={{fieldSchema.name}}
                @schema={{fieldSchema}}
                @configuration={{transientData}}
                @nodeDefinition={{credentialTypeDefinition
                  this.credentialTypes
                  transientData.credential_type
                }}
              />
            {{/if}}
          {{/each}}

          <form.Submit />
        </Form>
      </:body>
    </DModal>
  </template>
}
