import ModalFunctionality from 'discourse/mixins/modal-functionality';

// Modal for performing bulk actions on topics
export default Ember.ArrayController.extend(ModalFunctionality, {
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
      bootbox.alert(I18n.t('generic_error'));
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

    deleteTopics: function() {
      this.performAndRefresh({type: 'delete'});
    },

    closeTopics: function() {
      this.forEachPerformed({type: 'close'}, function(t) {
        t.set('closed', true);
      });
    },

    archiveTopics: function() {
      this.forEachPerformed({type: 'archive'}, function(t) {
        t.set('archived', true);
      });
    },

    changeCategory: function() {
      var categoryId = parseInt(this.get('newCategoryId'), 10) || 0,
          category = Discourse.Category.findById(categoryId),
          self = this;
      this.perform({type: 'change_category', category_id: categoryId}).then(function(topics) {
        topics.forEach(function(t) {
          t.set('category', category);
        });
        self.get('controllers.discovery/topics').send('refresh');
        self.send('closeModal');
      });
    },

    resetRead: function() {
      this.performAndRefresh({ type: 'reset_read' });
    }
  }
});
