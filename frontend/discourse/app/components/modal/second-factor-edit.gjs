import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { MAX_SECOND_FACTOR_NAME_LENGTH } from "discourse/models/user";
import { i18n } from "discourse-i18n";

export default class SecondFactorEdit extends Component {
  @tracked loading = false;

  maxSecondFactorNameLength = MAX_SECOND_FACTOR_NAME_LENGTH;

  @action
  editSecondFactor() {
    this.loading = true;
    this.args.model.user
      .updateSecondFactor(
        this.args.model.secondFactor.id,
        this.args.model.secondFactor.name,
        false,
        this.args.model.secondFactor.method
      )
      .then((response) => {
        if (response.error) {
          return;
        }
        this.args.model.markDirty();
      })
      .catch((error) => {
        this.args.closeModal();
        this.args.model.onError(error);
      })
      .finally(() => {
        this.loading = false;
        this.args.closeModal();
      });
  }

  <template>
    <DModal
      @title={{i18n "user.second_factor.edit_title"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        <div class="input-group">
          <label for="authenticator-name">{{i18n
              "user.second_factor.edit_description"
            }}</label>
          <Input
            name="authenticator-name"
            maxlength={{this.maxSecondFactorNameLength}}
            @type="text"
            @value={{@model.secondFactor.name}}
          />
        </div>
      </:body>
      <:footer>
        <DButton
          @action={{this.editSecondFactor}}
          class="btn-primary"
          @label="user.second_factor.save"
        />
      </:footer>
    </DModal>
  </template>
}
