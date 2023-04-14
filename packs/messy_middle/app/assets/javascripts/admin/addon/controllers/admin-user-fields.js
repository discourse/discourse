import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { gte, sort } from "@ember/object/computed";
import Controller from "@ember/controller";
import I18n from "I18n";
import { popupAjaxError } from "discourse/lib/ajax-error";

const MAX_FIELDS = 30;

export default class AdminUserFieldsController extends Controller {
  @service dialog;

  fieldTypes = null;

  @gte("model.length", MAX_FIELDS) createDisabled;
  @sort("model", "fieldSortOrder") sortedFields;

  fieldSortOrder = ["position"];

  @action
  createField() {
    const f = this.store.createRecord("user-field", {
      field_type: "text",
      position: MAX_FIELDS,
    });
    this.model.pushObject(f);
  }

  @action
  moveUp(f) {
    const idx = this.sortedFields.indexOf(f);
    if (idx) {
      const prev = this.sortedFields.objectAt(idx - 1);
      const prevPos = prev.get("position");

      prev.update({ position: f.get("position") });
      f.update({ position: prevPos });
    }
  }

  @action
  moveDown(f) {
    const idx = this.sortedFields.indexOf(f);
    if (idx > -1) {
      const next = this.sortedFields.objectAt(idx + 1);
      const nextPos = next.get("position");

      next.update({ position: f.get("position") });
      f.update({ position: nextPos });
    }
  }

  @action
  destroyField(f) {
    const model = this.model;

    // Only confirm if we already been saved
    if (f.get("id")) {
      this.dialog.yesNoConfirm({
        message: I18n.t("admin.user_fields.delete_confirm"),
        didConfirm: () => {
          return f
            .destroyRecord()
            .then(function () {
              model.removeObject(f);
            })
            .catch(popupAjaxError);
        },
      });
    } else {
      model.removeObject(f);
    }
  }
}
