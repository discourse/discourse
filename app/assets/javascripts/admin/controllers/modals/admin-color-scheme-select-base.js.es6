import { inject } from '@ember/controller';
import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Controller.extend(ModalFunctionality, {
  adminCustomizeColors: inject(),

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
