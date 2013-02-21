(function() {

  window.Discourse.Route = Em.Route.extend({
    /* Called every time we enter a route
    */

    enter: function(router, context) {
      /* Close mini profiler
      */

      var composerController, f, search, shareController;
      jQuery('.profiler-results .profiler-result').remove();
      /* Close stuff that may be open
      */

      jQuery('.d-dropdown').hide();
      jQuery('header ul.icons li').removeClass('active');
      jQuery('[data-toggle="dropdown"]').parent().removeClass('open');
      /* TODO: need to adjust these
      */

      if (false) {
        if (shareController = router.get('shareController')) {
          shareController.close();
        }
        /* Hide any searches
        */

        if (search = router.get('searchController')) {
          search.close();
        }
        /* get rid of "save as draft stuff"
        */

        composerController = Discourse.get('router.composerController');
        if (composerController) {
          composerController.closeIfCollapsed();
        }
      }
      f = jQuery('html').data('hide-dropdown');
      if (f) {
        return f();
      }
      /*return @_super(router, context)
      */

    }
  });

}).call(this);
