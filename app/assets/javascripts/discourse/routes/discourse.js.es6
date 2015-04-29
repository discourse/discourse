const DiscourseRoute = Ember.Route.extend({

  // Set to true to refresh a model without a transition if a query param
  // changes
  resfreshQueryWithoutTransition: false,

  refresh: function() {
    if (!this.refreshQueryWithoutTransition) { return this._super(); }

    if (!this.router.router.activeTransition) {
      const controller = this.controller,
            model = controller.get('model'),
            params = this.controller.getProperties(Object.keys(this.queryParams));

      model.set('loading', true);
      this.model(params).then(model => this.setupController(controller, model));
    }
  },

  /**
    NOT called every time we enter a route on Discourse.
    Only called the FIRST time we enter a route.
    So, when going from one topic to another, activate will only be called on the
    TopicRoute for the first topic.
  **/
  activate: function() {
    this._super();
    Em.run.scheduleOnce('afterRender', Ember.Route, this._cleanDOM);
  },

  _cleanDOM() {
    // Close mini profiler
    $('.profiler-results .profiler-result').remove();

    // Close some elements that may be open
    $('.d-dropdown').hide();
    $('header ul.icons li').removeClass('active');
    $('[data-toggle="dropdown"]').parent().removeClass('open');
    // close the lightbox
    if ($.magnificPopup && $.magnificPopup.instance) {
      $.magnificPopup.instance.close();
      $('body').removeClass('mfp-zoom-out-cur');
    }

    // Remove any link focus
    // NOTE: the '.not("body")' is here to prevent a bug in IE10 on Win7
    // cf. https://stackoverflow.com/questions/5657371/ie9-window-loses-focus-due-to-jquery-mobile
    $(document.activeElement).not("body").blur();

    Discourse.set('notifyCount',0);
    $('#discourse-modal').modal('hide');
    var hideDropDownFunction = $('html').data('hide-dropdown');
    if (hideDropDownFunction) { hideDropDownFunction(); }

    // TODO: Avoid container lookup here
    var appEvents = Discourse.__container__.lookup('app-events:main');
    appEvents.trigger('dom:clean');
  },

  _refreshTitleOnce: function() {
    this.send('_collectTitleTokens', []);
  },

  actions: {

    _collectTitleTokens: function(tokens) {
      // If there's a title token method, call it and get the token
      if (this.titleToken) {
        var t = this.titleToken();
        if (t && t.length) {
          if (t instanceof Array) {
            t.forEach(function(ti) {
              tokens.push(ti);
            });
          } else {
            tokens.push(t);
          }
        }
      }
      return true;
    },

    refreshTitle: function() {
      Ember.run.once(this, this._refreshTitleOnce);
    }
  },

  redirectIfLoginRequired: function() {
    var app = this.controllerFor('application');
    if (app.get('loginRequired')) {
      this.replaceWith('login');
    }
  },

  openTopicDraft: function(model){
    // If there's a draft, open the create topic composer
    if (model.draft) {
      var composer = this.controllerFor('composer');
      if (!composer.get('model.viewOpen')) {
        composer.open({
          action: Discourse.Composer.CREATE_TOPIC,
          draft: model.draft,
          draftKey: model.draft_key,
          draftSequence: model.draft_sequence
        });
      }
    }
  },

  isPoppedState: function(transition) {
    return (!transition._discourse_intercepted) && (!!transition.intent.url);
  }
});

export default DiscourseRoute;
