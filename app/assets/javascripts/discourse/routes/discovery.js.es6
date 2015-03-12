/**
  The parent route for all discovery routes.
  Handles the logic for showing the loading spinners.
**/

import ShowFooter from "discourse/mixins/show-footer";

const DiscoveryRoute = Discourse.Route.extend(Discourse.ScrollTop, Discourse.OpenComposer, ShowFooter, {
  redirect: function() { return this.redirectIfLoginRequired(); },

  beforeModel: function(transition) {
    if (transition.targetName.indexOf("discovery.top") === -1 &&
        Discourse.User.currentProp("should_be_redirected_to_top")) {
      Discourse.User.currentProp("should_be_redirected_to_top", false);
      this.replaceWith("discovery.top");
    }
  },

  actions: {
    loading: function() {
      this.controllerFor('discovery').set("loading", true);
      return true;
    },

    loadingComplete: function() {
      this.controllerFor('discovery').set('loading', false);
      if (!this.session.get('topicListScrollPosition')) {
        this._scrollTop();
      }
    },

    didTransition: function() {
      this.controllerFor("discovery")._showFooter();
      this.send('loadingComplete');
      return true;
    },

    // clear a pinned topic
    clearPin: function(topic) {
      topic.clearPin();
    },

    createTopic: function() {
      this.openComposer(this.controllerFor('discovery/topics'));
    }
  }

});

export default DiscoveryRoute;
