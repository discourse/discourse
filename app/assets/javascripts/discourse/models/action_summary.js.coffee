window.Discourse.ActionSummary = Em.Object.extend Discourse.Presence,

  # Description for the action
  description: (->
    if @get('acted')
      Em.String.i18n('post.actions.by_you_and_others', count: @get('count') - 1, long_form: @get('actionType.long_form'))
    else
      Em.String.i18n('post.actions.by_others', count: @get('count'), long_form: @get('actionType.long_form'))
  ).property('count', 'acted', 'actionType')

  canAlsoAction: (->
    return false if @get('hidden')
    return @get('can_act')
  ).property('can_act', 'hidden')

  # Remove it
  removeAction: ->
    @set('acted', false)
    @set('count', @get('count') - 1)
    @set('can_act', true)
    @set('can_undo', false)  

  # Perform this action
  act: (opts) ->
    # Mark it as acted
    @set('acted', true)
    @set('count', @get('count') + 1)
    @set('can_act', false)
    @set('can_undo', true)

    #TODO: mark all other flag types as acted
    
    # Add ourselves to the users who liked it if present
    @users.pushObject(Discourse.get('currentUser')) if @present('users')

    # Create our post action
    jQuery.ajax
      url: "/post_actions",
      type: 'POST'
      data:
        id: @get('post.id')
        post_action_type_id: @get('id')
        message: opts?.message || ""
      error: (error) =>
        @removeAction()
        errors = jQuery.parseJSON(error.responseText).errors
        bootbox.alert(errors[0])
        

  # Undo this action
  undo: ->
    @removeAction()

    # Remove our post action
    jQuery.ajax 
      url: "/post_actions/#{@get('post.id')}"
      type: 'DELETE'
      data:
        post_action_type_id: @get('id')    

  loadUsers: ->
    $.getJSON "/post_actions/users",
      id: @get('post.id'),
      post_action_type_id: @get('id')
      (result) => 
        @set('users', Em.A())
        result.each (u) => @get('users').pushObject(Discourse.User.create(u))
