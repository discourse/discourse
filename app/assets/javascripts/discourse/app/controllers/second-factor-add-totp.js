import Controller from "@ember/controller";
import { action } from "@ember/object";
import I18n from "I18n";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Controller.extend(ModalFunctionality, {
  loading: false,
  secondFactorImage: null,
  secondFactorKey: null,
  showSecondFactorKey: false,
  errorMessage: null,

  onShow() {
    this.setProperties({
      errorMessage: null,
      secondFactorKey: null,
      secondFactorName: null,
      secondFactorToken: null,
      showSecondFactorKey: false,
      secondFactorImage: null,
      loading: true,
    });
    this.model
      .createSecondFactorTotp()
      .then((response) => {
        if (response.error) {
          this.set("errorMessage", response.error);
          return;
        }

        this.setProperties({
          errorMessage: null,
          secondFactorKey: response.key,
          secondFactorImage: response.qr,
        });
      })
      .catch((error) => {
        this.send("closeModal");
        this.onError(error);
      })
      .finally(() => this.set("loading", false));
  },

  @action
  enableShowSecondFactorKey(event) {
    event?.preventDefault();
    this.set("showSecondFactorKey", true);
  },

  actions: {
    showSecondFactorKey() {
      this.enableShowSecondFactorKey();
    },

    enableSecondFactor() {
      if (!this.secondFactorToken || !this.secondFactorName) {
        this.set(
          "errorMessage",
          I18n.t("user.second_factor.totp.name_and_code_required_error")
        );
        return;
      }
      this.set("loading", true);

      this.model
        .enableSecondFactorTotp(this.secondFactorToken, this.secondFactorName)
        .then((response) => {
          if (response.error) {
            this.set("errorMessage", response.error);
            return;
          }
          this.markDirty();
          this.set("errorMessage", null);
          this.send("closeModal");
        })
        .catch((error) => this.onError(error))
        .finally(() => this.set("loading", false));
    },
  },
});
