import { on, observes } from "ember-addons/ember-computed-decorators";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Ember.Controller.extend(ModalFunctionality, {
  @on("init")
  @observes("model.value")
  _setup() {
    const value = this.get("model.value");
    this.set("images", value && value.length ? value.split("\n") : []);
  },

  actions: {
    uploadDone({ url }) {
      this.get("images").addObject(url);
    },

    remove(url) {
      this.get("images").removeObject(url);
    },

    close() {
      this.save(this.get("images").join("\n"));
      this.send("closeModal");
    }
  }
});
