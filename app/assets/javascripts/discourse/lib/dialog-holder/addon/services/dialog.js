import Service from "@ember/service";
import A11yDialog from "a11y-dialog";
import { bind } from "discourse-common/utils/decorators";

export default Service.extend({
  message: null,
  type: null,
  dialogInstance: null,

  title: null,
  titleElementId: null,

  didConfirm: null,
  iconConfirm: null,
  labelConfirm: null,

  didCancel: null,
  labelCancel: null,
  cancelVisible: null,

  buttons: null,
  class: null,
  _confirming: false,

  dialog(params) {
    const {
      message,
      type,
      title,

      didConfirm,
      iconConfirm,
      labelConfirm = "ok_value",

      didCancel,
      labelCancel = "cancel_value",
      cancelVisible,

      buttons,
    } = params;

    const element = document.getElementById("dialog-holder");

    this.setProperties({
      message,
      type,
      dialogInstance: new A11yDialog(element),

      title,
      titleElementId: title !== null ? "dialog-title" : null,

      didConfirm,
      labelConfirm,
      iconConfirm,

      didCancel,
      labelCancel,
      cancelVisible,

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
      cancelVisible: true,
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
      labelConfirm: "yes_value",
      labelCancel: "no_value",
    });
  },

  reset() {
    this.setProperties({
      message: null,
      type: null,
      dialogInstance: null,

      title: null,
      titleElementId: null,

      didConfirm: null,
      labelConfirm: null,
      iconConfirm: null,

      didCancel: null,
      labelCancel: null,
      cancelVisible: null,

      buttons: null,
      class: null,

      _confirming: false,
    });
  },

  willDestroy() {
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
});
