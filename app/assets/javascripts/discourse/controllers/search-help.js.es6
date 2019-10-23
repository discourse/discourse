import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import computed from "ember-addons/ember-computed-decorators";

export default Controller.extend(ModalFunctionality, {
  @computed
  showGoogleSearch() {
    return !Discourse.SiteSettings.login_required;
  }
});
