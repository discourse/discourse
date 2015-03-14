import showModal from 'discourse/lib/show-modal';

function unlessReadOnly(method) {
  return function() {
    if (this.site.get("isReadOnly")) {
      bootbox.alert(I18n.t("read_only_mode.login_disabled"));
    } else {
      this[method]();
    }
  };
}

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

    showLogin: unlessReadOnly('handleShowLogin'),

    showCreateAccount: unlessReadOnly('handleShowCreateAccount'),

    showForgotPassword() {
      showModal('forgotPassword');
    },

    showNotActivated(props) {
      showModal('notActivated');
      this.controllerFor('notActivated').setProperties(props);
    },

    showUploadSelector(composerView) {
      showModal('uploadSelector');
      this.controllerFor('upload-selector').setProperties({ composerView: composerView });
    },

    showKeyboardShortcutsHelp() {
      showModal('keyboardShortcutsHelp');
    },

    showSearchHelp() {
      // TODO: @EvitTrout how do we get a loading indicator here?
      Discourse.ajax("/static/search_help.html", { dataType: 'html' }).then(function(html){
        showModal('searchHelp', html);
      });
    },

    // Close the current modal, and destroy its state.
    closeModal() {
      this.render('hide-modal', { into: 'modal', outlet: 'modalBody' });
    },

    /**
      Hide the modal, but keep it with all its state so that it can be shown again later.
      This is useful if you want to prompt for confirmation. hideModal, ask "Are you sure?",
      user clicks "No", reopenModal. If user clicks "Yes", be sure to call closeModal.
    **/
    hideModal() {
      $('#discourse-modal').modal('hide');
    },

    reopenModal() {
      $('#discourse-modal').modal('show');
    },

    editCategory(category) {
      const self = this;
      Discourse.Category.reloadById(category.get('id')).then(function (c) {
        self.site.updateCategory(c);
        showModal('editCategory', c);
        self.controllerFor('editCategory').set('selectedTab', 'general');
      });
    },

    deleteSpammer: function (user) {
      this.send('closeModal');
      user.deleteAsSpammer(function() { window.location.reload(); });
    },

    checkEmail: function (user) {
      user.checkEmail();
    },

    changeBulkTemplate(w) {
      const controllerName = w.replace('modal/', ''),
            factory = this.container.lookupFactory('controller:' + controllerName);

      this.render(w, {into: 'topicBulkActions', outlet: 'bulkOutlet', controller: factory ? controllerName : 'topic-bulk-actions'});
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
    if (this.siteSettings.enable_sso) {
      const returnPath = encodeURIComponent(window.location.pathname);
      window.location = Discourse.getURL('/session/sso?return_path=' + returnPath);
    } else {
      this._autoLogin('login', () => this.controllerFor('login').resetForm());
    }
  },

  handleShowCreateAccount() {
    this._autoLogin('createAccount');
  },

  _autoLogin(modal, notAuto) {
    const methods = Em.get('Discourse.LoginMethod.all');
    if (!this.siteSettings.enable_local_logins && methods.length === 1) {
      this.controllerFor('login').send('externalLogin', methods[0]);
    } else {
      showModal(modal);
      if (notAuto) { notAuto(); }
    }
  },

});

RSVP.EventTarget.mixin(ApplicationRoute);
export default ApplicationRoute;
