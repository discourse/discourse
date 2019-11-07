import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";
import { alias } from "@ember/object/computed";
import { next } from "@ember/runloop";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import DiscourseURL from "discourse/lib/url";
import Topic from "discourse/models/topic";

export default Controller.extend(ModalFunctionality, {
  topicController: inject("topic"),

  saving: false,
  new_user: null,

  selectedPostsCount: alias("topicController.selectedPostsCount"),
  selectedPostsUsername: alias("topicController.selectedPostsUsername"),

  @discourseComputed("saving", "new_user")
  buttonDisabled(saving, newUser) {
    return saving || isEmpty(newUser);
  },

  onShow() {
    this.setProperties({
      saving: false,
      new_user: ""
    });
  },

  actions: {
    changeOwnershipOfPosts() {
      this.set("saving", true);

      const options = {
        post_ids: this.get("topicController.selectedPostIds"),
        username: this.new_user
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
          this.flash(I18n.t("topic.change_owner.error"), "alert-error");
          this.set("saving", false);
        }
      );

      return false;
    }
  }
});
