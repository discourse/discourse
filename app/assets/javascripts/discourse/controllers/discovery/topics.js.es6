import { inject } from "@ember/controller";
import DiscoveryController from "discourse/controllers/discovery";
import { queryParams } from "discourse/controllers/discovery-sortable";
import BulkTopicSelection from "discourse/mixins/bulk-topic-selection";
import { endWith } from "discourse/lib/computed";
import showModal from "discourse/lib/show-modal";
import { userPath } from "discourse/lib/url";
import TopicList from "discourse/models/topic-list";
import computed from "ember-addons/ember-computed-decorators";

const controllerOpts = {
  discovery: inject(),
  discoveryTopics: inject("discovery/topics"),

  period: null,

  canStar: Ember.computed.alias("currentUser.id"),
  showTopicPostBadges: Ember.computed.not("discoveryTopics.new"),
  redirectedReason: Ember.computed.alias(
    "currentUser.redirected_to_top.reason"
  ),

  order: "default",
  ascending: false,
  expandGloballyPinned: false,
  expandAllPinned: false,

  resetParams() {
    Object.keys(this.get("model.params") || {}).forEach(key => {
      // controllerOpts contains the default values for parameters, so use them. They might be null.
      this.set(key, controllerOpts[key]);
    });
  },

  actions: {
    changeSort(sortBy) {
      if (sortBy === this.order) {
        this.toggleProperty("ascending");
      } else {
        this.setProperties({ order: sortBy, ascending: false });
      }

      this.model.refreshSort(sortBy, this.ascending);
    },

    // Show newly inserted topics
    showInserted() {
      const tracker = this.topicTrackingState;

      // Move inserted into topics
      this.model.loadBefore(tracker.get("newIncoming"), true);
      tracker.resetTracking();
      return false;
    },

    refresh() {
      const filter = this.get("model.filter");
      this.resetParams();

      // Don't refresh if we're still loading
      if (this.get("discovery.loading")) {
        return;
      }

      // If we `send('loading')` here, due to returning true it bubbles up to the
      // router and ember throws an error due to missing `handlerInfos`.
      // Lesson learned: Don't call `loading` yourself.
      this.set("discovery.loading", true);

      this.topicTrackingState.resetTracking();
      this.store.findFiltered("topicList", { filter }).then(list => {
        TopicList.hideUniformCategory(list, this.category);

        this.setProperties({ model: list });
        this.resetSelected();

        if (this.topicTrackingState) {
          this.topicTrackingState.sync(list, filter);
        }

        this.send("loadingComplete");
      });
    },

    resetNew() {
      this.topicTrackingState.resetNew();
      Discourse.Topic.resetNew().then(() => this.send("refresh"));
    },

    dismissReadPosts() {
      showModal("dismiss-read", { title: "topics.bulk.dismiss_read" });
    }
  },

  isFilterPage: function(filter, filterType) {
    if (!filter) {
      return false;
    }
    return filter.match(new RegExp(filterType + "$", "gi")) ? true : false;
  },

  @computed("model.filter", "model.topics.length")
  showDismissRead(filter, topicsLength) {
    return this.isFilterPage(filter, "unread") && topicsLength > 0;
  },

  @computed("model.filter", "model.topics.length")
  showResetNew(filter, topicsLength) {
    return filter === "new" && topicsLength > 0;
  },

  @computed("model.filter", "model.topics.length")
  showDismissAtTop(filter, topicsLength) {
    return (
      (this.isFilterPage(filter, "new") ||
        this.isFilterPage(filter, "unread")) &&
      topicsLength >= 15
    );
  },

  hasTopics: Ember.computed.gt("model.topics.length", 0),
  allLoaded: Ember.computed.empty("model.more_topics_url"),
  latest: endWith("model.filter", "latest"),
  new: endWith("model.filter", "new"),
  top: Ember.computed.notEmpty("period"),
  yearly: Ember.computed.equal("period", "yearly"),
  quarterly: Ember.computed.equal("period", "quarterly"),
  monthly: Ember.computed.equal("period", "monthly"),
  weekly: Ember.computed.equal("period", "weekly"),
  daily: Ember.computed.equal("period", "daily"),

  @computed("allLoaded", "model.topics.length")
  footerMessage(allLoaded, topicsLength) {
    if (!allLoaded) return;

    const category = this.category;
    if (category) {
      return I18n.t("topics.bottom.category", {
        category: category.get("name")
      });
    } else {
      const split = (this.get("model.filter") || "").split("/");
      if (topicsLength === 0) {
        return I18n.t("topics.none." + split[0], {
          category: split[1]
        });
      } else {
        return I18n.t("topics.bottom." + split[0], {
          category: split[1]
        });
      }
    }
  },

  @computed("allLoaded", "model.topics.length")
  footerEducation(allLoaded, topicsLength) {
    if (!allLoaded || topicsLength > 0 || !this.currentUser) {
      return;
    }

    const segments = (this.get("model.filter") || "").split("/");

    const tab = segments[segments.length - 1];
    if (tab !== "new" && tab !== "unread") {
      return;
    }

    return I18n.t("topics.none.educate." + tab, {
      userPrefsUrl: userPath(
        `${this.currentUser.get("username_lower")}/preferences`
      )
    });
  }
};

Object.keys(queryParams).forEach(function(p) {
  // If we don't have a default value, initialize it to null
  if (typeof controllerOpts[p] === "undefined") {
    controllerOpts[p] = null;
  }
});

export default DiscoveryController.extend(controllerOpts, BulkTopicSelection);
