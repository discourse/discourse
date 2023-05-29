import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { ajax } from "discourse/lib/ajax";
import { action } from "@ember/object";
import { getOwner } from "discourse-common/lib/get-owner";

export default class DismissNewController extends Controller.extend(
  ModalFunctionality
) {
  @action
  close() {
    ajax("/topics/reset-new", {
      type: "PUT",
      data: {
        ...this.model,
        dismiss_topics: this.model.dismissTopics,
        dismiss_posts: this.model.dismissPosts,
      },
    }).then((result) => {
      if (this.model.dismissPosts) {
        const controller = getOwner(this).lookup("controller:discovery/topics");
        this.topicTrackingState.removeTopics(result.topic_ids);
        controller.send(
          "refresh",
          this.model.tracked ? { skipResettingParams: ["filter", "f"] } : {}
        );
      }
      this.send("closeModal");
    });
  }
}
