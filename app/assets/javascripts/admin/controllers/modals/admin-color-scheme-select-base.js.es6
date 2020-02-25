import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Controller.extend(ModalFunctionality, {
  adminCustomizeColors: inject(),

  selectedBaseThemeId: null,

  init() {
    this._super(...arguments);

    const defaultScheme = this.get(
      "adminCustomizeColors.baseColorSchemes.0.base_scheme_id"
    );
    this.set("selectedBaseThemeId", defaultScheme);
  },

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
