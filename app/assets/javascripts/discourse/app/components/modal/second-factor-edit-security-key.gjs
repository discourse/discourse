import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { MAX_SECOND_FACTOR_NAME_LENGTH } from "discourse/models/user";
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
      @title={{i18n "user.second_factor.security_key.edit"}}
      @closeModal={{@closeModal}}
      @tagName="form"
    >
      <:body>
        <div class="input-group">
          <label for="security-key-name">{{i18n
              "user.second_factor.security_key.edit_description"
            }}</label>
          <Input
            name="security-key-name"
            id="security-key-name"
            maxlength={{this.maxSecondFactorNameLength}}
            @type="text"
            @value={{@model.securityKey.name}}
          />
        </div>
      </:body>
      <:footer>
        <DButton
          @action={{this.editSecurityKey}}
          class="btn-primary"
          @label="user.second_factor.security_key.save"
          @type="submit"
        />
      </:footer>
    </DModal>
  </template>
}
