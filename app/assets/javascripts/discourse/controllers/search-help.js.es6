import discourseComputed from "discourse-common/utils/decorators";
import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Controller.extend(ModalFunctionality, {
  @discourseComputed
  showGoogleSearch() {
    return !Discourse.SiteSettings.login_required;
  }
});
