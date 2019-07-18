import { popupAjaxError } from "discourse/lib/ajax-error";

export default Ember.Controller.extend({
  publicCategoryId: null,
  saving: true,

  onShow() {
    this.publicCategoryId = null;
    this.saving = false;
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
    }
  }
});
