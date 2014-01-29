/**
  Modal for performing bulk actions on topics

  @class TopicBulkActionsController
  @extends Ember.ArrayController
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.TopicBulkActionsController = Ember.ArrayController.extend(Discourse.ModalFunctionality, {
  onShow: function() {
    this.set('controllers.modal.modalClass', 'topic-bulk-actions-modal');
  }
});
