import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Ember.Controller.extend(ModalFunctionality, {
  adminCustomizeColors: Ember.inject.controller(),

  actions: {
    selectBase() {
      this.get("adminCustomizeColors").send(
        "newColorSchemeWithBase",
        this.get("selectedBaseThemeId")
      );
      this.send("closeModal");
    }
  }
});
