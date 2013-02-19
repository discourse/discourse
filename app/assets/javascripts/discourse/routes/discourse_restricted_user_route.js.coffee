window.Discourse.RestrictedUserRoute = Discourse.Route.extend

  enter: (router, context) ->
    user = @controllerFor('user').get('content')
    
    @allowed = user.can_edit
    
  redirect: ->
    @transitionTo('user.activity') unless @allowed
    