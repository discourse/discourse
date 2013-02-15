window.Discourse.UserView = Ember.View.extend
  templateName: 'user/user'
  userBinding: 'controller.content'

  updateTitle: (->
    username = @get('user.username')
    Discourse.set('title', "#{Em.String.i18n("user.profile")} - #{username}") if username
  ).observes('user.loaded', 'user.username')