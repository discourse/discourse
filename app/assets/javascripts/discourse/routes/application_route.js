/**
  Application route for Discourse

  @class ApplicationRoute
  @extends Ember.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.ApplicationRoute = Em.Route.extend({

  events: {
    showLogin: function() {
      Discourse.Route.showModal(this, 'login');
    },

    showCreateAccount: function() {
      Discourse.Route.showModal(this, 'createAccount');
    },

    showForgotPassword: function() {
      Discourse.Route.showModal(this, 'forgotPassword');
    },

    showNotActivated: function(props) {
      Discourse.Route.showModal(this, 'notActivated');
      this.controllerFor('notActivated').setProperties(props);
    },

    showImageSelector: function(composerView) {
      Discourse.Route.showModal(this, 'imageSelector');
      this.controllerFor('imageSelector').setProperties({
        localSelected: true,
        composerView: composerView
      });
    },

    editCategory: function(category) {
      var router = this;
      Discourse.Category.findBySlugOrId(category.get('slug')).then(function (c) {
        Discourse.Route.showModal(router, 'editCategory', c);
        router.controllerFor('editCategory').set('selectedTab', 'general');
      })
    }

  }

});