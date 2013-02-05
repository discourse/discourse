window.Discourse.AdminEmailLogsController = Ember.ArrayController.extend Discourse.Presence,

  sendTestEmailDisabled: (->
    @blank('testEmailAddress')
  ).property('testEmailAddress')

  sendTestEmail: ->
    @set('sentTestEmail', false)
    $.ajax 
      url: '/admin/email_logs/test',
      type: 'POST'
      data:
        email_address: @get('testEmailAddress')
      success: =>
        @set('sentTestEmail', true)
    false
  