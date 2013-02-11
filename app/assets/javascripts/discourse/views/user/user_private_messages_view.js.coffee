window.Discourse.UserPrivateMessagesView = Ember.View.extend
  templateName: 'user/private_messages'
  elementId: 'user-private-messages'

  selectCurrent: (evt) ->
    t = $(evt.currentTarget)
    t.closest('.action-list').find('li').removeClass('active')
    t.closest('li').addClass('active')

  inbox: (evt)->
    @selectCurrent(evt)
    @set('controller.filter', 13)

  sentMessages: (evt) ->
    @selectCurrent(evt)
    @set('controller.filter', 12)

