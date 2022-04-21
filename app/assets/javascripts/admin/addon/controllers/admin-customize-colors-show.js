import Controller from "@ember/controller";
import I18n from "I18n";
import bootbox from "bootbox";
import discourseComputed from "discourse-common/utils/decorators";
import { later } from "@ember/runloop";
import { action } from "@ember/object";
import { clipboardCopy } from "discourse/lib/utilities";

export default class AdminCustomizeColorsShowController extends Controller {
  @discourseComputed("model.colors", "onlyOverridden")
  colors(allColors, onlyOverridden) {
    if (onlyOverridden) {
      return allColors.filterBy("overridden");
    } else {
      return allColors;
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
        I18n.t("admin.customize.copied_to_clipboard")
      );
    } else {
      this.set(
        "model.savingStatus",
        I18n.t("admin.customize.copy_to_clipboard_error")
      );
    }

    later(() => {
      this.set("model.savingStatus", null);
    }, 2000);
  }

  @action
  copy() {
    const newColorScheme = this.model.copy();
    newColorScheme.set(
      "name",
      I18n.t("admin.customize.colors.copy_name_prefix") +
        " " +
        this.get("model.name")
    );
    newColorScheme.save().then(() => {
      this.allColors.pushObject(newColorScheme);
      this.replaceRoute("adminCustomize.colors.show", newColorScheme);
    });
  }

  @action
  save() {
    this.model.save();
  }

  @action
  applyUserSelectable() {
    this.model.updateUserSelectable(this.get("model.user_selectable"));
  }

  @action
  destroy() {
    return bootbox.confirm(
      I18n.t("admin.customize.colors.delete_confirm"),
      I18n.t("no_value"),
      I18n.t("yes_value"),
      (result) => {
        if (result) {
          this.model.destroy().then(() => {
            this.allColors.removeObject(this.model);
            this.replaceRoute("adminCustomize.colors");
          });
        }
      }
    );
  }
}
