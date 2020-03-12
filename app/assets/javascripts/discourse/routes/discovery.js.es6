/**
  The parent route for all discovery routes.
  Handles the logic for showing the loading spinners.
**/
import DiscourseRoute from "discourse/routes/discourse";
import OpenComposer from "discourse/mixins/open-composer";
import { scrollTop } from "discourse/mixins/scroll-top";
import User from "discourse/models/user";

export default DiscourseRoute.extend(OpenComposer, {
  redirect() {
    return this.redirectIfLoginRequired();
  },

  beforeModel(transition) {
    // the new bookmark list is radically different to this topic-based one,
    // including being able to show links to multiple posts to the same topic
    // and being based on a different model. better to just redirect
    const url = transition.intent.url;
    if (
      this.siteSettings.enable_bookmarks_with_reminders &&
      url === "/bookmarks"
    ) {
      this.transitionTo(
        "userActivity.bookmarksWithReminders",
        this.currentUser
      );
    }

    if (
      (url === "/" || url === "/latest" || url === "/categories") &&
      transition.targetName.indexOf("discovery.top") === -1 &&
      User.currentProp("should_be_redirected_to_top")
    ) {
      User.currentProp("should_be_redirected_to_top", false);
      const period = User.currentProp("redirected_to_top.period") || "all";
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
      const operationType = dismissTopics ? "topics" : "posts";
      this.send("dismissRead", operationType);
    },

    dismissRead(operationType) {
      const controller = this.controllerFor("discovery/topics");
      controller.send("dismissRead", operationType, {
        includeSubcategories: !controller.noSubcategories
      });
    }
  }
});
