Discourse.TopicExtraInfoView = Ember.ContainerView.extend
  classNameBindings: [':extra-info-wrapper', 'controller.showExtraInfo']
  childViews: ['extraInfo']

  extraInfo: Em.View.createWithMixins
    templateName: 'topic_extra_info'
    classNames: ['extra-info']
    topicBinding: 'controller.topic'

    showFavoriteButton: (->
      Discourse.currentUser && !@get('topic.isPrivateMessage')
    ).property('topic.isPrivateMessage')
