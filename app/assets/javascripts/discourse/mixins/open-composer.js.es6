// This mixin allows a route to open the composer

export default Ember.Mixin.create({

  openComposer(controller) {
    this.controllerFor('composer').open({
      categoryId: controller.get('category.id'),
      action: Discourse.Composer.CREATE_TOPIC,
      draftKey: controller.get('model.draft_key'),
      draftSequence: controller.get('model.draft_sequence')
    });
  },

  openComposerWithParams(controller, topicTitle, topicBody, topicCategoryId, topicCategory) {
    this.controllerFor('composer').open({
      action: Discourse.Composer.CREATE_TOPIC,
      topicTitle,
      topicBody,
      topicCategoryId,
      topicCategory,
      draftKey: controller.get('model.draft_key'),
      draftSequence: controller.get('model.draft_sequence')
    });
  }

});
