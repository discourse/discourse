import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import discourseComputed from "discourse-common/utils/decorators";

export default Controller.extend(ModalFunctionality, {
  differentDraft: null,

  @discourseComputed()
  keyPrefix() {
    return this.model.action === "edit" ? "post.abandon_edit" : "post.abandon";
  },

  @discourseComputed("keyPrefix")
  descriptionKey(keyPrefix) {
    return `${keyPrefix}.confirm`;
  },

  @discourseComputed("keyPrefix")
  discardKey(keyPrefix) {
    return `${keyPrefix}.yes_value`;
  },

  @discourseComputed("keyPrefix", "differentDraft")
  saveKey(keyPrefix, differentDraft) {
    return differentDraft
      ? `${keyPrefix}.no_save_draft`
      : `${keyPrefix}.no_value`;
  },

  actions: {
    _destroyDraft() {
      this.onDestroyDraft();
      this.send("closeModal");
    },
    _saveDraft() {
      this.onSaveDraft();
      this.send("closeModal");
    },
  },
});
