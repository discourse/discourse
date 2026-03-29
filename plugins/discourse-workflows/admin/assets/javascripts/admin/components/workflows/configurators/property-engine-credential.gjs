import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import CredentialModal from "../credential/modal";

export default class PropertyEngineCredential extends Component {
  @service modal;

  @tracked credentials = null;

  constructor() {
    super(...arguments);
    this.#loadCredentials();
  }

  async #loadCredentials() {
    try {
      const credentialType = this.args.schema.credential_type;
      const url = credentialType
        ? `/admin/plugins/discourse-workflows/credentials.json?type=${credentialType}`
        : "/admin/plugins/discourse-workflows/credentials.json";
      const result = await ajax(url);
      this.credentials = result.credentials;
    } catch (e) {
      popupAjaxError(e);
    }
  }

  get options() {
    return (this.credentials || []).map((c) => ({
      id: c.id,
      name: c.name,
    }));
  }

  @action
  onChange(event) {
    const value = event.target.value;
    this.args.onPatch({
      [this.args.fieldName]: value ? parseInt(value, 10) : null,
    });
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
          this.args.onPatch({ [this.args.fieldName]: result.credential.id });
        },
      },
    });
  }

  <template>
    <div class="workflows-property-engine-credential">
      <select {{on "change" this.onChange}}>
        <option value="">{{i18n
            "discourse_workflows.credentials.select_type"
          }}</option>
        {{#each this.options as |credentialOption|}}
          <option
            value={{credentialOption.id}}
            selected={{eq credentialOption.id @value}}
          >{{credentialOption.name}}</option>
        {{/each}}
      </select>
      <DButton
        @action={{this.setupCredential}}
        @label="discourse_workflows.credentials.set_up_credential"
        @icon="plus"
        class="btn-small"
      />
    </div>
  </template>
}
