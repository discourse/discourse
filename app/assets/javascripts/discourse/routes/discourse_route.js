/**
  The base route for all routes on Discourse. Includes global enter functionality.

  @class Route
  @extends Em.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.Route = Em.Route.extend({

  /**
    Called every time we enter a route on Discourse.

    @method activate
  **/
  activate: function(router, context) {
    this._super();

    // Close mini profiler
    $('.profiler-results .profiler-result').remove();

    // Close some elements that may be open
    $('.d-dropdown').hide();
    $('header ul.icons li').removeClass('active');
    $('[data-toggle="dropdown"]').parent().removeClass('open');

    Discourse.set('notifyCount',0);

    var hideDropDownFunction = $('html').data('hide-dropdown');
    if (hideDropDownFunction) return hideDropDownFunction();
  }

});


Discourse.Route.reopenClass({

  buildRoutes: function(builder) {
    var oldBuilder = Discourse.routeBuilder;
    Discourse.routeBuilder = function() {
      if (oldBuilder) oldBuilder.call(this);
      return builder.call(this);
    };
  },

  /**
    Shows a modal

    @method showModal
  **/
  showModal: function(router, name, model) {
    router.controllerFor('modal').set('modalClass', null);
    router.render(name, {into: 'modal', outlet: 'modalBody'});
    var controller = router.controllerFor(name);
    if (controller) {
      if (model) {
        controller.set('model', model);
      }
      controller.set('flashMessage', null);
    }
  }

});
