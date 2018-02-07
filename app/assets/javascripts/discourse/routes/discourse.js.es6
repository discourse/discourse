import Composer from 'discourse/models/composer';

const DiscourseRoute = Ember.Route.extend({
  showFooter: false,

  // Set to true to refresh a model without a transition if a query param
  // changes
  resfreshQueryWithoutTransition: false,

  activate() {
    this._super();
    if (this.get('showFooter')) {
      this.controllerFor('application').set('showFooter', true);
    }
  },

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
          action: Composer.CREATE_TOPIC,
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

export default DiscourseRoute;
