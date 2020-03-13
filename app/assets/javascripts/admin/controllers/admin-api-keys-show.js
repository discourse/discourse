import { bufferedProperty } from "discourse/mixins/buffered-content";
import Controller from "@ember/controller";
import { isEmpty } from "@ember/utils";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { empty } from "@ember/object/computed";

export default Controller.extend(bufferedProperty("model"), {
  isNew: empty("model.id"),

  actions: {
    saveDescription() {
      const buffered = this.buffered;
      const attrs = buffered.getProperties("description");

      this.model
        .save(attrs)
        .then(() => {
          this.set("editingDescription", false);
          this.rollbackBuffer();
        })
        .catch(popupAjaxError);
    },

    cancel() {
      const id = this.get("userField.id");
      if (isEmpty(id)) {
        this.destroyAction(this.userField);
      } else {
        this.rollbackBuffer();
        this.set("editing", false);
      }
    },

    editDescription() {
      this.toggleProperty("editingDescription");
      if (!this.editingDescription) {
        this.rollbackBuffer();
      }
    },

    revokeKey(key) {
      key.revoke().catch(popupAjaxError);
    },

    deleteKey(key) {
      key
        .destroyRecord()
        .then(() => this.transitionToRoute("adminApiKeys.index"))
        .catch(popupAjaxError);
    },

    undoRevokeKey(key) {
      key.undoRevoke().catch(popupAjaxError);
    }
  }
});
