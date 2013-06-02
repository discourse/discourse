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
  saving: false,

  buttonDisabled: function() {
    if (this.get('saving')) return true;
    return this.blank('topicName');
  }.property('saving', 'topicName'),

  buttonTitle: function() {
    if (this.get('saving')) return Em.String.i18n('saving');
    return Em.String.i18n('topic.split_topic.action');
  }.property('saving'),

  movePostsToNewTopic: function() {
    this.set('saving', true);

    var postIds = this.get('selectedPosts').map(function(p) { return p.get('id'); });
    var moveSelectedView = this;

    Discourse.Topic.movePosts(this.get('id'), {
      title: this.get('topicName'),
      post_ids: postIds
    }).then(function(result) {
      // Posts moved
      $('#discourse-modal').modal('hide');
      moveSelectedView.get('topicController').toggleMultiSelect();
      Em.run.next(function() { Discourse.URL.routeTo(result.url); });
    }, function() {
      // Error moving posts
      moveSelectedView.flash(Em.String.i18n('topic.split_topic.error'));
      moveSelectedView.set('saving', false);
    });
    return false;
  }

});