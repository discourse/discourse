import { next } from "@ember/runloop";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { movePosts, mergeTopic } from "discourse/models/topic";
import DiscourseURL from "discourse/lib/url";
import { default as computed } from "ember-addons/ember-computed-decorators";
import { extractError } from "discourse/lib/ajax-error";

export default Controller.extend(ModalFunctionality, {
  topicName: null,
  saving: false,
  categoryId: null,
  tags: null,
  canAddTags: Ember.computed.alias("site.can_create_tag"),
  canTagMessages: Ember.computed.alias("site.can_tag_pms"),
  selectedTopicId: null,
  newTopic: Ember.computed.equal("selection", "new_topic"),
  existingTopic: Ember.computed.equal("selection", "existing_topic"),
  newMessage: Ember.computed.equal("selection", "new_message"),
  existingMessage: Ember.computed.equal("selection", "existing_message"),
  participants: null,

  init() {
    this._super(...arguments);

    this.saveAttrNames = [
      "newTopic",
      "existingTopic",
      "newMessage",
      "existingMessage"
    ];

    this.moveTypes = [
      "newTopic",
      "existingTopic",
      "newMessage",
      "existingMessage"
    ];
  },

  topicController: inject("topic"),
  selectedPostsCount: Ember.computed.alias(
    "topicController.selectedPostsCount"
  ),
  selectedAllPosts: Ember.computed.alias("topicController.selectedAllPosts"),
  selectedPosts: Ember.computed.alias("topicController.selectedPosts"),

  @computed("saving", "selectedTopicId", "topicName")
  buttonDisabled(saving, selectedTopicId, topicName) {
    return (
      saving || (Ember.isEmpty(selectedTopicId) && Ember.isEmpty(topicName))
    );
  },

  @computed(
    "saving",
    "newTopic",
    "existingTopic",
    "newMessage",
    "existingMessage"
  )
  buttonTitle(saving, newTopic, existingTopic, newMessage, existingMessage) {
    if (newTopic) {
      return I18n.t("topic.split_topic.title");
    } else if (existingTopic) {
      return I18n.t("topic.merge_topic.title");
    } else if (newMessage) {
      return I18n.t("topic.move_to_new_message.title");
    } else if (existingMessage) {
      return I18n.t("topic.move_to_existing_message.title");
    } else {
      return I18n.t("saving");
    }
  },

  onShow() {
    this.setProperties({
      "modal.modalClass": "move-to-modal",
      saving: false,
      selection: "new_topic",
      categoryId: null,
      topicName: "",
      tags: null,
      participants: null
    });

    const isPrivateMessage = this.get("model.isPrivateMessage");
    if (isPrivateMessage) {
      this.set(
        "selection",
        this.canSplitToPM ? "new_message" : "existing_message"
      );
    } else if (!this.canSplitTopic) {
      this.set("selection", "existing_topic");
      next(() => $("#choose-topic-title").focus());
    }
  },

  @computed("selectedAllPosts", "selectedPosts", "selectedPosts.[]")
  canSplitTopic(selectedAllPosts, selectedPosts) {
    return (
      !selectedAllPosts &&
      selectedPosts.length > 0 &&
      selectedPosts.sort((a, b) => a.post_number - b.post_number)[0]
        .post_type === this.site.get("post_types.regular")
    );
  },

  @computed("canSplitTopic")
  canSplitToPM(canSplitTopic) {
    return canSplitTopic && (this.currentUser && this.currentUser.admin);
  },

  actions: {
    performMove() {
      this.moveTypes.forEach(type => {
        if (this.get(type)) {
          this.send("movePostsTo", type);
        }
      });
    },

    movePostsTo(type) {
      this.set("saving", true);
      const topicId = this.get("model.id");
      let mergeOptions, moveOptions;

      if (type === "existingTopic") {
        mergeOptions = { destination_topic_id: this.selectedTopicId };
        moveOptions = Object.assign(
          { post_ids: this.get("topicController.selectedPostIds") },
          mergeOptions
        );
      } else if (type === "existingMessage") {
        mergeOptions = {
          destination_topic_id: this.selectedTopicId,
          participants: this.participants,
          archetype: "private_message"
        };
        moveOptions = Object.assign(
          { post_ids: this.get("topicController.selectedPostIds") },
          mergeOptions
        );
      } else if (type === "newTopic") {
        mergeOptions = {};
        moveOptions = {
          title: this.topicName,
          post_ids: this.get("topicController.selectedPostIds"),
          category_id: this.categoryId,
          tags: this.tags
        };
      } else {
        mergeOptions = {};
        moveOptions = {
          title: this.topicName,
          post_ids: this.get("topicController.selectedPostIds"),
          tags: this.tags,
          archetype: "private_message"
        };
      }

      const promise = this.get("topicController.selectedAllPosts")
        ? mergeTopic(topicId, mergeOptions)
        : movePosts(topicId, moveOptions);

      promise
        .then(result => {
          this.send("closeModal");
          this.topicController.send("toggleMultiSelect");
          DiscourseURL.routeTo(result.url);
        })
        .catch(xhr => {
          this.flash(extractError(xhr, I18n.t("topic.move_to.error")));
        })
        .finally(() => {
          this.set("saving", false);
        });

      return false;
    }
  }
});
