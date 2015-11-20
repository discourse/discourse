const DiscourseRoute = Ember.Route.extend({

  // Set to true to refresh a model without a transition if a query param
  // changes
  resfreshQueryWithoutTransition: false,

  refresh() {
    if (!this.refreshQueryWithoutTransition) { return this._super(); }

    if (!this.router.router.activeTransition) {
      const controller = this.controller,
            model = controller.get('model'),
            params = this.controller.getProperties(Object.keys(this.queryParams));

      model.set('loading', true);
      this.model(params).then(m => this.setupController(controller, m));
    }
  },

  _refreshTitleOnce() {
    this.send('_collectTitleTokens', []);
  },

  actions: {

    _collectTitleTokens(tokens) {
      // If there's a title token method, call it and get the token
      if (this.titleToken) {
        const t = this.titleToken();
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

    refreshTitle() {
      Ember.run.once(this, this._refreshTitleOnce);
    }
  },

  redirectIfLoginRequired() {
    const app = this.controllerFor('application');
    if (app.get('loginRequired')) {
      this.replaceWith('login');
    }
  },

  openTopicDraft(model){
    // If there's a draft, open the create topic composer
    if (model.draft) {
      const composer = this.controllerFor('composer');
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

  isPoppedState(transition) {
    return (!transition._discourse_intercepted) && (!!transition.intent.url);
  }
});

export function cleanDOM() {
  // Close mini profiler
  $('.profiler-results .profiler-result').remove();

  // Close some elements that may be open
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
  $(document.activeElement).not("body").not(".no-blur").blur();

  Discourse.set('notifyCount',0);
  $('#discourse-modal').modal('hide');
  const hideDropDownFunction = $('html').data('hide-dropdown');
  if (hideDropDownFunction) { hideDropDownFunction(); }

  // TODO: Avoid container lookup here
  const appEvents = Discourse.__container__.lookup('app-events:main');
  appEvents.trigger('dom:clean');
}

export default DiscourseRoute;
