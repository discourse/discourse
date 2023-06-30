import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import I18n from "I18n";

export default class SecondFactorAddTotp extends Component {
  @service modal;

  @tracked loading = false;
  @tracked secondFactorImage;
  @tracked secondFactorKey;
  @tracked showSecondFactorKey = false;
  @tracked errorMessage;
  @tracked secondFactorToken;

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
        this.modal.close();
        this.args.model.onError(error);
      })
      .finally(() => (this.loading = false));
  }

  @action
  enableShowSecondFactorKey() {
    this.showSecondFactorKey = true;
  }

  @action
  enableSecondFactor() {
    if (!this.secondFactorToken || !this.secondFactorName) {
      this.errorMessage = I18n.t(
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
        this.modal.close();
      })
      .catch((error) => this.args.model.onError(error))
      .finally(() => (this.loading = false));
  }
}
