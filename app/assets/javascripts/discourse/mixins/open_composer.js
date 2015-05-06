/**
  This mixin allows a route to open the composer

  @class Discourse.OpenComposer
  @extends Ember.Mixin
  @namespace Discourse
  @module Discourse
**/
Discourse.OpenComposer = Em.Mixin.create({

  openComposer: function(controller) {
    this.controllerFor('composer').open({
      categoryId: controller.get('category.id'),
      action: Discourse.Composer.CREATE_TOPIC,
      draftKey: controller.get('draft_key'),
      draftSequence: controller.get('draft_sequence')
    });
  },

  openComposerWithParams: function(controller, title, body, category_id, category) {
    this.controllerFor('composer').open({
      action: Discourse.Composer.CREATE_TOPIC,
      topicTitle: title,
      topicBody: body,
      topicCategoryId: category_id,
      topicCategory: category,
      draftKey: controller.get('draft_key'),
      draftSequence: controller.get('draft_sequence')
    });
  }

});
