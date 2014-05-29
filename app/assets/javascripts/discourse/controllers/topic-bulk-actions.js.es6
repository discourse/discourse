/**
  Modal for performing bulk actions on topics

  @class TopicBulkActionsController
  @extends Ember.ArrayController
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
export default Ember.ArrayController.extend(Discourse.ModalFunctionality, {
  needs: ['discovery/topics'],

  onShow: function() {
    this.set('controllers.modal.modalClass', 'topic-bulk-actions-modal small');
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

  forEachPerformed: function(operation, cb) {
    var self = this;
    this.perform(operation).then(function (topics) {
      if (topics) {
        topics.forEach(cb);
        self.send('closeModal');
      }
    });
  },

  performAndRefresh: function(operation) {
    var self = this;
    return this.perform(operation).then(function() {
      self.get('controllers.discovery/topics').send('refresh');
      self.send('closeModal');
    });
  },

  actions: {
    showChangeCategory: function() {
      this.send('changeBulkTemplate', 'modal/bulk_change_category');
      this.set('controllers.modal.modalClass', 'topic-bulk-actions-modal full');
    },

    showNotificationLevel: function() {
      this.send('changeBulkTemplate', 'modal/bulk_notification_level');
    },

    closeTopics: function() {
      this.forEachPerformed({type: 'close'}, function(t) {
        t.set('closed', true);
      });
    },

    changeCategory: function() {
      var category = Discourse.Category.findById(parseInt(this.get('newCategoryId'), 10)),
          categoryName = (category ? category.get('name') : null),
          self = this;
      this.perform({type: 'change_category', category_name: categoryName}).then(function(topics) {
        topics.forEach(function(t) {
          t.set('category', category);
        });
        self.send('closeModal');
      });
    },

    resetRead: function() {
      this.performAndRefresh({ type: 'reset_read' });
    }
  }
});
