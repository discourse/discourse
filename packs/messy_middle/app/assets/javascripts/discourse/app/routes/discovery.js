/**
  The parent route for all discovery routes.
  Handles the logic for showing the loading spinners.
**/
import DiscourseRoute from "discourse/routes/discourse";
import OpenComposer from "discourse/mixins/open-composer";
import User from "discourse/models/user";
import { scrollTop } from "discourse/mixins/scroll-top";
import { setTopicList } from "discourse/lib/topic-list-tracker";
import { action } from "@ember/object";

export default DiscourseRoute.extend(OpenComposer, {
  queryParams: {
    filter: { refreshModel: true },
  },

  redirect() {
    return this.redirectIfLoginRequired();
  },

  beforeModel(transition) {
    const url = transition.intent.url;
    let matches;
    if (
      (url === "/" || url === "/latest" || url === "/categories") &&
      !transition.targetName.includes("discovery.top") &&
      User.currentProp("user_option.should_be_redirected_to_top")
    ) {
      User.currentProp("user_option.should_be_redirected_to_top", false);
      const period =
        User.currentProp("user_option.redirected_to_top.period") || "all";
      this.replaceWith("discovery.top", {
        queryParams: {
          period,
        },
      });
    } else if (url && (matches = url.match(/top\/(.*)$/))) {
      if (this.site.periods.includes(matches[1])) {
        this.replaceWith("discovery.top", {
          queryParams: {
            period: matches[1],
          },
        });
      }
    }
  },

  @action
  loading() {
    this.controllerFor("discovery").loadingBegan();

    // We don't want loading to bubble
    return true;
  },

  @action
  loadingComplete() {
    this.controllerFor("discovery").loadingComplete();
    if (!this.session.get("topicListScrollPosition")) {
      scrollTop();
    }
  },

  @action
  didTransition() {
    this.send("loadingComplete");

    const model = this.controllerFor("discovery/topics").get("model");
    setTopicList(model);
  },

  // clear a pinned topic
  @action
  clearPin(topic) {
    topic.clearPin();
  },

  @action
  createTopic() {
    if (this.get("currentUser.has_topic_draft")) {
      this.openTopicDraft();
    } else {
      this.openComposer(this.controllerFor("discovery/topics"));
    }
  },

  @action
  dismissReadTopics(dismissTopics) {
    const operationType = dismissTopics ? "topics" : "posts";
    this.send("dismissRead", operationType);
  },

  @action
  dismissRead(operationType) {
    const controller = this.controllerFor("discovery/topics");
    controller.send("dismissRead", operationType, {
      categoryId: controller.get("category.id"),
      includeSubcategories: !controller.noSubcategories,
    });
  },
});
