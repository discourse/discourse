import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Controller.extend(ModalFunctionality, {
  adminCustomizeColors: Ember.inject.controller(),

  actions: {
    selectBase() {
      this.adminCustomizeColors.send(
        "newColorSchemeWithBase",
        this.selectedBaseThemeId
      );
      this.send("closeModal");
    }
  }
});
