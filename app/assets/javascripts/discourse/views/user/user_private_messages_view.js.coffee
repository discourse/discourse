window.Discourse.UserPrivateMessagesView = Ember.View.extend
  templateName: 'user/private_messages'

  selectCurrent: (evt) ->
    t = $(evt.currentTarget)
    t.closest('.action-list').find('li').removeClass('active')
    t.closest('li').addClass('active')

  inbox: (evt)->
    @selectCurrent(evt)
    @set('controller.filter', Discourse.UserAction.GOT_PRIVATE_MESSAGE)

  sentMessages: (evt) ->
    @selectCurrent(evt)
    @set('controller.filter', Discourse.UserAction.NEW_PRIVATE_MESSAGE)

