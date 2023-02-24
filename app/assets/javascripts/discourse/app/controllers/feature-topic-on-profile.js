import Modal from "discourse/controllers/modal";
import { ajax } from "discourse/lib/ajax";
import { none } from "@ember/object/computed";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Modal.extend({
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
        data: { topic_id: this.newFeaturedTopic.id },
      })
        .then(() => {
          this.model.set("featured_topic", this.newFeaturedTopic);
          this.send("closeModal");
        })
        .catch(popupAjaxError);
    },

    newTopicSelected(topic) {
      this.set("newFeaturedTopic", topic);
    },
  },
});
