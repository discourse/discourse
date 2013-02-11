window.Discourse.FlagView = Discourse.ModalBodyView.extend
  templateName: 'flag'
  title: Em.String.i18n('flagging.title')

  changePostActionType: (action) ->
    if @get('postActionTypeId') == action.id
      return false
    @set('postActionTypeId', action.id)
    @set('isCustomFlag', action.is_custom_flag)
    Em.run.next -> $("#radio_#{action.name_key}").prop('checked', 'true')
    false

  createFlag: ->
    actionType = Discourse.get("site").postActionTypeById(@get('postActionTypeId'))
    @get("post.actionByName.#{actionType.get('name_key')}")?.act(message: @get('customFlagMessage')).then ->
      $('#discourse-modal').modal('hide')
    , (errors) => @displayErrors(errors)
    false

  customPlaceholder: (->
    Em.String.i18n("flagging.custom_placeholder")
  ).property()

  showSubmit: (->
    if @get("postActionTypeId")
      if @get("isCustomFlag")
        m = @get("customFlagMessage")
        return m && m.length >= 10 && m.length <= 500
      else
        return true
    false
  ).property("isCustomFlag","customFlagMessage", "postActionTypeId")

  customFlagMessageChanged: (->
    minLen = 10
    len = @get('customFlagMessage')?.length || 0
    @set("customMessageLengthClasses", "too-short custom-message-length")
    if len == 0
      message = Em.String.i18n("flagging.custom_message.at_least", n: minLen)
    else if len < minLen
      message = Em.String.i18n("flagging.custom_message.more", n: minLen - len)
    else
      message = Em.String.i18n("flagging.custom_message.left", n: 500 - len)
      @set("customMessageLengthClasses", "ok custom-message-length")
    @set("customMessageLength",message)
    return
  ).observes("customFlagMessage")

  didInsertElement: ->
    @customFlagMessageChanged()
    @set('postActionTypeId', null)
    $flagModal = $('#flag-modal')

    # Would be nice if there were an EmberJs radio button to do this for us. Oh well, one should be coming
    # in an upcoming release.
    $("input[type='radio']", $flagModal).prop('checked', false)
    return
