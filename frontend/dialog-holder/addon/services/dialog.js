import Service from "@ember/service";
import { bind } from "discourse/lib/decorators";

export default class DialogService extends Service {
  dialogInstance = null;
  message = null;
  title = null;
  titleElementId = null;
  type = null;

  bodyComponent = null;
  bodyComponentModel = null;

  confirmButtonIcon = null;
  confirmButtonLabel = null;
  confirmButtonClass = null;
  confirmButtonDisabled = false;
  cancelButtonLabel = null;
  cancelButtonClass = null;
  shouldDisplayCancel = null;

  didConfirm = null;
  didCancel = null;
  buttons = null;
  class = null;
  _confirming = false;

  async dialog(params) {
    const {
      message,
      bodyComponent,
      bodyComponentModel,
      type,
      title,

      confirmButtonClass = "btn-primary",
      confirmButtonIcon,
      confirmButtonLabel = "ok_value",
      confirmButtonDisabled = false,

      cancelButtonClass = "btn-default",
      cancelButtonLabel = "cancel_value",
      shouldDisplayCancel,

      didConfirm,
      didCancel,
      buttons,
    } = params;

    this.setProperties({
      show: true,

      message,
      bodyComponent,
      bodyComponentModel,
      type,

      title,
      titleElementId: title !== null ? "dialog-title" : null,

      confirmButtonClass,
      confirmButtonDisabled,
      confirmButtonIcon,
      confirmButtonLabel,

      cancelButtonClass,
      cancelButtonLabel,
      shouldDisplayCancel,

      didConfirm,
      didCancel,
      buttons,
      class: params.class,
    });
  }

  alert(params) {
    // support string param for easier porting of bootbox.alert
    if (typeof params === "string") {
      return this.#promiseDialog({
        message: params,
        type: "alert",
        shouldDisplayCancel: false,
      });
    }

    return this.#promiseDialog({
      ...params,
      type: "alert",
      shouldDisplayCancel: false,
    });
  }

  confirm(params) {
    return this.#promiseDialog({
      ...params,
      buttons: null,
      type: "confirm",
    });
  }

  notice(message) {
    return this.#promiseDialog({
      message,
      type: "notice",
    });
  }

  yesNoConfirm(params) {
    return this.#promiseDialog({
      ...params,
      confirmButtonLabel: "yes_value",
      cancelButtonLabel: "no_value",
      buttons: null,
      type: "confirm",
    });
  }

  deleteConfirm(params) {
    return this.#promiseDialog({
      ...params,
      confirmButtonClass: "btn-danger",
      confirmButtonLabel: params.confirmButtonLabel || "delete",
      buttons: null,
      type: "confirm",
    });
  }

  #promiseDialog(params) {
    return new Promise((resolve) => {
      const { didConfirm, didCancel } = params;

      this.dialog({
        shouldDisplayCancel: true,
        ...params,
        didConfirm: () => {
          didConfirm?.();
          resolve(true);
        },
        didCancel: () => {
          didCancel?.();
          resolve(false);
        },
      });
    });
  }

  reset() {
    if (!this._confirming && this.didCancel) {
      this.didCancel();
    }

    this.setProperties({
      show: false,

      message: null,
      bodyComponent: null,
      bodyComponentModel: null,
      type: null,
      dialogInstance: null,

      title: null,
      titleElementId: null,

      confirmButtonDisabled: false,
      confirmButtonIcon: null,
      confirmButtonLabel: null,

      cancelButtonClass: null,
      cancelButtonLabel: null,
      shouldDisplayCancel: null,

      didConfirm: null,
      didCancel: null,
      buttons: null,
      class: null,

      _confirming: false,
    });
  }

  @bind
  didConfirmWrapped() {
    let didConfirm = this.didConfirm;
    this._confirming = true;
    this.reset();
    if (didConfirm) {
      didConfirm();
    }
  }

  @bind
  cancel() {
    this.reset();
  }

  @bind
  enableConfirmButton() {
    this.set("confirmButtonDisabled", false);
  }

  @bind
  hide() {
    this.reset();
  }
}
