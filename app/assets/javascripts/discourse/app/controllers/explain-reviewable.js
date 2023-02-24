import Modal from "discourse/controllers/modal";

export default Modal.extend({
  loading: null,
  reviewableExplanation: null,

  onShow() {
    this.setProperties({ loading: true, reviewableExplanation: null });

    this.store
      .find("reviewable-explanation", this.model.id)
      .then((result) => this.set("reviewableExplanation", result))
      .finally(() => this.set("loading", false));
  },
});
