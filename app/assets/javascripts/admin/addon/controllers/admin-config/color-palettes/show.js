import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { service } from "@ember/service";
import discourseLater from "discourse/lib/later";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class AdminConfigColorPalettesShowController extends Controller {
  @service dialog;
  @service router;

  onlyOverridden = false;

  @computed("model.colors.[]", "onlyOverridden")
  get colors() {
    if (this.onlyOverridden) {
      return this.model.colors?.filterBy("overridden");
    } else {
      return this.model.colors;
    }
  }

  @action
  revert(color) {
    color.revert();
  }

  @action
  undo(color) {
    color.undo();
  }

  @action
  copyToClipboard() {
    if (clipboardCopy(this.model.schemeJson())) {
      this.set(
        "model.savingStatus",
        i18n("admin.customize.copied_to_clipboard")
      );
    } else {
      this.set(
        "model.savingStatus",
        i18n("admin.customize.copy_to_clipboard_error")
      );
    }

    discourseLater(() => {
      this.set("model.savingStatus", null);
    }, 2000);
  }

  @action
  async copy() {
    const newColorScheme = this.model.copy();
    newColorScheme.set(
      "name",
      i18n("admin.customize.colors.copy_name_prefix") +
        " " +
        this.get("model.name")
    );
    await newColorScheme.save();
    this.router.replaceWith("adminConfig.colorPalettes.show", newColorScheme);
  }

  @action
  save() {
    this.model.save();
  }

  @action
  applyUserSelectable(value) {
    this.model.set("user_selectable", value);
    this.model.updateUserSelectable(value);
  }

  @action
  destroy() {
    return this.dialog.deleteConfirm({
      title: i18n("admin.customize.colors.delete_confirm"),
      didConfirm: async () => {
        await this.model.destroy();
        this.router.replaceWith("adminConfig.colorPalettes");
      },
    });
  }
}
