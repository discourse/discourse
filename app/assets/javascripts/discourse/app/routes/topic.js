import { cancel, schedule } from "@ember/runloop";
import discourseLater from "discourse-common/lib/later";
import DiscourseRoute from "discourse/routes/discourse";
import DiscourseURL from "discourse/lib/url";
import { ID_CONSTRAINT } from "discourse/models/topic";
import { action, get } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { inject as service } from "@ember/service";
import { setTopicId } from "discourse/lib/topic-list-tracker";
import showModal from "discourse/lib/show-modal";
import TopicFlag from "discourse/lib/flag-targets/topic-flag";
import PostFlag from "discourse/lib/flag-targets/post-flag";
import HistoryModal from "discourse/components/modal/history";
import PublishPageModal from "discourse/components/modal/publish-page";
import EditSlowModeModal from "discourse/components/modal/edit-slow-mode";
import ChangeTimestampModal from "discourse/components/modal/change-timestamp";
import EditTopicTimerModal from "discourse/components/modal/edit-topic-timer";
import FeatureTopicModal from "discourse/components/modal/feature-topic";
import FlagModal from "discourse/components/modal/flag";
import GrantBadgeModal from "discourse/components/modal/grant-badge";
import MoveToTopicModal from "discourse/components/modal/move-to-topic";
import RawEmailModal from "discourse/components/modal/raw-email";
import AddPmParticipants from "discourse/components/modal/add-pm-participants";

const SCROLL_DELAY = 500;

const TopicRoute = DiscourseRoute.extend({
  composer: service(),
  screenTrack: service(),
  modal: service(),

  scheduledReplace: null,
  lastScrollPos: null,
  isTransitioning: false,

  buildRouteInfoMetadata() {
    return {
      scrollOnTransition: false,
    };
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
      if (model.get("errorHtml")) {
        return model.get("errorTitle");
      }

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
    let modalTitle;

    if (this.isPM) {
      modalTitle = "topic.invite_private.title";
    } else if (this.invitingToTopic) {
      modalTitle = "topic.invite_reply.title";
    } else {
      modalTitle = "user.invited.create";
    }

    this.modal.show(AddPmParticipants, {
      model: {
        title: modalTitle,
        inviteModel: this.modelFor("topic"),
      },
    });
  },

  @action
  showFlags(model) {
    this.modal.show(FlagModal, {
      model: {
        flagTarget: new PostFlag(),
        flagModel: model,
        setHidden: () => model.set("hidden", true),
      },
    });
  },

  @action
  showFlagTopic() {
    const model = this.modelFor("topic");
    this.modal.show(FlagModal, {
      model: {
        flagTarget: new TopicFlag(),
        flagModel: model,
        setHidden: () => model.set("hidden", true),
      },
    });
  },

  @action
  showPagePublish() {
    const model = this.modelFor("topic");
    this.modal.show(PublishPageModal, {
      model,
    });
  },

  @action
  showTopicTimerModal() {
    const model = this.modelFor("topic");
    this.modal.show(EditTopicTimerModal, {
      model: {
        topic: model,
        setTopicTimer: (v) => model.set("topic_timer", v),
        updateTopicTimerProperty: this.updateTopicTimerProperty,
      },
    });
  },

  @action
  updateTopicTimerProperty(property, value) {
    this.modelFor("topic").set(`topic_timer.${property}`, value);
  },

  @action
  showTopicSlowModeUpdate() {
    this.modal.show(EditSlowModeModal, {
      model: { topic: this.modelFor("topic") },
    });
  },

  @action
  showChangeTimestamp() {
    this.modal.show(ChangeTimestampModal, {
      model: { topic: this.modelFor("topic") },
    });
  },

  @action
  showFeatureTopic() {
    const topicController = this.controllerFor("topic");
    const model = this.modelFor("topic");
    model.setProperties({
      pinnedInCategoryUntil: null,
      pinnedGloballyUntil: null,
    });

    this.modal.show(FeatureTopicModal, {
      model: {
        topic: model,
        pinGlobally: () => topicController.send("pinGlobally"),
        togglePinned: () => topicController.send("togglePinned"),
        makeBanner: () => topicController.send("makeBanner"),
        removeBanner: () => topicController.send("removeBanner"),
      },
    });
  },

  @action
  showHistory(model, revision) {
    this.modal.show(HistoryModal, {
      model: {
        postId: model.id,
        postVersion: revision || "latest",
        post: model,
        editPost: (post) => this.controllerFor("topic").send("editPost", post),
      },
    });
  },

  @action
  showGrantBadgeModal() {
    const topicController = this.controllerFor("topic");
    this.modal.show(GrantBadgeModal, {
      model: {
        selectedPost: topicController.selectedPosts[0],
      },
    });
  },

  @action
  showRawEmail(model) {
    this.modal.show(RawEmailModal, { model });
  },

  @action
  moveToTopic() {
    const topicController = this.controllerFor("topic");
    this.modal.show(MoveToTopicModal, {
      model: {
        topic: this.modelFor("topic"),
        selectedPostsCount: topicController.selectedPostsCount,
        selectedAllPosts: topicController.selectedAllPosts,
        selectedPosts: topicController.selectedPosts,
        selectedPostIds: topicController.selectedPostIds,
        toggleMultiSelect: topicController.toggleMultiSelect,
      },
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
        scheduledReplace: discourseLater(
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
      scheduledReplace: discourseLater(
        this,
        "_replaceUnlessScrolling",
        url,
        SCROLL_DELAY
      ),
    });
  },

  setupParams(topic, params) {
    const postStream = topic.get("postStream");
    postStream.set("filter", get(params, "filter"));

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
      let props = { ...params };
      delete props.username_filters;
      delete props.filter;
      topic = this.store.createRecord("topic", props);
      return this.setupParams(topic, queryParams);
    }
  },

  activate() {
    this._super(...arguments);
    this.set("isTransitioning", false);
  },

  deactivate() {
    this._super(...arguments);

    this.searchService.searchContext = null;

    const topicController = this.controllerFor("topic");
    const postStream = topicController.get("model.postStream");

    postStream.cancelFilter();

    topicController.set("multiSelect", false);
    this.composer.set("topic", null);
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

    this.searchService.searchContext = model.get("searchContext");

    // close the multi select when switching topics
    controller.set("multiSelect", false);
    controller.get("quoteState").clear();

    this.composer.set("topic", model);
    this.topicTrackingState.trackIncoming("all");

    // We reset screen tracking every time a topic is entered
    this.screenTrack.start(model.get("id"), controller);

    schedule("afterRender", () =>
      this.appEvents.trigger("header:update-topic", model)
    );
  },
});

export default TopicRoute;
