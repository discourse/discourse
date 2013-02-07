window.Discourse.UserActivityView = Ember.View.extend
  templateName: 'user/activity'
  currentUserBinding: 'Discourse.currentUser'
  userBinding: 'controller.content'


  didInsertElement: ->
    window.scrollTo(0, 0)
