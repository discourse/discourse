import Controller from "@ember/controller";
import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";
import BulkTopicSelection from "discourse/mixins/bulk-topic-selection";
import {
  default as NavItem,
  extraNavItemProperties,
  customNavItemHref
} from "discourse/models/nav-item";

if (extraNavItemProperties) {
  extraNavItemProperties(function(text, opts) {
    if (opts && opts.tagId) {
      return { tagId: opts.tagId };
    } else {
      return {};
    }
  });
}

if (customNavItemHref) {
  customNavItemHref(function(navItem) {
    if (navItem.get("tagId")) {
      const name = navItem.get("name");

      if (!Discourse.Site.currentProp("filters").includes(name)) {
        return null;
      }

      let path = "/tags/";
      const category = navItem.get("category");

      if (category) {
        path += "c/";
        path += Discourse.Category.slugFor(category);
        if (navItem.get("noSubcategories")) {
          path += "/none";
        }
        path += "/";
      }

      path += `${navItem.get("tagId")}/l/`;
      return `${path}${name.replace(" ", "-")}`;
    } else {
      return null;
    }
  });
}

export default Controller.extend(BulkTopicSelection, {
  application: Ember.inject.controller(),

  tag: null,
  additionalTags: null,
  list: null,
  canAdminTag: Ember.computed.alias("currentUser.staff"),
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

  categories: Ember.computed.alias("site.categoriesList"),

  @computed("list", "list.draft")
  createTopicLabel(list, listDraft) {
    return listDraft ? "topic.open_draft" : "topic.create";
  },

  @computed(
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

  @computed("category", "tag.id", "filterMode")
  navItems(category, tagId, filterMode) {
    return NavItem.buildList(category, {
      tagId,
      filterMode
    });
  },

  @computed("category")
  showTagFilter() {
    return Discourse.SiteSettings.show_filter_by_tag;
  },

  @computed("additionalTags", "canAdminTag", "category")
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

  @computed("navMode", "list.topics.length", "loading")
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
