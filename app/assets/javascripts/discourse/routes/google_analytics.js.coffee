Ember.Route.reopen
  setup: (router,context) ->
    @_super(router,context)
    if window._gaq
      if @get("isLeafRoute")
        # first hit is tracked inline
        if router.afterFirstHit
          path = @absoluteRoute(router)
          _gaq.push(['_trackPageview', path])
        else
          router.afterFirstHit = true
        null
