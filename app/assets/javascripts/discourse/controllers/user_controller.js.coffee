Discourse.UserController = Ember.ObjectController.extend

  viewingSelf: (->
    @get('content.username') == Discourse.get('currentUser.username')
  ).property('content.username', 'Discourse.currentUser.username')

  canSeePrivateMessages: (->
    @get('viewingSelf') || Discourse.get('currentUser.admin')
  ).property('viewingSelf', 'Discourse.currentUser')
