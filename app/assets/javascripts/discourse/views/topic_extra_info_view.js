/**
  This view is used for rendering the extra information on a topic in the header

  @class TopicExtraInfoView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.TopicExtraInfoView = Ember.ContainerView.extend({
  classNameBindings: [':extra-info-wrapper', 'controller.showExtraInfo'],
  childViews: ['extraInfo'],

  extraInfo: Em.View.createWithMixins({
    templateName: 'topic_extra_info',
    classNames: ['extra-info'],
    topicBinding: 'controller.topic',
    showFavoriteButton: function() {
      return Discourse.User.current() && !this.get('topic.isPrivateMessage');
    }.property('topic.isPrivateMessage')
  })

});


