import { alias } from "@ember/object/computed";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import BulkTopicSelection from "discourse/mixins/bulk-topic-selection";
import NavItem from "discourse/models/nav-item";
import FilterModeMixin from "discourse/mixins/filter-mode";
import { queryParams } from "discourse/controllers/discovery-sortable";

export default Controller.extend(BulkTopicSelection, FilterModeMixin, {
  application: inject(),

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

  categories: alias("site.categoriesList"),

  @discourseComputed("list", "list.draft")
  createTopicLabel(list, listDraft) {
    return listDraft ? "topic.open_draft" : "topic.create";
  },

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
      noSubcategories
    });
  },

  @discourseComputed("category")
  showTagFilter() {
    return Discourse.SiteSettings.show_filter_by_tag;
  },

  @discourseComputed("additionalTags", "category", "tag.id")
  showToggleInfo(additionalTags, category, tagId) {
    return !additionalTags && !category && tagId !== "none";
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
    if (loading || listTopicsLength !== 0) {
      return;
    }

    if (listTopicsLength === 0) {
      return I18n.t(`tagging.topics.none.${navMode}`, {
        tag: this.get("tag.id")
      });
    } else {
      return I18n.t(`tagging.topics.bottom.${navMode}`, {
        tag: this.get("tag.id")
      });
    }
  },

  actions: {
    changeSort(order) {
      if (order === this.order) {
        this.toggleProperty("ascending");
      } else {
        this.setProperties({ order, ascending: false });
      }

      this.transitionToRoute({
        queryParams: { order, ascending: this.ascending }
      });
    },

    toggleInfo() {
      this.toggleProperty("showInfo");
    },

    refresh() {
      // TODO: this probably doesn't work anymore
      return this.store
        .findFiltered("topicList", { filter: "tags/" + this.get("tag.id") })
        .then(list => {
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
            count: tagInfo.synonyms.length
          });
      }

      bootbox.confirm(confirmText, result => {
        if (!result) return;

        this.tag
          .destroyRecord()
          .then(() => this.transitionToRoute("tags.index"))
          .catch(() => bootbox.alert(I18n.t("generic_error")));
      });
    },

    changeTagNotificationLevel(notificationLevel) {
      this.tagNotification.update({ notification_level: notificationLevel });
    }
  }
});
