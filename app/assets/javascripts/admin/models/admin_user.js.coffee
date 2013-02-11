window.Discourse.AdminUser = Discourse.Model.extend

  deleteAllPosts: ->
    @set('can_delete_all_posts', false)
    $.ajax "/admin/users/#{@get('id')}/delete_all_posts", type: 'PUT'

  # Revoke the user's admin access
  revokeAdmin: ->
    @set('admin',false)
    @set('can_grant_admin',true)
    @set('can_revoke_admin',false)
    $.ajax "/admin/users/#{@get('id')}/revoke_admin", type: 'PUT'

  grantAdmin: ->
    @set('admin',true)
    @set('can_grant_admin',false)
    @set('can_revoke_admin',true)
    $.ajax "/admin/users/#{@get('id')}/grant_admin", type: 'PUT'

  refreshBrowsers: ->
    $.ajax "/admin/users/#{@get('id')}/refresh_browsers",
      type: 'POST'
    bootbox.alert("Message sent to all clients!")

  approve: ->
    @set('can_approve', false)
    @set('approved', true)
    @set('approved_by', Discourse.get('currentUser'))
    $.ajax "/admin/users/#{@get('id')}/approve", type: 'PUT'

  username_lower:(->
    @get('username').toLowerCase()
  ).property('username')

  trustLevel: (->
    Discourse.get('site.trust_levels').findProperty('id', @get('trust_level'))
  ).property('trust_level')


  canBan: ( ->
    !@admin && !@moderator
  ).property('admin','moderator')

  banDuration: (->
    banned_at = Date.create(@banned_at)
    banned_till = Date.create(@banned_till)

    "#{banned_at.short()} - #{banned_till.short()}"

  ).property('banned_till', 'banned_at')

  ban: ->
    debugger
    if duration = parseInt(window.prompt(Em.String.i18n('admin.user.ban_duration')))
      if duration > 0
        $.ajax "/admin/users/#{@id}/ban",
          type: 'PUT'
          data:
            duration: duration
          success: ->
            window.location.reload()
            return
          error: (e) =>
            error = Em.String.i18n('admin.user.ban_failed', error: "http: #{e.status} - #{e.body}")
            bootbox.alert error
            return

  unban: ->
    $.ajax "/admin/users/#{@id}/unban",
      type: 'PUT'
      success: ->
        window.location.reload()
        return
      error: (e) =>
        error = Em.String.i18n('admin.user.unban_failed', error: "http: #{e.status} - #{e.body}")
        bootbox.alert error
        return

  impersonate: ->
    $.ajax "/admin/impersonate"
      type: 'POST'
      data:
        username_or_email: @get('username')
      success: ->
        document.location = "/"
      error: (e) =>
        @set('loading', false)
        if e.status == 404
          bootbox.alert Em.String.i18n('admin.impersonate.not_found')
        else
          bootbox.alert Em.String.i18n('admin.impersonate.invalid')

window.Discourse.AdminUser.reopenClass

  create: (result) ->
    result = @_super(result)
    result

  bulkApprove: (users) ->
    users.each (user) ->
      user.set('approved', true)
      user.set('can_approve', false)
      user.set('selected', false)

    $.ajax "/admin/users/approve-bulk",
      type: 'PUT'
      data: {users: users.map (u) -> u.id}

  find: (username)->
    promise = new RSVP.Promise()
    $.ajax
      url: "/admin/users/#{username}"
      success: (result) -> promise.resolve(Discourse.AdminUser.create(result))
    promise

  findAll: (query, filter)->
    result = Em.A()
    $.ajax
      url: "/admin/users/list/#{query}.json"
      data: {filter: filter}
      success: (users) ->
        users.each (u) -> result.pushObject(Discourse.AdminUser.create(u))
    result

