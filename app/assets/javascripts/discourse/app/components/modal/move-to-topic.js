import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { applyValueTransformer } from "discourse/lib/transformer";
import DiscourseURL from "discourse/lib/url";
import { mergeTopic, movePosts } from "discourse/models/topic";
import { i18n } from "discourse-i18n";

export default class MoveToTopic extends Component {
  @service currentUser;
  @service site;

  @tracked topicName;
  @tracked saving = false;
  @tracked categoryId;
  @tracked tags;
  @tracked participants = [];
  @tracked chronologicalOrder = false;
  @tracked selection = "new_topic";
  @tracked selectedTopic;
  @tracked flash;

  constructor() {
    super(...arguments);
    if (this.args.model.topic.isPrivateMessage) {
      this.selection = this.canSplitToPM ? "new_message" : "existing_message";
    } else if (!this.canSplitTopic) {
      this.selection = "existing_topic";
    }
  }

  get newTopic() {
    return this.selection === "new_topic";
  }

  get existingTopic() {
    return this.selection === "existing_topic";
  }

  get newMessage() {
    return this.selection === "new_message";
  }

  get existingMessage() {
    return this.selection === "existing_message";
  }

  get buttonDisabled() {
    return (
      this.saving || (isEmpty(this.selectedTopic) && isEmpty(this.topicName))
    );
  }

  get buttonTitle() {
    if (this.newTopic) {
      return "topic.split_topic.title";
    } else if (this.existingTopic) {
      return "topic.merge_topic.title";
    } else if (this.newMessage) {
      return "topic.move_to_new_message.title";
    } else if (this.existingMessage) {
      return "topic.move_to_existing_message.title";
    } else {
      return "saving";
    }
  }

  get canSplitTopic() {
    return (
      !this.args.model.selectedAllPosts &&
      this.args.model.selectedPosts.length > 0 &&
      this.args.model.selectedPosts.sort(
        (a, b) => a.post_number - b.post_number
      )[0].post_type === this.site.get("post_types.regular")
    );
  }

  get canSplitToPM() {
    return this.canSplitTopic && this.currentUser?.admin;
  }

  get canAddTags() {
    return this.site.can_create_tag;
  }

  get canTagMessages() {
    return this.site.can_tag_pms;
  }

  @action
  performMove() {
    if (this.newTopic) {
      this.movePostsTo("newTopic");
    } else if (this.existingTopic) {
      this.movePostsTo("existingTopic");
    } else if (this.newMessage) {
      this.movePostsTo("newMessage");
    } else if (this.existingMessage) {
      this.movePostsTo("existingMessage");
    }
  }

  @action
  async movePostsTo(type) {
    this.saving = true;
    this.flash = null;
    let mergeOptions, moveOptions;

    if (type === "existingTopic") {
      mergeOptions = {
        destination_topic_id: this.selectedTopic.id,
        chronological_order: this.chronologicalOrder,
      };
      moveOptions = {
        post_ids: this.args.model.selectedPostIds,
        ...mergeOptions,
      };
    } else if (type === "existingMessage") {
      mergeOptions = {
        destination_topic_id: this.selectedTopic.id,
        participants: this.participants.join(","),
        archetype: "private_message",
        chronological_order: this.chronologicalOrder,
      };
      moveOptions = {
        post_ids: this.args.model.selectedPostIds,
        ...mergeOptions,
      };
    } else if (type === "newTopic") {
      mergeOptions = {};
      moveOptions = {
        title: this.topicName,
        post_ids: this.args.model.selectedPostIds,
        category_id: this.categoryId,
        tags: this.tags,
      };
    } else {
      mergeOptions = {};
      moveOptions = {
        title: this.topicName,
        post_ids: this.args.model.selectedPostIds,
        tags: this.tags,
        archetype: "private_message",
      };
    }

    mergeOptions = applyValueTransformer(
      "move-to-topic-merge-options",
      mergeOptions
    );
    moveOptions = applyValueTransformer(
      "move-to-topic-move-options",
      moveOptions
    );

    try {
      let result;
      if (this.args.model.selectedAllPosts) {
        result = await mergeTopic(this.args.model.topic.id, mergeOptions);
      } else {
        result = await movePosts(this.args.model.topic.id, moveOptions);
      }

      this.args.closeModal();
      this.args.model.toggleMultiSelect();
      DiscourseURL.routeTo(result.url);
    } catch {
      this.flash = i18n("topic.move_to.error");
    } finally {
      this.saving = false;
    }
  }

  @action
  updateTopicName(newName) {
    this.topicName = newName;
  }

  @action
  updateCategoryId(newId) {
    this.categoryId = newId;
  }

  @action
  updateTags(newTags) {
    this.tags = newTags;
  }

  @action
  newTopicSelected(topic) {
    this.selectedTopic = topic.id;
  }
}
