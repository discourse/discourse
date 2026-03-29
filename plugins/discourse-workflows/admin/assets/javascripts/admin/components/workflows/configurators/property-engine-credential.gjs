import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ComboBox from "discourse/select-kit/components/combo-box";
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
  handleChange(value) {
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
      <ComboBox
        @content={{this.options}}
        @value={{@value}}
        @nameProperty="name"
        @valueProperty="id"
        @onChange={{this.handleChange}}
        @options={{hash none="discourse_workflows.credentials.select_type"}}
      />
      {{#unless @value}}
        <DButton
          @action={{this.setupCredential}}
          @label="discourse_workflows.credentials.set_up_credential"
          @icon="plus"
          class="btn-small"
        />
      {{/unless}}
    </div>
  </template>
}
