import Controller from "@ember/controller";
import { popupAjaxError } from "discourse/lib/ajax-error";

const MAX_FIELDS = 20;

export default Controller.extend({
  fieldTypes: null,
  createDisabled: Ember.computed.gte("model.length", MAX_FIELDS),
  sortedFields: Ember.computed.sort("model", "fieldSortOrder"),

  init() {
    this._super(...arguments);

    this.fieldSortOrder = ["position"];
  },

  actions: {
    createField() {
      const f = this.store.createRecord("user-field", {
        field_type: "text",
        position: MAX_FIELDS
      });
      this.model.pushObject(f);
    },

    moveUp(f) {
      const idx = this.sortedFields.indexOf(f);
      if (idx) {
        const prev = this.sortedFields.objectAt(idx - 1);
        const prevPos = prev.get("position");

        prev.update({ position: f.get("position") });
        f.update({ position: prevPos });
      }
    },

    moveDown(f) {
      const idx = this.sortedFields.indexOf(f);
      if (idx > -1) {
        const next = this.sortedFields.objectAt(idx + 1);
        const nextPos = next.get("position");

        next.update({ position: f.get("position") });
        f.update({ position: nextPos });
      }
    },

    destroy(f) {
      const model = this.model;

      // Only confirm if we already been saved
      if (f.get("id")) {
        bootbox.confirm(I18n.t("admin.user_fields.delete_confirm"), function(
          result
        ) {
          if (result) {
            f.destroyRecord()
              .then(function() {
                model.removeObject(f);
              })
              .catch(popupAjaxError);
          }
        });
      } else {
        model.removeObject(f);
      }
    }
  }
});
