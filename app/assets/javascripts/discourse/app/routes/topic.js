import { action, get } from "@ember/object";
import { cancel, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import AddPmParticipants from "discourse/components/modal/add-pm-participants";
import AnonymousFlagModal from "discourse/components/modal/anonymous-flag";
import ChangeOwnerModal from "discourse/components/modal/change-owner";
import ChangeTimestampModal from "discourse/components/modal/change-timestamp";
import EditSlowModeModal from "discourse/components/modal/edit-slow-mode";
import EditTopicTimerModal from "discourse/components/modal/edit-topic-timer";
import FeatureTopicModal from "discourse/components/modal/feature-topic";
import FlagModal from "discourse/components/modal/flag";
import GrantBadgeModal from "discourse/components/modal/grant-badge";
import HistoryModal from "discourse/components/modal/history";
import MoveToTopicModal from "discourse/components/modal/move-to-topic";
import PublishPageModal from "discourse/components/modal/publish-page";
import RawEmailModal from "discourse/components/modal/raw-email";
import PostFlag from "discourse/lib/flag-targets/post-flag";
import TopicFlag from "discourse/lib/flag-targets/topic-flag";
import discourseLater from "discourse/lib/later";
import { setTopicId } from "discourse/lib/topic-list-tracker";
import DiscourseURL from "discourse/lib/url";
import { ID_CONSTRAINT } from "discourse/models/topic";
import DiscourseRoute from "discourse/routes/discourse";

const SCROLL_DELAY = 500;

export default class TopicRoute extends DiscourseRoute {
  @service composer;
  @service screenTrack;
  @service currentUser;
  @service modal;
  @service router;

  scheduledReplace = null;

  lastScrollPos = null;
  isTransitioning = false;

  queryParams = {
    filter: { replace: true },
    username_filters: { replace: true },
  };

  buildRouteInfoMetadata() {
    return {
      scrollOnTransition: false,
    };
  }

  redirect() {
    return this.redirectIfLoginRequired();
  }

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
  }

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
  }

  @action
  showFlags(model) {
    this.modal.show(this.currentUser ? FlagModal : AnonymousFlagModal, {
      model: {
        flagTarget: new PostFlag(),
        flagModel: model,
        setHidden: () => model.set("hidden", true),
      },
    });
  }

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
  }

  @action
  showPagePublish() {
    const model = this.modelFor("topic");
    this.modal.show(PublishPageModal, {
      model,
    });
  }

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
  }

  @action
  updateTopicTimerProperty(property, value) {
    this.modelFor("topic").set(`topic_timer.${property}`, value);
  }

  @action
  showTopicSlowModeUpdate() {
    this.modal.show(EditSlowModeModal, {
      model: { topic: this.modelFor("topic") },
    });
  }

  @action
  showChangeTimestamp() {
    this.modal.show(ChangeTimestampModal, {
      model: { topic: this.modelFor("topic") },
    });
  }

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
  }

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
  }

  @action
  showGrantBadgeModal() {
    const topicController = this.controllerFor("topic");
    this.modal.show(GrantBadgeModal, {
      model: {
        selectedPost: topicController.selectedPosts[0],
      },
    });
  }

  @action
  showRawEmail(model) {
    this.modal.show(RawEmailModal, { model });
  }

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
  }

  @action
  changeOwner() {
    const topicController = this.controllerFor("topic");
    this.modal.show(ChangeOwnerModal, {
      model: {
        deselectAll: topicController.deselectAll,
        multiSelect: topicController.multiSelect,
        selectedPostsCount: topicController.selectedPostsCount,
        selectedPostIds: topicController.selectedPostIds,
        selectedPostUsername: topicController.selectedPostsUsername,
        toggleMultiSelect: topicController.toggleMultiSelect,
        topic: this.modelFor("topic"),
      },
    });
  }

  // Use replaceState to update the URL once it changes
  @action
  postChangedRoute(currentPost) {
    if (TopicRoute.disableReplaceState) {
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
        lastScrollPos: document.scrollingElement.scrollTop,
        scheduledReplace: discourseLater(
          this,
          "_replaceUnlessScrolling",
          postUrl,
          topic.id,
          SCROLL_DELAY
        ),
      });
    }
  }

  @action
  didTransition() {
    const controller = this.controllerFor("topic");
    const topicId = controller.get("model.id");
    setTopicId(topicId);
    return true;
  }

  @action
  willTransition() {
    super.willTransition(...arguments);
    cancel(this.scheduledReplace);
    return true;
  }

  // replaceState can be very slow on Android Chrome. This function debounces replaceState
  // within a topic until scrolling stops
  _replaceUnlessScrolling(url, topicId) {
    const { currentRouteName } = this.router;

    const stillOnTopicRoute = currentRouteName.split(".")[0] === "topic";
    if (!stillOnTopicRoute) {
      return;
    }

    const stillOnSameTopic = this.modelFor("topic").id === topicId;
    if (!stillOnSameTopic) {
      return;
    }

    const currentPos = document.scrollingElement.scrollTop;
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
        topicId,
        SCROLL_DELAY
      ),
    });
  }

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
  }

  model(params, transition) {
    if (params.slug.match(ID_CONSTRAINT)) {
      // URL with no slug - redirect to a URL with placeholder slug
      this.router.transitionTo(`/t/-/${params.slug}/${params.id}`);
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
  }

  deactivate() {
    super.deactivate(...arguments);

    this.searchService.searchContext = null;

    const topicController = this.controllerFor("topic");
    const postStream = topicController.get("model.postStream");

    postStream.cancelFilter();

    topicController.set("multiSelect", false);
    this.composer.set("topic", null);
    this.screenTrack.stop();

    this.appEvents.trigger("header:hide-topic");

    this.controllerFor("topic").set("model", null);
  }

  setupController(controller, model) {
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
  }
}
