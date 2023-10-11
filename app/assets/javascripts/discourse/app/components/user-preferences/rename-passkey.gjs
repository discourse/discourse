import I18n from "I18n";
import Component from "@glimmer/component";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import DButton from "discourse/components/d-button";

export default class RenamePasskey extends Component {
  <template>
    <div class="rename-passkey__form">
      <div class="rename-passkey__message">
        <p>{{this.instructions}}</p>
      </div>
      <form>
        <div class="rename-passkey__form inline-form">
          <Input @value={{this.passkeyName}} autofocus={{true}} @type="text" />
          <DButton
            @class="btn-primary"
            @type="submit"
            @action={{this.saveRename}}
            @label="user.passkeys.save"
          />
        </div>
      </form>
    </div>
  </template>

  @service router;
  @service dialog;

  @tracked passkeyName;

  constructor() {
    super(...arguments);
    this.passkeyName = this.args.model.name;
  }

  get instructions() {
    return I18n.t("user.passkeys.rename_passkey_instructions");
  }

  @action
  async saveRename() {
    await ajax(`/u/rename_passkey/${this.args.model.id}`, {
      type: "PUT",
      data: {
        name: this.passkeyName,
      },
    });

    this.router.refresh();
    this.dialog.didConfirmWrapped();
  }
}
