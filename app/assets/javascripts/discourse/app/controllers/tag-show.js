import Controller, { inject as controller } from "@ember/controller";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import BulkTopicSelection from "discourse/mixins/bulk-topic-selection";
import FilterModeMixin from "discourse/mixins/filter-mode";
import I18n from "I18n";
import NavItem from "discourse/models/nav-item";
import Topic from "discourse/models/topic";
import { alias } from "@ember/object/computed";
import bootbox from "bootbox";
import { queryParams } from "discourse/controllers/discovery-sortable";
import { endWith } from "discourse/lib/computed";

export default Controller.extend(BulkTopicSelection, FilterModeMixin, {
  application: controller(),

  tag: null,
  additionalTags: null,
  list: null,
  canAdminTag: alias("currentUser.staff"),
  navMode: "latest",
  loading: false,
  canCreateTopic: false,
  order: "default",
  ascending: false,
  status: null,
  state: null,
  search: null,
  max_posts: null,
  q: null,
  showInfo: false,
  top: endWith("list.filter", "top"),
  period: alias("list.for_period"),

  @discourseComputed(
    "canCreateTopic",
    "category",
    "canCreateTopicOnCategory",
    "tag",
    "canCreateTopicOnTag"
  )
  createTopicDisabled(
    canCreateTopic,
    category,
    canCreateTopicOnCategory,
    tag,
    canCreateTopicOnTag
  ) {
    return (
      !canCreateTopic ||
      (category && !canCreateTopicOnCategory) ||
      (tag && !canCreateTopicOnTag)
    );
  },

  queryParams: Object.keys(queryParams),

  @discourseComputed("category", "tag.id", "filterType", "noSubcategories")
  navItems(category, tagId, filterType, noSubcategories) {
    return NavItem.buildList(category, {
      tagId,
      filterType,
      noSubcategories,
      siteSettings: this.siteSettings,
    });
  },

  @discourseComputed("category")
  showTagFilter() {
    return true;
  },

  loadMoreTopics() {
    return this.list.loadMore();
  },

  @observes("list.canLoadMore")
  _showFooter() {
    this.set("application.showFooter", !this.get("list.canLoadMore"));
  },

  @discourseComputed("navMode", "list.topics.length", "loading")
  footerMessage(navMode, listTopicsLength, loading) {
    if (loading) {
      return;
    }

    if (listTopicsLength === 0) {
      return I18n.t(`tagging.topics.none.${navMode}`, {
        tag: this.get("tag.id"),
      });
    } else {
      return I18n.t(`topics.bottom.tag`, {
        tag: this.get("tag.id"),
      });
    }
  },

  @discourseComputed("list.filter", "list.topics.length")
  showDismissRead(filter, topicsLength) {
    return this._isFilterPage(filter, "unread") && topicsLength > 0;
  },

  @discourseComputed("list.filter", "list.topics.length")
  showResetNew(filter, topicsLength) {
    return this._isFilterPage(filter, "new") && topicsLength > 0;
  },

  actions: {
    resetNew() {
      const tracked =
        (this.router.currentRoute.queryParams["f"] ||
          this.router.currentRoute.queryParams["filter"]) === "tracked";

      let topicIds = this.selected
        ? this.selected.map((topic) => topic.id)
        : null;

      Topic.resetNew(this.category, !this.noSubcategories, {
        tracked,
        tag: this.tag,
        topicIds,
      }).then(() =>
        this.send(
          "refresh",
          tracked ? { skipResettingParams: ["filter", "f"] } : {}
        )
      );
    },

    showInserted() {
      const tracker = this.topicTrackingState;
      this.list.loadBefore(tracker.get("newIncoming"), true);
      tracker.resetTracking();
      return false;
    },

    changeSort(order) {
      if (order === this.order) {
        this.toggleProperty("ascending");
      } else {
        this.setProperties({ order, ascending: false });
      }

      let params = { order, ascending: this.ascending };
      if (this.period) {
        params.period = this.period;
      }

      this.transitionToRoute({
        queryParams: params,
      });
    },

    changePeriod(p) {
      this.set("period", p);

      let params = { period: this.period };

      if (!(this.order === "default" && this.ascending === false)) {
        params = Object.assign(params, {
          order: this.order,
          ascending: this.ascending,
        });
      }

      this.transitionToRoute({
        queryParams: params,
      });
    },

    toggleInfo() {
      this.toggleProperty("showInfo");
    },

    refresh() {
      return this.store
        .findFiltered("topicList", {
          filter: this.get("list.filter"),
        })
        .then((list) => {
          this.set("list", list);
          this.resetSelected();
        });
    },

    deleteTag(tagInfo) {
      const numTopics =
        this.get("list.topic_list.tags.firstObject.topic_count") || 0;

      let confirmText =
        numTopics === 0
          ? I18n.t("tagging.delete_confirm_no_topics")
          : I18n.t("tagging.delete_confirm", { count: numTopics });

      if (tagInfo.synonyms.length > 0) {
        confirmText +=
          " " +
          I18n.t("tagging.delete_confirm_synonyms", {
            count: tagInfo.synonyms.length,
          });
      }

      bootbox.confirm(confirmText, (result) => {
        if (!result) {
          return;
        }

        this.tag
          .destroyRecord()
          .then(() => this.transitionToRoute("tags.index"))
          .catch(() => bootbox.alert(I18n.t("generic_error")));
      });
    },

    changeTagNotificationLevel(notificationLevel) {
      this.tagNotification
        .update({ notification_level: notificationLevel })
        .then((response) => {
          this.currentUser.set(
            "muted_tag_ids",
            this.currentUser.calculateMutedIds(
              notificationLevel,
              response.responseJson.tag_id,
              "muted_tag_ids"
            )
          );
        });
    },
  },
});
