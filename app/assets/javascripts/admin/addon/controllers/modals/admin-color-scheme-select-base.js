import { action } from "@ember/object";
import Controller, { inject as controller } from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default class AdminColorSchemeSelectBaseController extends Controller.extend(
  ModalFunctionality
) {
  @controller adminCustomizeColors;

  selectedBaseThemeId = null;

  init() {
    super.init(...arguments);

    const defaultScheme = this.get(
      "adminCustomizeColors.baseColorSchemes.0.base_scheme_id"
    );
    this.set("selectedBaseThemeId", defaultScheme);
  }

  @action
  selectBase() {
    this.adminCustomizeColors.send(
      "newColorSchemeWithBase",
      this.selectedBaseThemeId
    );
    this.send("closeModal");
  }
}
