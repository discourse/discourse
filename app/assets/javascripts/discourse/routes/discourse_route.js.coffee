window.Discourse.Route = Em.Route.extend

  # Called every time we enter a route
  enter: (router, context) ->
    # Close mini profiler
    $('.profiler-results .profiler-result').remove()

    # Close stuff that may be open
    $('.d-dropdown').hide()
    $('header ul.icons li').removeClass('active')
    $('[data-toggle="dropdown"]').parent().removeClass('open')

    # TODO: need to adjust these
    if false
      if shareController = router.get('shareController')
        shareController.close()

      # Hide any searches
      if search = router.get('searchController')
        search.close()

      # get rid of "save as draft stuff"
      composerController = Discourse.get('router.composerController')
      composerController.closeIfCollapsed() if composerController

    f = $('html').data('hide-dropdown')
    f() if f

    #return @_super(router, context)
