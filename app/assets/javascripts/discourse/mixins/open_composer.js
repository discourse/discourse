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
  }

});

