/**
  The parent route for all discovery routes.
  Handles the logic for showing the loading spinners.
**/
import OpenComposer from "discourse/mixins/open-composer";
import { scrollTop } from "discourse/mixins/scroll-top";

export default Discourse.Route.extend(OpenComposer, {
  redirect() {
    return this.redirectIfLoginRequired();
  },

  beforeModel(transition) {
    if (
      (transition.intent.url === "/" ||
        transition.intent.url === "/latest" ||
        transition.intent.url === "/categories") &&
      transition.targetName.indexOf("discovery.top") === -1 &&
      Discourse.User.currentProp("should_be_redirected_to_top")
    ) {
      Discourse.User.currentProp("should_be_redirected_to_top", false);
      const period =
        Discourse.User.currentProp("redirect_to_top.period") || "all";
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
      return false;
    },

    didTransition() {
      this.controllerFor("discovery")._showFooter();
      this.send("loadingComplete");
      return false;
    },

    // clear a pinned topic
    clearPin(topic) {
      topic.clearPin();
    },

    createTopic() {
      const model = this.controllerFor("discovery/topics").get("model");
      if (model.draft) {
        this.openTopicDraft(model);
      } else {
        this.openComposer(this.controllerFor("discovery/topics"));
      }
    },

    dismissReadTopics(dismissTopics) {
      var operationType = dismissTopics ? "topics" : "posts";
      this.controllerFor("discovery/topics").send("dismissRead", operationType);
    },

    dismissRead(operationType) {
      this.controllerFor("discovery/topics").send("dismissRead", operationType);
    }
  }
});
