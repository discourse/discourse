window.Discourse.SelectedPostsView = Ember.View.extend
  elementId: 'selected-posts'
  templateName: 'selected_posts'
  topicBinding: 'controller.content'
  classNameBindings: ['customVisibility']

  customVisibility: (->
    return 'hidden' unless @get('controller.multiSelect')
  ).property('controller.multiSelect')
