/**
  A modal view for handling moving of posts to a new topic

  @class SplitTopicView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.SplitTopicView = Discourse.ModalBodyView.extend(Discourse.SelectedPostsCount, {
  templateName: 'modal/split_topic',
  title: Em.String.i18n('topic.split_topic.title'),
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

    Discourse.Topic.movePosts(this.get('topic.id'), {
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


