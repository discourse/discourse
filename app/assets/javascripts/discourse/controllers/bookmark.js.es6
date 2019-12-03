import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import discourseComputed from "discourse-common/utils/decorators";

export default Controller.extend(ModalFunctionality, {
  loading: false,
  errorMessage: null,

  onShow() {
    this.setProperties({
      errorMessage: null,
      loading: true
    });

    this.set("loading", false);
  },

  @discourseComputed()
  usingMobileDevice() {
    return this.site.mobileView;
  },

  actions: {}
});
