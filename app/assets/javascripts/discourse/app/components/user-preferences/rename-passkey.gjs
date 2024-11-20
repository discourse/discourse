import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class RenamePasskey extends Component {
  @service router;
  @service dialog;

  @tracked passkeyName;
  @tracked errorMessage;

  instructions = i18n("user.passkeys.rename_passkey_instructions");

  constructor() {
    super(...arguments);
    this.passkeyName = this.args.model.name;
  }

  @action
  async saveRename() {
    try {
      await ajax(`/u/rename_passkey/${this.args.model.id}`, {
        type: "PUT",
        data: {
          name: this.passkeyName,
        },
      });

      this.errorMessage = null;
      this.router.refresh();
      this.dialog.didConfirmWrapped();
    } catch (error) {
      this.errorMessage = extractError(error);
    }
  }

  <template>
    {{#if this.errorMessage}}
      <div class="alert alert-error">
        {{this.errorMessage}}
      </div>
    {{/if}}

    <div class="rename-passkey__form">
      <div class="rename-passkey__message">
        <p>{{this.instructions}}</p>
      </div>
      <form>
        <div class="rename-passkey__form inline-form">
          <Input @value={{this.passkeyName}} autofocus={{true}} @type="text" />
          <DButton
            class="btn-primary"
            @type="submit"
            @action={{this.saveRename}}
            @label="user.passkeys.save"
          />
        </div>
      </form>
    </div>
  </template>
}
