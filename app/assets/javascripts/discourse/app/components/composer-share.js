import Component from "@ember/component";
import showModal from "discourse/lib/show-modal";
import { getOwner } from "discourse-common/lib/get-owner";

export default Component.extend({
  actions: {
    shareModal() {
      const composer = getOwner(this).lookup("controller:composer");
      const controller = showModal("share-topic");
      controller.setProperties({
        allowInvites:
          composer.topic.details.can_invite_to &&
          !composer.topic.archived &&
          !composer.topic.closed &&
          !composer.topic.deleted,
        topic: composer.topic,
      });
    },
  },
});
