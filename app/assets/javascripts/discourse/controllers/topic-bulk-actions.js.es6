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
addBulkButton('unlistTopics', 'unlist_topics');
addBulkButton('showTagTopics', 'change_tags');
addBulkButton('showAppendTagTopics', 'append_tags');

// Modal for performing bulk actions on topics
export default Ember.Controller.extend(ModalFunctionality, {
  tags: null,
  buttonRows: null,

  emptyTags: Ember.computed.empty('tags'),
  categoryId: Ember.computed.alias('model.category.id'),

  onShow() {
    this.set('modal.modalClass', 'topic-bulk-actions-modal small');

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
    this.send('changeBulkTemplate', 'modal/bulk-actions-buttons');
  },

  perform(operation) {
    this.set('loading', true);

    const topics = this.get('model.topics');
    return Discourse.Topic.bulkOperation(topics, operation).then(result => {
      this.set('loading', false);
      if (result && result.topic_ids) {
        return result.topic_ids.map(t => topics.findBy('id', t));
      }
      return result;
    }).catch(() => {
      bootbox.alert(I18n.t('generic_error'));
      this.set('loading', false);
    });
  },

  forEachPerformed(operation, cb) {
    this.perform(operation).then(topics => {
      if (topics) {
        topics.forEach(cb);
        (this.get('refreshClosure') || Ember.k)();
        this.send('closeModal');
      }
    });
  },

  performAndRefresh(operation) {
    return this.perform(operation).then(() => {
      (this.get('refreshClosure') || Ember.k)();
      this.send('closeModal');
    });
  },

  actions: {
    showTagTopics() {
      this.set('tags', '');
      this.set('action', 'changeTags');
      this.set('label', 'change_tags');
      this.set('title', 'choose_new_tags');
      this.send('changeBulkTemplate', 'bulk-tag');
    },

    changeTags() {
      this.performAndRefresh({type: 'change_tags', tags: this.get('tags')});
    },

    showAppendTagTopics() {
      this.set('tags', '');
      this.set('action', 'appendTags');
      this.set('label', 'append_tags');
      this.set('title', 'choose_append_tags');
      this.send('changeBulkTemplate', 'bulk-tag');
    },

    appendTags() {
      this.performAndRefresh({type: 'append_tags', tags: this.get('tags')});
    },

    showChangeCategory() {
      this.send('changeBulkTemplate', 'modal/bulk-change-category');
      this.set('modal.modalClass', 'topic-bulk-actions-modal full');
    },

    showNotificationLevel() {
      this.send('changeBulkTemplate', 'modal/bulk-notification-level');
    },

    deleteTopics() {
      this.performAndRefresh({type: 'delete'});
    },

    closeTopics() {
      this.forEachPerformed({type: 'close'}, t => t.set('closed', true));
    },

    archiveTopics() {
      this.forEachPerformed({type: 'archive'}, t => t.set('archived', true));
    },

    unlistTopics() {
      this.forEachPerformed({type: 'unlist'}, t => t.set('visible', false));
    },

    changeCategory() {
      const categoryId = parseInt(this.get('newCategoryId'), 10) || 0;
      const category = Discourse.Category.findById(categoryId);

      this.perform({type: 'change_category', category_id: categoryId}).then(topics => {
        topics.forEach(t => t.set('category', category));
        (this.get('refreshClosure') || Ember.k)();
        this.send('closeModal');
      });
    },

    resetRead() {
      this.performAndRefresh({ type: 'reset_read' });
    }
  }
});

export { addBulkButton };
