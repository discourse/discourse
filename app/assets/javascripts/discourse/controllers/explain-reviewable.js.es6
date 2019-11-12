import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Controller.extend(ModalFunctionality, {
  loading: null,
  reviewableExplanation: null,

  onShow() {
    this.setProperties({ loading: true, reviewableExplanation: null });

    this.store
      .find("reviewable-explanation", this.model.id)
      .then(result => this.set("reviewableExplanation", result))
      .finally(() => this.set("loading", false));
  }
});
