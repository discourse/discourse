import DiscourseURL from "discourse/lib/url";
import { ID_CONSTRAINT } from "discourse/models/topic";

let isTransitioning = false,
  scheduledReplace = null,
  lastScrollPos = null;

const SCROLL_DELAY = 500;

import showModal from "discourse/lib/show-modal";

const TopicRoute = Discourse.Route.extend({
  redirect() {
    return this.redirectIfLoginRequired();
  },

  queryParams: {
    filter: { replace: true },
    username_filters: { replace: true }
  },

  titleToken() {
    const model = this.modelFor("topic");
    if (model) {
      const result = model.unicode_title || model.title,
        cat = model.category;

      // Only display uncategorized in the title tag if it was renamed
      if (
        this.siteSettings.topic_page_title_includes_category &&
        cat &&
        !(
          cat.isUncategorizedCategory &&
          cat.name.toLowerCase() === "uncategorized"
        )
      ) {
        let catName = cat.name;

        const parentCategory = cat.parentCategory;
        if (parentCategory) {
          catName = parentCategory.name + " / " + catName;
        }

        return [result, catName];
      }
      return result;
    }
  },

  actions: {
    showInvite() {
      let invitePanelTitle;

      if (this.isPM) {
        invitePanelTitle = "topic.invite_private.title";
      } else if (this.invitingToTopic) {
        invitePanelTitle = "topic.invite_reply.title";
      } else {
        invitePanelTitle = "user.invited.create";
      }

      showModal("share-and-invite", {
        modalClass: "share-and-invite",
        panels: [
          {
            id: "invite",
            title: invitePanelTitle,
            model: {
              inviteModel: this.modelFor("topic")
            }
          }
        ]
      });
    },

    showFlags(model) {
      let controller = showModal("flag", { model });
      controller.setProperties({ flagTopic: false });
    },

    showFlagTopic() {
      const model = this.modelFor("topic");
      let controller = showModal("flag", { model });
      controller.setProperties({ flagTopic: true });
    },

    showTopicStatusUpdate() {
      const model = this.modelFor("topic");

      const topicTimer = model.topic_timer;
      if (!topicTimer) {
        model.set("topic_timer", {});
      }

      const privateTopicTimer = model.private_topic_timer;
      if (!privateTopicTimer) {
        model.set("private_topic_timer", {});
      }

      showModal("edit-topic-timer", { model });
      this.controllerFor("modal").set("modalClass", "edit-topic-timer-modal");
    },

    showChangeTimestamp() {
      showModal("change-timestamp", {
        model: this.modelFor("topic"),
        title: "topic.change_timestamp.title"
      });
    },

    showFeatureTopic() {
      showModal("featureTopic", {
        model: this.modelFor("topic"),
        title: "topic.feature_topic.title"
      });
      this.controllerFor("modal").set("modalClass", "feature-topic-modal");
      this.controllerFor("feature_topic").reset();
    },

    showHistory(model, revision) {
      let historyController = showModal("history", {
        model,
        modalClass: "history-modal"
      });
      historyController.refresh(model.id, revision || "latest");
      historyController.set("post", model);
      historyController.set("topicController", this.controllerFor("topic"));
    },

    showGrantBadgeModal() {
      showModal("grant-badge", {
        model: this.modelFor("topic"),
        title: "admin.badges.grant_badge"
      });
    },

    showRawEmail(model) {
      showModal("raw-email", { model });
      this.controllerFor("raw_email").loadRawEmail(model.id);
    },

    moveToTopic() {
      showModal("move-to-topic", {
        model: this.modelFor("topic"),
        title: "topic.move_to.title"
      });
    },

    changeOwner() {
      showModal("change-owner", {
        model: this.modelFor("topic"),
        title: "topic.change_owner.title"
      });
    },

    // Use replaceState to update the URL once it changes
    postChangedRoute(currentPost) {
      // do nothing if we are transitioning to another route
      if (isTransitioning || TopicRoute.disableReplaceState) {
        return;
      }

      const topic = this.modelFor("topic");
      if (topic && currentPost) {
        let postUrl = topic.url;
        if (currentPost > 1) {
          postUrl += "/" + currentPost;
        }

        Ember.run.cancel(scheduledReplace);
        lastScrollPos = parseInt($(document).scrollTop(), 10);
        scheduledReplace = Ember.run.later(
          this,
          "_replaceUnlessScrolling",
          postUrl,
          Ember.Test ? 0 : SCROLL_DELAY
        );
      }
    },

    didTransition() {
      this.controllerFor("topic")._showFooter();
      return true;
    },

    willTransition() {
      this._super(...arguments);
      Ember.run.cancel(scheduledReplace);
      isTransitioning = true;
      return true;
    }
  },

  // replaceState can be very slow on Android Chrome. This function debounces replaceState
  // within a topic until scrolling stops
  _replaceUnlessScrolling(url) {
    const currentPos = parseInt($(document).scrollTop(), 10);
    if (currentPos === lastScrollPos) {
      DiscourseURL.replaceState(url);
      return;
    }
    lastScrollPos = currentPos;
    scheduledReplace = Ember.run.later(
      this,
      "_replaceUnlessScrolling",
      url,
      SCROLL_DELAY
    );
  },

  setupParams(topic, params) {
    const postStream = topic.postStream;
    postStream.set("summary", Ember.get(params, "filter") === "summary");

    const usernames = Ember.get(params, "username_filters"),
      userFilters = postStream.userFilters;

    userFilters.clear();
    if (!Ember.isEmpty(usernames) && usernames !== "undefined") {
      userFilters.addObjects(usernames.split(","));
    }

    return topic;
  },

  model(params, transition) {
    if (params.slug.match(ID_CONSTRAINT)) {
      return DiscourseURL.routeTo(`/t/topic/${params.slug}/${params.id}`, {
        replaceURL: true
      });
    }

    const queryParams = transition.to.queryParams;

    let topic = this.modelFor("topic");
    if (topic && topic.id === parseInt(params.id, 10)) {
      this.setupParams(topic, queryParams);
      return topic;
    } else {
      topic = this.store.createRecord(
        "topic",
        _.omit(params, "username_filters", "filter")
      );
      return this.setupParams(topic, queryParams);
    }
  },

  activate() {
    this._super(...arguments);
    isTransitioning = false;

    const topic = this.modelFor("topic");
    this.session.set("lastTopicIdViewed", parseInt(topic.id, 10));
  },

  deactivate() {
    this._super(...arguments);

    this.searchService.set("searchContext", null);
    this.controllerFor("user-card").set("visible", false);

    const topicController = this.controllerFor("topic");
    const postStream = topicController.get("model.postStream");

    postStream.cancelFilter();

    topicController.set("multiSelect", false);
    this.controllerFor("composer").set("topic", null);
    this.screenTrack.stop();

    this.appEvents.trigger("header:hide-topic");

    this.controllerFor("topic").set("model", null);
  },

  setupController(controller, model) {
    // In case we navigate from one topic directly to another
    isTransitioning = false;

    controller.setProperties({
      model,
      editingTopic: false,
      firstPostExpanded: false
    });

    TopicRoute.trigger("setupTopicController", this);

    this.searchService.set("searchContext", model.searchContext);

    // close the multi select when switching topics
    controller.set("multiSelect", false);
    controller.quoteState.clear();

    this.controllerFor("composer").set("topic", model);
    this.topicTrackingState.trackIncoming("all");

    // We reset screen tracking every time a topic is entered
    this.screenTrack.start(model.id, controller);

    Ember.run.scheduleOnce("afterRender", () => {
      this.appEvents.trigger("header:update-topic", model);
    });
  }
});

RSVP.EventTarget.mixin(TopicRoute);
export default TopicRoute;
