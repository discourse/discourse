Discourse.TopicAdminMenuController = Ember.ObjectController.extend

  visible: false

  show: -> @set('visible', true)
  hide: -> @set('visible', false)
