import Component from "@ember/component";
import { action } from "@ember/object";
import showModal from "discourse/lib/show-modal";

export default Component.extend({
  @action
  showRawEmail(event) {
    event?.preventDefault();
    showModal("raw-email").set("rawEmail", this.reviewable.payload.raw_email);
  },
});
