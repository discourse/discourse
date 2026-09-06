import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";
import CredentialModal from "../credential/modal";
import ExpressionWrapper from "./expression-wrapper";

export default class Credential extends Component {
  @service modal;

  @tracked credentials = null;

  constructor() {
    super(...arguments);
    this.#loadCredentials();
  }

  async #loadCredentials() {
    try {
      const credentialType =
        this.credentialTypes.length === 1 ? this.credentialTypes[0] : null;
      const url = credentialType
        ? `/admin/plugins/discourse-workflows/credentials.json?type=${credentialType}`
        : "/admin/plugins/discourse-workflows/credentials.json";
      const result = await ajax(url);
      this.credentials = result.credentials;
    } catch (e) {
      popupAjaxError(e);
    }
  }

  get credentialTypes() {
    return [
      this.args.credentialTypes ||
        this.args.schema?.credential_types ||
        this.args.schema?.credential_type,
    ]
      .flat()
      .filter(Boolean);
  }

  get value() {
    return this.args.value?.id || this.args.field?.value || null;
  }

  get options() {
    return (this.credentials || [])
      .filter(
        (c) =>
          this.credentialTypes.length === 0 ||
          this.credentialTypes.includes(c.credential_type)
      )
      .map((c) => ({
        id: c.id?.toString(),
        name: c.name,
        credential_type: c.credential_type,
      }));
  }

  @action
  handleChange(value) {
    if (this.args.onChange) {
      const selected = this.options.find(
        (c) => c.id.toString() === value?.toString()
      );
      this.args.onChange(
        value
          ? {
              id: value.toString(),
              credential_type:
                selected?.credential_type || this.credentialTypes[0] || null,
            }
          : null
      );
    } else {
      this.args.field.set(value ? parseInt(value, 10) : null);
    }
  }

  @action
  setupCredential() {
    this.modal.show(CredentialModal, {
      model: {
        credential: null,
        onSave: async (data) => {
          const result = await ajax(
            "/admin/plugins/discourse-workflows/credentials.json",
            { type: "POST", data }
          );
          await this.#loadCredentials();
          this.handleChange(result.credential.id);
        },
      },
    });
  }

  <template>
    <ExpressionWrapper
      @field={{if @field @field (hash value=this.value)}}
      @schema={{@schema}}
      @supportsExpression={{@supportsExpression}}
      @placeholder={{@placeholder}}
      @dynamicValueHint={{@dynamicValueHint}}
      @session={{@session}}
    >
      {{#if @label}}
        <label class="workflows-property-engine__label">{{@label}}</label>
      {{/if}}
      <div class="workflows-property-engine__select-with-action">
        <ComboBox
          @content={{this.options}}
          @value={{this.value}}
          @nameProperty="name"
          @valueProperty="id"
          @onChange={{this.handleChange}}
          @options={{hash none="discourse_workflows.credentials.select_type"}}
        />
        {{#unless this.value}}
          <DButton
            @action={{this.setupCredential}}
            @label="discourse_workflows.credentials.set_up_credential"
            @icon="plus"
            class="btn-default"
          />
        {{/unless}}
      </div>
    </ExpressionWrapper>
  </template>
}
