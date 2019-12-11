// import { next } from "@ember/runloop";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
// import { default as discourseComputed } from "discourse-common/utils/decorators";

export default Controller.extend(ModalFunctionality, {
  existingFeaturedTopic: null,
  newFeaturedTopic: null,
  saving: false,

  init() {
    this._super(...arguments);
  },

  topicController: inject("topic"),

  onShow() {
    this.setProperties({
      "modal.modalClass": "feature-topic-on-profile-modal",
      saving: false
    });
  },

  actions: {}
});
