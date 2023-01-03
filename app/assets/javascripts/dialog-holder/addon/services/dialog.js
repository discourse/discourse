import Service from "@ember/service";
import A11yDialog from "a11y-dialog";
import { bind } from "discourse-common/utils/decorators";
import { isBlank } from "@ember/utils";

export default Service.extend({
  message: null,
  type: null,
  dialogInstance: null,

  title: null,
  titleElementId: null,

  confirmButtonIcon: null,
  confirmButtonLabel: null,
  confirmButtonClass: null,
  confirmPhrase: null,
  confirmPhraseInput: null,
  cancelButtonLabel: null,
  cancelButtonClass: null,
  shouldDisplayCancel: null,

  didConfirm: null,
  didCancel: null,
  buttons: null,
  class: null,
  _confirming: false,

  dialog(params) {
    const {
      message,
      type,
      title,

      confirmButtonIcon,
      confirmButtonLabel = "ok_value",
      confirmButtonClass = "btn-primary",
      cancelButtonLabel = "cancel_value",
      cancelButtonClass = "btn-default",
      confirmPhrase,
      shouldDisplayCancel,

      didConfirm,
      didCancel,
      buttons,
    } = params;

    let confirmButtonDisabled = !isBlank(confirmPhrase);

    const element = document.getElementById("dialog-holder");

    this.setProperties({
      message,
      type,
      dialogInstance: new A11yDialog(element),

      title,
      titleElementId: title !== null ? "dialog-title" : null,

      confirmButtonDisabled,
      confirmButtonClass,
      confirmButtonLabel,
      confirmButtonIcon,
      confirmPhrase,
      cancelButtonLabel,
      cancelButtonClass,
      shouldDisplayCancel,

      didConfirm,
      didCancel,
      buttons,
      class: params.class,
    });

    this.dialogInstance.show();

    this.dialogInstance.on("hide", () => {
      if (!this._confirming && this.didCancel) {
        this.didCancel();
      }

      this.reset();
    });
  },

  alert(params) {
    // support string param for easier porting of bootbox.alert
    if (typeof params === "string") {
      return this.dialog({
        message: params,
        type: "alert",
      });
    }

    return this.dialog({
      ...params,
      type: "alert",
    });
  },

  confirm(params) {
    return this.dialog({
      ...params,
      shouldDisplayCancel: true,
      buttons: null,
      type: "confirm",
    });
  },

  notice(message) {
    return this.dialog({
      message,
      type: "notice",
    });
  },

  yesNoConfirm(params) {
    return this.confirm({
      ...params,
      confirmButtonLabel: "yes_value",
      cancelButtonLabel: "no_value",
    });
  },

  deleteConfirm(params) {
    return this.confirm({
      ...params,
      confirmButtonClass: "btn-danger",
      confirmButtonLabel: params.confirmButtonLabel || "delete",
    });
  },

  reset() {
    this.setProperties({
      message: null,
      type: null,
      dialogInstance: null,

      title: null,
      titleElementId: null,

      confirmButtonLabel: null,
      confirmButtonIcon: null,
      cancelButtonLabel: null,
      cancelButtonClass: null,
      shouldDisplayCancel: null,
      confirmPhrase: null,
      confirmPhraseInput: null,

      didConfirm: null,
      didCancel: null,
      buttons: null,
      class: null,

      _confirming: false,
    });
  },

  willDestroy() {
    this.dialogInstance?.destroy();
    this.reset();
  },

  @bind
  didConfirmWrapped() {
    if (this.didConfirm) {
      this.didConfirm();
    }
    this._confirming = true;
    this.dialogInstance.hide();
  },

  @bind
  cancel() {
    this.dialogInstance.hide();
  },

  @bind
  onConfirmPhraseInput() {
    this.set(
      "confirmButtonDisabled",
      this.confirmPhrase && this.confirmPhraseInput !== this.confirmPhrase
    );
  },
});
