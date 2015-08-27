import ModalFunctionality from 'discourse/mixins/modal-functionality';

const _buttons = [];

function addBulkButton(action, key) {
  _buttons.push({ action: action, label: "topics.bulk." + key });
}

// Default buttons
addBulkButton('showChangeCategory', 'change_category');
addBulkButton('deleteTopics', 'delete');
addBulkButton('closeTopics', 'close_topics');
addBulkButton('archiveTopics', 'archive_topics');
addBulkButton('showNotificationLevel', 'notification_level');
addBulkButton('resetRead', 'reset_read');

// Modal for performing bulk actions on topics
export default Ember.ArrayController.extend(ModalFunctionality, {
  buttonRows: null,

  onShow: function() {
    this.set('controllers.modal.modalClass', 'topic-bulk-actions-modal small');

    const buttonRows = [];
    let row = [];
    _buttons.forEach(function(b) {
      row.push(b);
      if (row.length === 4) {
        buttonRows.push(row);
        row = [];
      }
    });
    if (row.length) { buttonRows.push(row); }

    this.set('buttonRows', buttonRows);
    this.send('changeBulkTemplate', 'modal/bulk_actions_buttons');
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
        const refreshTarget = self.get('refreshTarget');
        if (refreshTarget) { refreshTarget.send('refresh'); }
        self.send('closeModal');
      }
    });
  },

  performAndRefresh: function(operation) {
    const self = this;
    return this.perform(operation).then(function() {
      const refreshTarget = self.get('refreshTarget');
      if (refreshTarget) { refreshTarget.send('refresh'); }
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
        const refreshTarget = self.get('refreshTarget');
        if (refreshTarget) { refreshTarget.send('refresh'); }
        self.send('closeModal');
      });
    },

    resetRead: function() {
      this.performAndRefresh({ type: 'reset_read' });
    }
  }
});

export { addBulkButton };
