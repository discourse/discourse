import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Ember.Controller.extend(ModalFunctionality, {
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
