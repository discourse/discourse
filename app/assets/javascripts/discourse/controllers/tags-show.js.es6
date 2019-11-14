import { alias } from "@ember/object/computed";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import {
  default as discourseComputed,
  observes
} from "discourse-common/utils/decorators";
import BulkTopicSelection from "discourse/mixins/bulk-topic-selection";
import { default as NavItem } from "discourse/models/nav-item";

export default Controller.extend(BulkTopicSelection, {
  application: inject(),

  tag: null,
  additionalTags: null,
  list: null,
  canAdminTag: alias("currentUser.staff"),
  filterMode: null,
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

  queryParams: [
    "order",
    "ascending",
    "status",
    "state",
    "search",
    "max_posts",
    "q"
  ],

  @discourseComputed("category", "tag.id", "filterMode", "noSubcategories")
  navItems(category, tagId, filterMode, noSubcategories) {
    return NavItem.buildList(category, {
      tagId,
      filterMode,
      noSubcategories
    });
  },

  @discourseComputed("category")
  showTagFilter() {
    return Discourse.SiteSettings.show_filter_by_tag;
  },

  @discourseComputed("additionalTags", "canAdminTag", "category")
  showAdminControls(additionalTags, canAdminTag, category) {
    return !additionalTags && canAdminTag && !category;
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

      this.send("invalidateModel");
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

    deleteTag() {
      const numTopics =
        this.get("list.topic_list.tags.firstObject.topic_count") || 0;

      const confirmText =
        numTopics === 0
          ? I18n.t("tagging.delete_confirm_no_topics")
          : I18n.t("tagging.delete_confirm", { count: numTopics });

      bootbox.confirm(confirmText, result => {
        if (!result) return;

        this.tag
          .destroyRecord()
          .then(() => this.transitionToRoute("tags.index"))
          .catch(() => bootbox.alert(I18n.t("generic_error")));
      });
    },

    changeTagNotification(id) {
      const tagNotification = this.tagNotification;
      tagNotification.update({ notification_level: id });
    }
  }
});
