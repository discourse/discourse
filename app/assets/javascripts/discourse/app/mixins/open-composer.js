// This mixin allows a route to open the composer
import Composer from "discourse/models/composer";
import Mixin from "@ember/object/mixin";

export default Mixin.create({
  openComposer(controller) {
    let categoryId = controller.get("category.id");
    if (
      categoryId &&
      controller.category.isUncategorizedCategory &&
      !this.siteSettings.allow_uncategorized_topics
    ) {
      categoryId = null;
    }

    this.controllerFor("composer").open({
      categoryId,
      action: Composer.CREATE_TOPIC,
      draftKey: controller.get("model.draft_key") || Composer.NEW_TOPIC_KEY,
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
      draftKey: controller.get("model.draft_key") || Composer.NEW_TOPIC_KEY,
      draftSequence: controller.get("model.draft_sequence")
    });
  },

  openComposerWithMessageParams(recipients, topicTitle, topicBody) {
    this.controllerFor("composer").open({
      action: Composer.PRIVATE_MESSAGE,
      recipients,
      topicTitle,
      topicBody,
      archetypeId: "private_message",
      draftKey: Composer.NEW_PRIVATE_MESSAGE_KEY
    });
  }
});
