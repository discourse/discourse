/*global _gaq:true */

/**
  The base controller for all things Discourse

  @class ApplicationController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.ApplicationController = Discourse.Controller.extend({
  needs: ['modal'],

  showLogin: function() {
    var modalController = this.get('controllers.modal');
    if (modalController) {
      modalController.show(Discourse.LoginView.create())
    }
  },

  routeChanged: function(){
    if (window._gaq === undefined) { return; }

    if(this.afterFirstHit) {
      Em.run.schedule('afterRender', function() {
        _gaq.push(['_trackPageview']);
      });
    } else {
      this.afterFirstHit = true;
    }
  }.observes('currentPath')

});
