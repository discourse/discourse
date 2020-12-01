import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Controller.extend(ModalFunctionality, {
  publicCategoryId: null,
  saving: true,

  onShow() {
    this.setProperties({ publicCategoryId: null, saving: false });
  },

  actions: {
    makePublic() {
      let topic = this.model;
      topic
        .convertTopic("public", { categoryId: this.publicCategoryId })
        .then(() => {
          topic.set("archetype", "regular");
          topic.set("category_id", this.publicCategoryId);
          this.appEvents.trigger("header:show-topic", topic);
          this.send("closeModal");
        })
        .catch(popupAjaxError);
    },
  },
});
