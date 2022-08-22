import Service from "@ember/service";
import A11yDialog from "a11y-dialog";
import { bind } from "discourse-common/utils/decorators";

export default Service.extend({
  message: null,
  type: null,

  title: null,
  titleElementId: null,

  actionConfirm: null,
  labelConfirm: null,
  iconConfirm: null,

  actionCancel: null,
  labelCancel: null,
  cancelVisible: null,

  dialogInstance: null,

  dialog(params) {
    const {
      message,
      type,
      title,

      actionConfirm,
      labelConfirm = "ok_value",
      iconConfirm,

      actionCancel,
      labelCancel = "cancel_value",
      cancelVisible,
    } = params;

    const element = document.getElementById("a11y-dialog");

    this.setProperties({
      message,
      type,

      title,
      titleElementId: title !== null ? "a11y-dialog-title" : null,

      actionConfirm,
      labelConfirm,
      iconConfirm,

      actionCancel,
      labelCancel,
      cancelVisible,

      dialogInstance: new A11yDialog(element),
    });

    this.dialogInstance.show();

    this.dialogInstance.on("hide", () => this.reset());
  },

  alert(params) {
    // support string param for easier porting of bootbox.alert
    if (typeof params === "string") {
      return this.dialog({
        message: params,
        type: "alert",
        labelConfirm: "ok_value",
      });
    }

    return this.dialog({
      ...params,
      type: "alert",
      labelConfirm: "ok_value",
    });
  },

  confirm(params) {
    return this.dialog({
      ...params,
      cancelVisible: true,
      type: "confirm",
    });
  },

  yesNoConfirm(params) {
    return this.dialog({
      ...params,
      labelConfirm: "yes_value",
      labelCancel: "no_value",
      cancelVisible: true,
      type: "confirm",
    });
  },
  reset() {
    this.setProperties({
      message: null,
      type: null,

      title: null,
      titleElementId: null,

      actionConfirm: null,
      labelConfirm: null,
      iconConfirm: null,

      actionCancel: null,
      labelCancel: null,
      cancelVisible: null,
    });
  },

  @bind
  actionConfirmWrapped() {
    if (this.actionConfirm) {
      this.actionConfirm();
    }
    this.dialogInstance.hide();
  },

  @bind
  actionCancelWrapped() {
    if (this.actionCancel) {
      this.actionCancel();
    }
    this.dialogInstance.hide();
  },
});
