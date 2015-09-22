/**
  The parent route for all discovery routes.
  Handles the logic for showing the loading spinners.
**/
import OpenComposer from "discourse/mixins/open-composer";
import { scrollTop } from "discourse/mixins/scroll-top";

const DiscoveryRoute = Discourse.Route.extend(OpenComposer, {
  redirect() {
    return this.redirectIfLoginRequired();
  },

  beforeModel(transition) {
    if (transition.intent.url === "/" &&
        transition.targetName.indexOf("discovery.top") === -1 &&
        Discourse.User.currentProp("should_be_redirected_to_top")) {
      Discourse.User.currentProp("should_be_redirected_to_top", false);
      const period = Discourse.User.currentProp("redirect_to_top.period") || "all";
      this.replaceWith(`discovery.top${period.capitalize()}`);
    }
  },

  actions: {
    loading() {
      this.controllerFor("discovery").set("loading", true);
      return true;
    },

    loadingComplete() {
      this.controllerFor("discovery").set("loading", false);
      if (!this.session.get("topicListScrollPosition")) {
        scrollTop();
      }
    },

    didTransition() {
      this.controllerFor("discovery")._showFooter();
      this.send("loadingComplete");
      return true;
    },

    // clear a pinned topic
    clearPin(topic) {
      topic.clearPin();
    },

    createTopic() {
      this.openComposer(this.controllerFor("discovery/topics"));
    }
  }

});

export default DiscoveryRoute;
