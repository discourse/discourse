// This mixin allows a route to open the composer

export default Ember.Mixin.create({

  openComposer(controller) {
    const Composer = require('discourse/models/composer').default;
    this.controllerFor('composer').open({
      categoryId: controller.get('category.id'),
      action: Composer.CREATE_TOPIC,
      draftKey: controller.get('model.draft_key'),
      draftSequence: controller.get('model.draft_sequence')
    });
  },

  openComposerWithParams(controller, topicTitle, topicBody, topicCategoryId, topicCategory) {
    const Composer = require('discourse/models/composer').default;
    this.controllerFor('composer').open({
      action: Composer.CREATE_TOPIC,
      topicTitle,
      topicBody,
      topicCategoryId,
      topicCategory,
      draftKey: controller.get('model.draft_key'),
      draftSequence: controller.get('model.draft_sequence')
    });
  }

});
