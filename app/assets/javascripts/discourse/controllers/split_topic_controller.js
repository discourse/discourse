/**
  Modal related to auto closing of topics

  @class SplitTopicController
  @extends Discourse.ObjectController
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.SplitTopicController = Discourse.ObjectController.extend(Discourse.SelectedPostsCount, Discourse.ModalFunctionality, {
  needs: ['topic'],

  topicController: Em.computed.alias('controllers.topic'),
  selectedPosts: Em.computed.alias('topicController.selectedPosts'),
  selectedReplies: Em.computed.alias('topicController.selectedReplies'),

  buttonDisabled: function() {
    if (this.get('saving')) return true;
    return this.blank('topicName');
  }.property('saving', 'topicName'),

  buttonTitle: function() {
    if (this.get('saving')) return I18n.t('saving');
    return I18n.t('topic.split_topic.action');
  }.property('saving'),

  onShow: function() {
    this.setProperties({
      'controllers.modal.modalClass': 'split-modal',
      saving: false,
      categoryId: null,
      topicName: ''
    });
  },

  actions: {
    movePostsToNewTopic: function() {
      this.set('saving', true);

      var postIds = this.get('selectedPosts').map(function(p) { return p.get('id'); }),
          replyPostIds = this.get('selectedReplies').map(function(p) { return p.get('id'); }),
          self = this,
          categoryId = this.get('categoryId'),
          saveOpts = {
            title: this.get('topicName'),
            post_ids: postIds,
            reply_post_ids: replyPostIds
          };

      if (!Ember.isNone(categoryId)) { saveOpts.category_id = categoryId; }

      Discourse.Topic.movePosts(this.get('id'), saveOpts).then(function(result) {
        // Posts moved
        self.send('closeModal');
        self.get('topicController').send('toggleMultiSelect');
        Em.run.next(function() { Discourse.URL.routeTo(result.url); });
      }, function() {
        // Error moving posts
        self.flash(I18n.t('topic.split_topic.error'));
        self.set('saving', false);
      });
      return false;
    }
  }


});
