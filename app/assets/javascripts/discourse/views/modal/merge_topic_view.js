/**
  A modal view for handling moving of posts to an existing topic

  @class MergeTopicView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.MergeTopicView = Discourse.ModalBodyView.extend(Discourse.SelectedPostsCount, {
  templateName: 'modal/merge_topic',
  title: Em.String.i18n('topic.merge_topic.title'),

  buttonDisabled: function() {
    if (this.get('saving')) return true;
    return this.blank('selectedTopicId');
  }.property('selectedTopicId', 'saving'),

  buttonTitle: function() {
    if (this.get('saving')) return Em.String.i18n('saving');
    return Em.String.i18n('topic.merge_topic.title');
  }.property('saving'),

  movePostsToExistingTopic: function() {
    this.set('saving', true);

    var moveSelectedView = this;

    var promise = null;
    if (this.get('allPostsSelected')) {
      promise = Discourse.Topic.mergeTopic(this.get('topic.id'), this.get('selectedTopicId'));
    } else {
      var postIds = this.get('selectedPosts').map(function(p) { return p.get('id'); });
      promise = Discourse.Topic.movePosts(this.get('topic.id'), {
        destination_topic_id: this.get('selectedTopicId'),
        post_ids: postIds
      });
    }

    promise.then(function(result) {
      // Posts moved
      $('#discourse-modal').modal('hide');
      moveSelectedView.get('topicController').toggleMultiSelect();
      Em.run.next(function() { Discourse.URL.routeTo(result.url); });
    }, function() {
      // Error moving posts
      moveSelectedView.flash(Em.String.i18n('topic.merge_topic.error'));
      moveSelectedView.set('saving', false);
    });
    return false;
  }

});


