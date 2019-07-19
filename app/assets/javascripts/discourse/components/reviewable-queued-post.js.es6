import showModal from "discourse/lib/show-modal";

export default Ember.Component.extend({
  actions: {
    showRawEmail() {
      showModal("raw-email").set("rawEmail", this.reviewable.payload.raw_email);
    }
  }
});
