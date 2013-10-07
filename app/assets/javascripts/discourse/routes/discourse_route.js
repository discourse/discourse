/**
  The base route for all routes on Discourse. Includes global enter functionality.

  @class Route
  @extends Em.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.Route = Em.Route.extend({

  /**
    NOT called every time we enter a route on Discourse.
    Only called the FIRST time we enter a route.
    So, when going from one topic to another, activate will only be called on the
    TopicRoute for the first topic.

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
    // close the lightbox
    if ($.magnificPopup && $.magnificPopup.instance) { $.magnificPopup.instance.close(); }

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
      if(controller && controller.onShow) {
        controller.onShow();
      }
      controller.set('flashMessage', null);
    }
  }

});
