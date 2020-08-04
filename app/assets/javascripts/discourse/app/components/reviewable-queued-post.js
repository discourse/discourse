import Component from "@ember/component";
import showModal from "discourse/lib/show-modal";

export default Component.extend({
  actions: {
    showRawEmail() {
      showModal("raw-email").set("rawEmail", this.reviewable.payload.raw_email);
    }
  }
});
