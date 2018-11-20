import ModalFunctionality from "discourse/mixins/modal-functionality";
import { extractError } from "discourse/lib/ajax-error";
import { movePosts } from "discourse/models/topic";
import DiscourseURL from "discourse/lib/url";
import { default as computed } from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend(ModalFunctionality, {
  topicName: null,
  saving: false,
  categoryId: null,
  tags: null,
  canAddTags: Ember.computed.alias("site.can_create_tag"),

  topicController: Ember.inject.controller("topic"),
  selectedPostsCount: Ember.computed.alias(
    "topicController.selectedPostsCount"
  ),

  @computed("saving", "topicName")
  buttonDisabled(saving, topicName) {
    return saving || Ember.isEmpty(topicName);
  },

  @computed("saving")
  buttonTitle(saving) {
    return saving ? I18n.t("saving") : I18n.t("topic.split_topic.action");
  },

  onShow() {
    this.setProperties({
      "modal.modalClass": "split-modal",
      saving: false,
      categoryId: null,
      topicName: "",
      tags: null
    });
  },

  actions: {
    movePostsToNewTopic() {
      this.set("saving", true);

      const options = {
        title: this.get("topicName"),
        post_ids: this.get("topicController.selectedPostIds"),
        category_id: this.get("categoryId"),
        tags: this.get("tags")
      };

      movePosts(this.get("model.id"), options)
        .then(result => {
          this.send("closeModal");
          this.get("topicController").send("toggleMultiSelect");
          Ember.run.next(() => DiscourseURL.routeTo(result.url));
        })
        .catch(xhr => {
          this.flash(extractError(xhr, I18n.t("topic.split_topic.error")));
        })
        .finally(() => {
          this.set("saving", false);
        });

      return false;
    }
  }
});
