import { bufferedProperty } from "discourse/mixins/buffered-content";
import { default as computed } from "ember-addons/ember-computed-decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Ember.Controller.extend(bufferedProperty("model"), {
  @computed("model.id")
  isNew(id) {
    return id === undefined;
  },

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
      if (Ember.isEmpty(id)) {
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
