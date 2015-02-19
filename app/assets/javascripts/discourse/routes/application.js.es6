const ApplicationRoute = Discourse.Route.extend({

  siteTitle: Discourse.computed.setting('title'),

  actions: {
    _collectTitleTokens(tokens) {
      tokens.push(this.get('siteTitle'));
      Discourse.set('_docTitle', tokens.join(' - '));
    },

    // Ember doesn't provider a router `willTransition` event so let's make one
    willTransition() {
      var router = this.container.lookup('router:main');
      Ember.run.once(router, router.trigger, 'willTransition');
      return this._super();
    },

    // This is here as a bugfix for when an Ember Cloaked view triggers
    // a scroll after a controller has been torn down. The real fix
    // should be to fix ember cloaking to not do that, but this catches
    // it safely just in case.
    postChangedRoute: Ember.K,

    showTopicEntrance(data) {
      this.controllerFor('topic-entrance').send('show', data);
    },

    composePrivateMessage(user, post) {
      const self = this;
      this.transitionTo('userActivity', user).then(function () {
        self.controllerFor('user-activity').send('composePrivateMessage', user, post);
      });
    },

    error(err, transition) {
      if (err.status === 404) {
        // 404
        this.intermediateTransitionTo('unknown');
        return;
      }

      const exceptionController = this.controllerFor('exception'),
            stack = err.stack;

      // If we have a stack call `toString` on it. It gives us a better
      // stack trace since `console.error` uses the stack track of this
      // error callback rather than the original error.
      let errorString = err.toString();
      if (stack) { errorString = stack.toString(); }

      if (err.statusText) { errorString = err.statusText; }

      const c = window.console;
      if (c && c.error) {
        c.error(errorString);
      }
      exceptionController.setProperties({ lastTransition: transition, thrown: err });

      this.intermediateTransitionTo('exception');
    },

    showLogin() {
      if (this.site.get("isReadOnly")) {
        bootbox.alert(I18n.t("read_only_mode.login_disabled"));
      } else {
        this.handleShowLogin();
      }
    },

    showCreateAccount() {
      if (this.site.get("isReadOnly")) {
        bootbox.alert(I18n.t("read_only_mode.login_disabled"));
      } else {
        this.handleShowCreateAccount();
      }
    },

    autoLogin(modal, onFail){
      const methods = Em.get('Discourse.LoginMethod.all');
      if (!Discourse.SiteSettings.enable_local_logins &&
          methods.length === 1) {
            Discourse.Route.showModal(this, modal);
            this.controllerFor('login').send('externalLogin', methods[0]);
      } else {
        onFail();
      }
    },

    showForgotPassword() {
      Discourse.Route.showModal(this, 'forgotPassword');
    },

    showNotActivated(props) {
      Discourse.Route.showModal(this, 'notActivated');
      this.controllerFor('notActivated').setProperties(props);
    },

    showUploadSelector(composerView) {
      Discourse.Route.showModal(this, 'uploadSelector');
      this.controllerFor('upload-selector').setProperties({ composerView: composerView });
    },

    showKeyboardShortcutsHelp() {
      Discourse.Route.showModal(this, 'keyboardShortcutsHelp');
    },

    showSearchHelp() {
      const self = this;

      // TODO: @EvitTrout how do we get a loading indicator here?
      Discourse.ajax("/static/search_help.html", { dataType: 'html' }).then(function(html){
        Discourse.Route.showModal(self, 'searchHelp', html);
      });

    },


    /**
      Close the current modal, and destroy its state.

      @method closeModal
    **/
    closeModal() {
      this.render('hide-modal', {into: 'modal', outlet: 'modalBody'});
    },

    /**
      Hide the modal, but keep it with all its state so that it can be shown again later.
      This is useful if you want to prompt for confirmation. hideModal, ask "Are you sure?",
      user clicks "No", showModal. If user clicks "Yes", be sure to call closeModal.

      @method hideModal
    **/
    hideModal() {
      $('#discourse-modal').modal('hide');
    },

    /**
      Show the modal. Useful after calling hideModal.

      @method showModal
    **/
    showModal() {
      $('#discourse-modal').modal('show');
    },

    editCategory(category) {
      const self = this;
      Discourse.Category.reloadById(category.get('id')).then(function (c) {
        self.site.updateCategory(c);
        Discourse.Route.showModal(self, 'editCategory', c);
        self.controllerFor('editCategory').set('selectedTab', 'general');
      });
    },

    /**
      Deletes a user and all posts and topics created by that user.

      @method deleteSpammer
    **/
    deleteSpammer: function (user) {
      this.send('closeModal');
      user.deleteAsSpammer(function() { window.location.reload(); });
    },

    checkEmail: function (user) {
      user.checkEmail();
    }
  },

  activate() {
    this._super();
    Em.run.next(function() {
      // Support for callbacks once the application has activated
      ApplicationRoute.trigger('activate');
    });
  },

  handleShowLogin() {
    const self = this;

    if(Discourse.SiteSettings.enable_sso) {
      const returnPath = encodeURIComponent(window.location.pathname);
      window.location = Discourse.getURL('/session/sso?return_path=' + returnPath);
    } else {
      this.send('autoLogin', 'login', function(){
        Discourse.Route.showModal(self, 'login');
        self.controllerFor('login').resetForm();
      });
    }
  },

  handleShowCreateAccount() {
    const self = this;

    self.send('autoLogin', 'createAccount', function(){
      Discourse.Route.showModal(self, 'createAccount');
    });
  }
});

RSVP.EventTarget.mixin(ApplicationRoute);
export default ApplicationRoute;
