import { observes, on } from "discourse-common/utils/decorators";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Controller.extend(ModalFunctionality, {
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
