(function() {

  /**
    The base admin route for all routes on Discourse. Includes global enter functionality.

    @class Route    
    @extends Em.Route
    @namespace Discourse
    @module Discourse
  **/
  Discourse.Route = Em.Route.extend({

    /** 
      Called every time we enter a route on Discourse.

      @method enter
    **/
    enter: function(router, context) {
      // Close mini profiler
      jQuery('.profiler-results .profiler-result').remove();

      // Close some elements that may be open
      jQuery('.d-dropdown').hide();
      jQuery('header ul.icons li').removeClass('active');
      jQuery('[data-toggle="dropdown"]').parent().removeClass('open');

      var hideDropDownFunction = jQuery('html').data('hide-dropdown');
      if (hideDropDownFunction) return hideDropDownFunction();
    }
  });

}).call(this);
