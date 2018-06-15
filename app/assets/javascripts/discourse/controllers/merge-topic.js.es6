import ModalFunctionality from "discourse/mixins/modal-functionality";
import { movePosts, mergeTopic } from "discourse/models/topic";
import DiscourseURL from "discourse/lib/url";
import computed from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend(ModalFunctionality, {
  topicController: Ember.inject.controller("topic"),

  saving: false,
  selectedTopicId: null,

  selectedPostsCount: Ember.computed.alias(
    "topicController.selectedPostsCount"
  ),

  @computed("saving", "selectedTopicId")
  buttonDisabled(saving, selectedTopicId) {
    return saving || Ember.isEmpty(selectedTopicId);
  },

  @computed("saving")
  buttonTitle(saving) {
    return saving ? I18n.t("saving") : I18n.t("topic.merge_topic.title");
  },

  onShow() {
    this.set("modal.modalClass", "split-modal");
  },

  actions: {
    movePostsToExistingTopic() {
      const topicId = this.get("model.id");

      this.set("saving", true);

      let promise = this.get("topicController.selectedAllPosts")
        ? mergeTopic(topicId, this.get("selectedTopicId"))
        : movePosts(topicId, {
            destination_topic_id: this.get("selectedTopicId"),
            post_ids: this.get("topicController.selectedPostIds")
          });

      promise
        .then(result => {
          this.send("closeModal");
          this.get("topicController").send("toggleMultiSelect");
          Ember.run.next(() => DiscourseURL.routeTo(result.url));
        })
        .catch(() => {
          this.flash(I18n.t("topic.merge_topic.error"));
        })
        .finally(() => {
          this.set("saving", false);
        });

      return false;
    }
  }
});
