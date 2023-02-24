import Modal from "discourse/controllers/modal";

export default Modal.extend({
  actions: {
    editSecondFactor() {
      this.user
        .updateSecondFactor(
          this.model.id,
          this.model.name,
          false,
          this.model.method
        )
        .then((response) => {
          if (response.error) {
            return;
          }
          this.markDirty();
        })
        .catch((error) => {
          this.send("closeModal");
          this.onError(error);
        })
        .finally(() => {
          this.set("loading", false);
          this.send("closeModal");
        });
    },
  },
});
