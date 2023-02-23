import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Controller.extend(ModalFunctionality, {
  actions: {
    editSecurityKey() {
      this.user
        .updateSecurityKey(this.model.id, this.model.name, false)
        .then((response) => {
          if (response.error) {
            return;
          }
          this.markDirty();
        })
        .catch((error) => {
          this.onError(error);
        })
        .finally(() => {
          this.set("loading", false);
          this.send("closeModal");
        });
    },
  },
});
