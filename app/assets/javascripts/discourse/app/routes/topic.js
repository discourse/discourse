import { cancel, later, schedule } from "@ember/runloop";
import DiscourseRoute from "discourse/routes/discourse";
import DiscourseURL from "discourse/lib/url";
import { ID_CONSTRAINT } from "discourse/models/topic";
import { action, get } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { inject as service } from "@ember/service";
import { setTopicId } from "discourse/lib/topic-list-tracker";
import showModal from "discourse/lib/show-modal";
import { isTesting } from "discourse-common/config/environment";

const SCROLL_DELAY = isTesting() ? 0 : 500;

const TopicRoute = DiscourseRoute.extend({
  screenTrack: service(),

  init() {
    this._super(...arguments);

    this.setProperties({
      isTransitioning: false,
      scheduledReplace: null,
      lastScrollPos: null,
    });
  },

  redirect() {
    return this.redirectIfLoginRequired();
  },

  queryParams: {
    filter: { replace: true },
    username_filters: { replace: true },
  },

  titleToken() {
    const model = this.modelFor("topic");
    if (model) {
      const result = model.get("unicode_title") || model.get("title"),
        cat = model.get("category");

      // Only display uncategorized in the title tag if it was renamed
      if (
        this.siteSettings.topic_page_title_includes_category &&
        cat &&
        !(
          cat.get("isUncategorizedCategory") &&
          cat.get("name").toLowerCase() === "uncategorized"
        )
      ) {
        let catName = cat.get("name");

        const parentCategory = cat.get("parentCategory");
        if (parentCategory) {
          catName = parentCategory.get("name") + " / " + catName;
        }

        return [result, catName];
      }
      return result;
    }
  },

  @action
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
            inviteModel: this.modelFor("topic"),
          },
        },
      ],
    });
  },

  @action
  showFlags(model) {
    let controller = showModal("flag", { model });
    controller.setProperties({ flagTopic: false });
  },

  @action
  showFlagTopic() {
    const model = this.modelFor("topic");
    let controller = showModal("flag", { model });
    controller.setProperties({ flagTopic: true });
  },

  @action
  showPagePublish() {
    const model = this.modelFor("topic");
    showModal("publish-page", {
      model,
      title: "topic.publish_page.title",
    });
  },

  @action
  showTopicTimerModal() {
    const model = this.modelFor("topic");

    const topicTimer = model.get("topic_timer");
    if (!topicTimer) {
      model.set("topic_timer", {});
    }

    showModal("edit-topic-timer", { model });
    this.controllerFor("modal").set("modalClass", "edit-topic-timer-modal");
  },

  @action
  showTopicSlowModeUpdate() {
    const model = this.modelFor("topic");

    showModal("edit-slow-mode", { model });
  },

  @action
  showChangeTimestamp() {
    showModal("change-timestamp", {
      model: this.modelFor("topic"),
      title: "topic.change_timestamp.title",
    });
  },

  @action
  showFeatureTopic() {
    showModal("featureTopic", {
      model: this.modelFor("topic"),
      title: "topic.feature_topic.title",
    });
    this.controllerFor("modal").set("modalClass", "feature-topic-modal");
    this.controllerFor("feature_topic").reset();
  },

  @action
  showHistory(model, revision) {
    let historyController = showModal("history", {
      model,
      modalClass: "history-modal",
    });
    historyController.refresh(model.get("id"), revision || "latest");
    historyController.set("post", model);
    historyController.set("topicController", this.controllerFor("topic"));
  },

  @action
  showGrantBadgeModal() {
    showModal("grant-badge", {
      model: this.modelFor("topic"),
      title: "admin.badges.grant_badge",
    });
  },

  @action
  showRawEmail(model) {
    showModal("raw-email", { model });
    this.controllerFor("raw_email").loadRawEmail(model.get("id"));
  },

  @action
  moveToTopic() {
    showModal("move-to-topic", {
      model: this.modelFor("topic"),
      title: "topic.move_to.title",
    });
  },

  @action
  changeOwner() {
    showModal("change-owner", {
      model: this.modelFor("topic"),
      title: "topic.change_owner.title",
    });
  },

  // Use replaceState to update the URL once it changes
  @action
  postChangedRoute(currentPost) {
    // do nothing if we are transitioning to another route
    if (this.isTransitioning || TopicRoute.disableReplaceState) {
      return;
    }

    const topic = this.modelFor("topic");
    if (topic && currentPost) {
      let postUrl;
      if (currentPost > 1) {
        postUrl = topic.urlForPostNumber(currentPost);
      } else {
        postUrl = topic.url;
      }

      if (this._router.currentRoute.queryParams) {
        let searchParams;

        Object.entries(this._router.currentRoute.queryParams).map(
          ([key, value]) => {
            if (!searchParams) {
              searchParams = new URLSearchParams();
            }

            searchParams.append(key, value);
          }
        );

        if (searchParams) {
          postUrl += `?${searchParams.toString()}`;
        }
      }

      cancel(this.scheduledReplace);

      this.setProperties({
        lastScrollPos: parseInt($(document).scrollTop(), 10),
        scheduledReplace: later(
          this,
          "_replaceUnlessScrolling",
          postUrl,
          SCROLL_DELAY
        ),
      });
    }
  },

  @action
  didTransition() {
    const controller = this.controllerFor("topic");
    controller._showFooter();
    const topicId = controller.get("model.id");
    setTopicId(topicId);
    return true;
  },

  @action
  willTransition(transition) {
    this._super(...arguments);
    cancel(this.scheduledReplace);
    this.set("isTransitioning", true);
    transition.catch(() => this.set("isTransitioning", false));
    return true;
  },

  // replaceState can be very slow on Android Chrome. This function debounces replaceState
  // within a topic until scrolling stops
  _replaceUnlessScrolling(url) {
    const currentPos = parseInt($(document).scrollTop(), 10);
    if (currentPos === this.lastScrollPos) {
      DiscourseURL.replaceState(url);
      return;
    }

    this.setProperties({
      lastScrollPos: currentPos,
      scheduledReplace: later(
        this,
        "_replaceUnlessScrolling",
        url,
        SCROLL_DELAY
      ),
    });
  },

  setupParams(topic, params) {
    const postStream = topic.get("postStream");
    postStream.set("summary", get(params, "filter") === "summary");

    const usernames = get(params, "username_filters"),
      userFilters = postStream.get("userFilters");

    userFilters.clear();
    if (!isEmpty(usernames) && usernames !== "undefined") {
      userFilters.addObjects(usernames.split(","));
    }

    return topic;
  },

  model(params, transition) {
    if (params.slug.match(ID_CONSTRAINT)) {
      transition.abort();

      DiscourseURL.routeTo(`/t/topic/${params.slug}/${params.id}`, {
        replaceURL: true,
      });

      return;
    }

    const queryParams = transition.to.queryParams;

    let topic = this.modelFor("topic");
    if (topic && topic.get("id") === parseInt(params.id, 10)) {
      this.setupParams(topic, queryParams);
      return topic;
    } else {
      let props = Object.assign({}, params);
      delete props.username_filters;
      delete props.filter;
      topic = this.store.createRecord("topic", props);
      return this.setupParams(topic, queryParams);
    }
  },

  activate() {
    this._super(...arguments);
    this.set("isTransitioning", false);

    const topic = this.modelFor("topic");
    this.session.set("lastTopicIdViewed", parseInt(topic.get("id"), 10));
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
    this.set("isTransitioning", false);

    controller.setProperties({
      model,
      editingTopic: false,
      firstPostExpanded: false,
    });

    this.searchService.set("searchContext", model.get("searchContext"));

    // close the multi select when switching topics
    controller.set("multiSelect", false);
    controller.get("quoteState").clear();

    this.controllerFor("composer").set("topic", model);
    this.topicTrackingState.trackIncoming("all");

    // We reset screen tracking every time a topic is entered
    this.screenTrack.start(model.get("id"), controller);

    schedule("afterRender", () =>
      this.appEvents.trigger("header:update-topic", model)
    );
  },
});

export default TopicRoute;
