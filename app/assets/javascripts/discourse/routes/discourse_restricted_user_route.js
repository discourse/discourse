/**
  A base route that allows us to redirect when access is restricted

  @class RestrictedUserRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.RestrictedUserRoute = Discourse.Route.extend({

  enter: function(router, context) {
    var _this = this;

    // a bit hacky, but we don't have a fully loaded user at this point
    //  so we need to wait for it
    var user = this.controllerFor('user').get('content');
    
    if(user.can_edit === undefined) {
      user.onDetailsLoaded(function(){
        if (this.get('can_edit') === false) {
          _this.transitionTo('user.activity');
        }
      });
    }
    
    if(user.can_edit === false) {
      this.transitionTo('user.activity');
    }
  }

});


