import ShowFooter from "discourse/mixins/show-footer";

var configs = {
  'faq': 'faq_url',
  'tos': 'tos_url',
  'privacy': 'privacy_policy_url'
};

export default function(page) {
  return Discourse.Route.extend(ShowFooter, {
    renderTemplate: function() {
      this.render('static');
    },

    beforeModel: function(transition) {
      var configKey = configs[page];
      if (configKey && Discourse.SiteSettings[configKey].length > 0) {
        transition.abort();
        Discourse.URL.redirectTo(Discourse.SiteSettings[configKey]);
      }
    },

    activate: function() {
      this._super();

      // Scroll to an element if exists
      Discourse.URL.scrollToId(document.location.hash);
    },

    model: function() {
      return Discourse.StaticPage.find(page);
    },

    setupController: function(controller, model) {
      this.controllerFor('static').set('model', model);
    }
  });
}

