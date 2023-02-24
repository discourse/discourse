import { observes, on } from "discourse-common/utils/decorators";
import { action } from "@ember/object";
import Modal from "discourse/controllers/modal";

export default Modal.extend({
  @on("init")
  @observes("model.value")
  _setup() {
    const value = this.get("model.value");
    this.set("images", value && value.length ? value.split("|") : []);
  },

  @action
  remove(url, event) {
    event?.preventDefault();
    this.images.removeObject(url);
  },

  actions: {
    uploadDone({ url }) {
      this.images.addObject(url);
    },

    close() {
      this.save(this.images.join("|"));
      this.send("closeModal");
    },
  },
});
