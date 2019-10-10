import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Ember.Controller.extend(ModalFunctionality, {
  onShow() {
    this.set("updateExistingUsers", null);
  },

  actions: {
    updateExistingUsers() {
      this.set("updateExistingUsers", true);
      this.send("closeModal");
    },

    cancel() {
      this.set("updateExistingUsers", false);
      this.send("closeModal");
    }
  }
});
