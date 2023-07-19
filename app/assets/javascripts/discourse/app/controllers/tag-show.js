import DiscoverySortableController from "discourse/controllers/discovery-sortable";
import { inject as controller } from "@ember/controller";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import BulkTopicSelection from "discourse/mixins/bulk-topic-selection";
import DismissTopics from "discourse/mixins/dismiss-topics";
import FilterModeMixin from "discourse/mixins/filter-mode";
import I18n from "I18n";
import NavItem from "discourse/models/nav-item";
import Topic from "discourse/models/topic";
import { readOnly } from "@ember/object/computed";
import { endWith } from "discourse/lib/computed";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default DiscoverySortableController.extend(
  BulkTopicSelection,
  DismissTopics,
  FilterModeMixin,
  {
    application: controller(),
    dialog: service(),
    router: service(),
    currentUser: service(),
    siteSettings: service(),

    tag: null,
    additionalTags: null,
    list: null,
    canAdminTag: readOnly("currentUser.staff"),
    navMode: "latest",
    loading: false,
    canCreateTopic: false,
    showInfo: false,
    top: endWith("list.filter", "top"),

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

    @discourseComputed("category", "tag.id", "filterType", "noSubcategories")
    navItems(category, tagId, filterType, noSubcategories) {
      return NavItem.buildList(category, {
        tagId,
        filterType,
        noSubcategories,
        siteSettings: this.siteSettings,
      });
    },

    @observes("list.canLoadMore")
    _showFooter() {
      this.set("application.showFooter", !this.list?.canLoadMore);
    },

    @discourseComputed("navMode", "list.topics.length", "loading")
    footerMessage(navMode, listTopicsLength, loading) {
      if (loading) {
        return;
      }

      if (listTopicsLength === 0) {
        return I18n.t(`tagging.topics.none.${navMode}`, {
          tag: this.tag?.id,
        });
      } else {
        return I18n.t("topics.bottom.tag", {
          tag: this.tag?.id,
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

    callResetNew(dismissPosts = false, dismissTopics = false, untrack = false) {
      const tracked =
        (this.router.currentRoute.queryParams["f"] ||
          this.router.currentRoute.queryParams["filter"]) === "tracked";

      let topicIds = this.selected ? this.selected.mapBy("id") : null;

      Topic.resetNew(this.category, !this.noSubcategories, {
        tracked,
        tag: this.tag,
        topicIds,
        dismissPosts,
        dismissTopics,
        untrack,
      }).then((result) => {
        if (result.topic_ids) {
          this.topicTrackingState.removeTopics(result.topic_ids);
        }
        this.refresh(tracked ? { skipResettingParams: ["filter", "f"] } : {});
      });
    },

    @action
    showInserted(event) {
      event?.preventDefault();
      const tracker = this.topicTrackingState;
      this.list.loadBefore(tracker.newIncoming, true);
      tracker.resetTracking();
      return false;
    },

    @action
    changeSort(order) {
      if (order === this.order) {
        this.toggleProperty("ascending");
      } else {
        this.setProperties({ order, ascending: false });
      }
    },

    @action
    changePeriod(p) {
      this.set("period", p);
    },

    @action
    toggleInfo() {
      this.toggleProperty("showInfo");
    },

    @action
    refresh() {
      return this.store
        .findFiltered("topicList", {
          filter: this.list?.filter,
        })
        .then((list) => {
          this.set("list", list);
          this.resetSelected();
        });
    },

    @action
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

      this.dialog.deleteConfirm({
        message: confirmText,
        didConfirm: () => {
          return this.tag
            .destroyRecord()
            .then(() => this.router.transitionTo("tags.index"))
            .catch(() => this.dialog.alert(I18n.t("generic_error")));
        },
      });
    },

    @action
    changeTagNotificationLevel(notificationLevel) {
      this.tagNotification
        .update({ notification_level: notificationLevel })
        .then((response) => {
          const payload = response.responseJson;

          this.tagNotification.set("notification_level", notificationLevel);

          this.currentUser.setProperties({
            watched_tags: payload.watched_tags,
            watching_first_post_tags: payload.watching_first_post_tags,
            tracked_tags: payload.tracked_tags,
            muted_tags: payload.muted_tags,
            regular_tags: payload.regular_tags,
          });
        });
    },
  }
);
