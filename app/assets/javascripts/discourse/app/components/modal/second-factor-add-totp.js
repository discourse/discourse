import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import {
  MAX_SECOND_FACTOR_NAME_LENGTH,
  SECOND_FACTOR_METHODS,
} from "discourse/models/user";
import { i18n } from "discourse-i18n";

export default class SecondFactorAddTotp extends Component {
  @tracked loading = false;
  @tracked secondFactorImage;
  @tracked secondFactorKey;
  @tracked showSecondFactorKey = false;
  @tracked errorMessage;
  @tracked secondFactorToken;

  maxSecondFactorNameLength = MAX_SECOND_FACTOR_NAME_LENGTH;
  totpType = SECOND_FACTOR_METHODS.TOTP;

  @action
  totpRequested() {
    this.args.model.secondFactor
      .createSecondFactorTotp()
      .then((response) => {
        if (response.error) {
          this.errorMessage = response.error;
          return;
        }

        this.errorMessage = null;
        this.secondFactorKey = response.key;
        this.secondFactorImage = response.qr;
      })
      .catch((error) => {
        this.args.closeModal();
        this.args.model.onError(error);
      })
      .finally(() => (this.loading = false));
  }

  @action
  enableShowSecondFactorKey(e) {
    e.preventDefault();
    e.stopImmediatePropagation();
    this.showSecondFactorKey = true;
  }

  @action
  enableSecondFactor() {
    if (!this.secondFactorToken || !this.secondFactorName) {
      this.errorMessage = i18n(
        "user.second_factor.totp.name_and_code_required_error"
      );
      return;
    }
    this.loading = true;
    this.args.model.secondFactor
      .enableSecondFactorTotp(this.secondFactorToken, this.secondFactorName)
      .then((response) => {
        if (response.error) {
          this.errorMessage = response.error;
          return;
        }
        this.args.model.markDirty();
        this.errorMessage = null;
        this.args.closeModal();
        if (this.args.model.enforcedSecondFactor) {
          window.location.reload();
        }
      })
      .catch((error) => this.args.model.onError(error))
      .finally(() => (this.loading = false));
  }
}
