// import { next } from "@ember/runloop";
import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
// import { default as discourseComputed } from "discourse-common/utils/decorators";

export default Controller.extend(ModalFunctionality, {
  existingFeaturedTopic: null,
  newFeaturedTopicId: null,
  saving: false,
  noTopicSelected: true,

  actions: {
    save() {
      return null;
    }
  }
});
