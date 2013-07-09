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

  buttonDisabled: function() {
    if (this.get('saving')) return true;
    return this.blank('topicName');
  }.property('saving', 'topicName'),

  buttonTitle: function() {
    if (this.get('saving')) return I18n.t('saving');
    return I18n.t('topic.split_topic.action');
  }.property('saving'),

  onShow: function() {
    this.set('saving', false);
  },

  movePostsToNewTopic: function() {
    this.set('saving', true);

    var postIds = this.get('selectedPosts').map(function(p) { return p.get('id'); });
    var splitTopicController = this;

    Discourse.Topic.movePosts(this.get('id'), {
      title: this.get('topicName'),
      post_ids: postIds
    }).then(function(result) {
      // Posts moved
      splitTopicController.send('closeModal');
      splitTopicController.get('topicController').toggleMultiSelect();
      Em.run.next(function() { Discourse.URL.routeTo(result.url); });
    }, function() {
      // Error moving posts
      splitTopicController.flash(I18n.t('topic.split_topic.error'));
      splitTopicController.set('saving', false);
    });
    return false;
  }

});
