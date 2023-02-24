import { inject as controller } from "@ember/controller";
import DiscourseURL from "discourse/lib/url";
import I18n from "I18n";
import Modal from "discourse/controllers/modal";
import Topic from "discourse/models/topic";
import { alias } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";
import { next } from "@ember/runloop";

export default Modal.extend({
  topicController: controller("topic"),

  saving: false,
  newOwner: null,

  selectedPostsCount: alias("topicController.selectedPostsCount"),
  selectedPostsUsername: alias("topicController.selectedPostsUsername"),

  @discourseComputed("saving", "newOwner")
  buttonDisabled(saving, newUser) {
    return saving || isEmpty(newUser);
  },

  onShow() {
    this.setProperties({
      saving: false,
      newOwner: null,
    });
  },

  actions: {
    changeOwnershipOfPosts() {
      this.set("saving", true);

      const options = {
        post_ids: this.get("topicController.selectedPostIds"),
        username: this.newOwner,
      };

      Topic.changeOwners(this.get("topicController.model.id"), options).then(
        () => {
          this.send("closeModal");
          this.topicController.send("deselectAll");
          if (this.get("topicController.multiSelect")) {
            this.topicController.send("toggleMultiSelect");
          }
          next(() =>
            DiscourseURL.routeTo(this.get("topicController.model.url"))
          );
        },
        () => {
          this.flash(I18n.t("topic.change_owner.error"), "error");
          this.set("saving", false);
        }
      );

      return false;
    },

    updateNewOwner(selected) {
      this.set("newOwner", selected.firstObject);
    },
  },
});
