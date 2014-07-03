/**
  Application route for Discourse

  @class ApplicationRoute
  @extends Ember.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.ApplicationRoute = Em.Route.extend({

  actions: {

    error: function(err, transition) {
      if (err.status === 404) {
        // 404
        this.intermediateTransitionTo('unknown');
        return;
      }

      var exceptionController = this.controllerFor('exception');
      exceptionController.setProperties({ lastTransition: transition, thrown: err });

      this.intermediateTransitionTo('exception');
    },

    showLogin: function() {
      if (Discourse.get("isReadOnly")) {
        bootbox.alert(I18n.t("read_only_mode.login_disabled"));
      } else {
        if(Discourse.SiteSettings.enable_sso) {
          var returnPath = encodeURIComponent(window.location.pathname);
          window.location = Discourse.getURL('/session/sso?return_path=' + returnPath);
        } else {
          Discourse.Route.showModal(this, 'login');
          this.controllerFor('login').resetForm();
        }
      }
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
      this.controllerFor('upload-selector').setProperties({ composerView: composerView });
    },

    showKeyboardShortcutsHelp: function() {
      Discourse.Route.showModal(this, 'keyboardShortcutsHelp');
    },


    /**
      Close the current modal, and destroy its state.

      @method closeModal
    **/
    closeModal: function() {
      this.render('hide-modal', {into: 'modal', outlet: 'modalBody'});
    },

    /**
      Hide the modal, but keep it with all its state so that it can be shown again later.
      This is useful if you want to prompt for confirmation. hideModal, ask "Are you sure?",
      user clicks "No", showModal. If user clicks "Yes", be sure to call closeModal.

      @method hideModal
    **/
    hideModal: function() {
      $('#discourse-modal').modal('hide');
    },

    /**
      Show the modal. Useful after calling hideModal.

      @method showModal
    **/
    showModal: function() {
      $('#discourse-modal').modal('show');
    },

    editCategory: function(category) {
      var router = this;

      if (category.get('isUncategorizedCategory')) {
        Discourse.Route.showModal(router, 'editCategory', category);
        router.controllerFor('editCategory').set('selectedTab', 'general');
      } else {
        Discourse.Category.reloadBySlugOrId(category.get('slug') || category.get('id')).then(function (c) {
          Discourse.Site.current().updateCategory(c);
          Discourse.Route.showModal(router, 'editCategory', c);
          router.controllerFor('editCategory').set('selectedTab', 'general');
        });
      }

    }
  },

  activate: function() {
    this._super();
    Em.run.next(function() {
      // Support for callbacks once the application has activated
      Discourse.ApplicationRoute.trigger('activate');
    });
  }

});

RSVP.EventTarget.mixin(Discourse.ApplicationRoute);
