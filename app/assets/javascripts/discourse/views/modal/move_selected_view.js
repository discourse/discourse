/**
  A modal view for handling moving of posts.

  @class MoveSelectedView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.MoveSelectedView = Discourse.ModalBodyView.extend(Discourse.SelectedPostsCount, {
  templateName: 'modal/move_selected',
  title: Em.String.i18n('topic.move_selected.title'),

  showMoveNewTopic: function() {
    var modalController = this.get('controller');
    if (!modalController) return;

    modalController.show(Discourse.MoveSelectedNewTopicView.create({
      topicController: this.get('topicController'),
      topic: this.get('topic'),
      selectedPosts: this.get('selectedPosts')
    }));
  },

  showMoveExistingTopic: function() {
    var modalController = this.get('controller');
    if (!modalController) return;

    modalController.show(Discourse.MoveSelectedExistingTopicView.create({
      topicController: this.get('topicController'),
      topic: this.get('topic'),
      selectedPosts: this.get('selectedPosts')
    }));
  }

});


