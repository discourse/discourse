import { inject as controller } from "@ember/controller";
import Modal from "discourse/controllers/modal";

export default Modal.extend({
  adminCustomizeColors: controller(),

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
    },
  },
});
