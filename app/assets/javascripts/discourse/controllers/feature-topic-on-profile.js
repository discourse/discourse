import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { none } from "@ember/object/computed";

export default Controller.extend(ModalFunctionality, {
  newFeaturedTopic: null,
  saving: false,
  noTopicSelected: none("newFeaturedTopic"),

  onClose() {
    this.set("newFeaturedTopic", null);
  },

  onShow() {
    this.set("modal.modalClass", "choose-topic-modal");
  },

  actions: {
    save() {
      return ajax(`/u/${this.model.username}/feature-topic`, {
        type: "PUT",
        data: { topic_id: this.newFeaturedTopic.id }
      })
        .then(() => {
          this.model.set("featured_topic", this.newFeaturedTopic);
          this.send("closeModal");
        })
        .catch(popupAjaxError);
    },

    newTopicSelected(topic) {
      this.set("newFeaturedTopic", topic);
    }
  }
});
