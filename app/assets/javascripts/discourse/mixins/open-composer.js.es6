// This mixin allows a route to open the composer
import Composer from "discourse/models/composer";

export default Ember.Mixin.create({
  openComposer(controller) {
    this.controllerFor("composer").open({
      categoryId: controller.get("category.id"),
      action: Composer.CREATE_TOPIC,
      draftKey: controller.get("model.draft_key") || Composer.CREATE_TOPIC,
      draftSequence: controller.get("model.draft_sequence") || 0
    });
  },

  openComposerWithTopicParams(
    controller,
    topicTitle,
    topicBody,
    topicCategoryId,
    topicTags
  ) {
    this.controllerFor("composer").open({
      action: Composer.CREATE_TOPIC,
      topicTitle,
      topicBody,
      topicCategoryId,
      topicTags,
      draftKey: controller.get("model.draft_key"),
      draftSequence: controller.get("model.draft_sequence")
    });
  },

  openComposerWithMessageParams(usernames, topicTitle, topicBody) {
    this.controllerFor("composer").open({
      action: Composer.PRIVATE_MESSAGE,
      usernames,
      topicTitle,
      topicBody,
      archetypeId: "private_message",
      draftKey: Composer.NEW_PRIVATE_MESSAGE_KEY
    });
  }
});
