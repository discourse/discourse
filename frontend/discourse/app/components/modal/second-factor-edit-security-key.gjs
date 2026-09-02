import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import { MAX_SECOND_FACTOR_NAME_LENGTH } from "discourse/models/user";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class SecondFactorEditSecurityKey extends Component {
  @tracked loading = false;

  maxSecondFactorNameLength = MAX_SECOND_FACTOR_NAME_LENGTH;

  @action
  editSecurityKey() {
    this.loading = true;
    this.args.model.user
      .updateSecurityKey(
        this.args.model.securityKey.id,
        this.args.model.securityKey.name,
        false
      )
      .then((response) => {
        if (response.error) {
          return;
        }
        this.args.model.markDirty();
      })
      .catch((error) => {
        this.args.model.onError(error);
      })
      .finally(() => {
        this.loading = false;
        this.args.closeModal();
      });
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @tagName="form"
      @title={{i18n "user.second_factor.security_key.edit"}}
    >
      <:body>
        <div class="input-group">
          <label for="security-key-name">{{i18n
              "user.second_factor.security_key.edit_description"
            }}</label>
          <Input
            id="security-key-name"
            maxlength={{this.maxSecondFactorNameLength}}
            name="security-key-name"
            @type="text"
            @value={{@model.securityKey.name}}
          />
        </div>
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.editSecurityKey}}
          @label="user.second_factor.security_key.save"
          @type="submit"
        />
      </:footer>
    </DModal>
  </template>
}
