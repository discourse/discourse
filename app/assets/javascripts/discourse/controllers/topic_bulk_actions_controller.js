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
  },

  perform: function(operation) {
    this.set('loading', true);

    var self = this,
        topics = this.get('model');
    return Discourse.Topic.bulkOperation(this.get('model'), operation).then(function(result) {
      self.set('loading', false);
      if (result && result.topic_ids) {
        return result.topic_ids.map(function (t) {
          return topics.findBy('id', t);
        });
      }
      return result;
    }).catch(function() {
      self.set('loading', false);
    });
  },

  actions: {
    showChangeCategory: function() {
      this.send('changeBulkTemplate', 'modal/bulk_change_category');
    },

    changeCategory: function() {
      var category = Discourse.Category.findById(parseInt(this.get('newCategoryId'), 10)),
          self = this;
      this.perform({type: 'change_category', category_id: this.get('newCategoryId')}).then(function(topics) {
        topics.forEach(function(t) {
          t.set('category', category);
        });
        self.send('closeModal');
      });
    }
  }
});
