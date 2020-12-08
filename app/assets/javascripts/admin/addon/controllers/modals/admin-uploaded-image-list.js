import { observes, on } from "discourse-common/utils/decorators";
import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Controller.extend(ModalFunctionality, {
  @on("init")
  @observes("model.value")
  _setup() {
    const value = this.get("model.value");
    this.set("images", value && value.length ? value.split("|") : []);
  },

  actions: {
    uploadDone({ url }) {
      this.images.addObject(url);
    },

    remove(url) {
      this.images.removeObject(url);
    },

    close() {
      this.save(this.images.join("|"));
      this.send("closeModal");
    },
  },
});
