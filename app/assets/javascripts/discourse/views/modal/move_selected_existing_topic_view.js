/**
  A modal view for handling moving of posts to an existing topic

  @class MoveSelectedExistingTopicView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.MoveSelectedExistingTopicView = Discourse.ModalBodyView.extend(Discourse.SelectedPostsCount, {
  templateName: 'modal/move_selected_existing_topic',
  title: Em.String.i18n('topic.move_selected.existing_topic.title'),

  buttonDisabled: function() {
    if (this.get('saving')) return true;
    return this.blank('selectedTopicId');
  }.property('selectedTopicId', 'saving'),

  buttonTitle: function() {
    if (this.get('saving')) return Em.String.i18n('saving');
    return Em.String.i18n('topic.move_selected.title');
  }.property('saving'),

  movePostsToExistingTopic: function() {
    this.set('saving', true);

    var postIds = this.get('selectedPosts').map(function(p) { return p.get('id'); });
    var moveSelectedView = this;

    Discourse.Topic.movePosts(this.get('topic.id'), {
      destination_topic_id: this.get('selectedTopicId'),
      post_ids: postIds
    }).then(function(result) {
      // Posts moved
      $('#discourse-modal').modal('hide');
      moveSelectedView.get('topicController').toggleMultiSelect();
      Em.run.next(function() { Discourse.URL.routeTo(result.url); });
    }, function() {
      // Error moving posts
      moveSelectedView.flash(Em.String.i18n('topic.move_selected.error'));
      moveSelectedView.set('saving', false);
    });
    return false;
  }

});


