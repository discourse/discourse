/**
  Application route for Discourse

  @class ApplicationRoute
  @extends Ember.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.ApplicationRoute = Em.Route.extend({

  actions: {
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

    showUploadSelector: function(composerView) {
      Discourse.Route.showModal(this, 'uploadSelector');
      this.controllerFor('uploadSelector').setProperties({ composerView: composerView });
    },


    /**
      Close the current modal.

      @method closeModal
    **/
    closeModal: function() {
      this.render('hide_modal', {into: 'modal', outlet: 'modalBody'});
    },

    editCategory: function(category) {
      var router = this;

      if (category.get('isUncategorized')) {
        Discourse.Route.showModal(router, 'editCategory', category);
        router.controllerFor('editCategory').set('selectedTab', 'general');
      } else {
        Discourse.Category.findBySlugOrId(category.get('slug') || category.get('id')).then(function (c) {
          Discourse.Site.current().updateCategory(c);
          Discourse.Route.showModal(router, 'editCategory', c);
          router.controllerFor('editCategory').set('selectedTab', 'general');
        });
      }

    }

  }

});
