import { default as computed } from "ember-addons/ember-computed-decorators";
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
      var name = navItem.get("name");

      if (!Discourse.Site.currentProp("filters").includes(name)) {
        return null;
      }

      var path = "/tags/",
        category = navItem.get("category");

      if (category) {
        path += "c/";
        path += Discourse.Category.slugFor(category);
        if (navItem.get("noSubcategories")) {
          path += "/none";
        }
        path += "/";
      }

      path += navItem.get("tagId") + "/l/";
      return path + name.replace(" ", "-");
    } else {
      return null;
    }
  });
}

export default Ember.Controller.extend(BulkTopicSelection, {
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

  createTopicLabel: function() {
    return this.get("list.draft") ? "topic.open_draft" : "topic.create";
  }.property("list", "list.draft"),

  @computed("canCreateTopic", "category", "canCreateTopicOnCategory")
  createTopicDisabled(canCreateTopic, category, canCreateTopicOnCategory) {
    return !canCreateTopic || (category && !canCreateTopicOnCategory);
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

  navItems: function() {
    return NavItem.buildList(this.get("category"), {
      tagId: this.get("tag.id"),
      filterMode: this.get("filterMode")
    });
  }.property("category", "tag.id", "filterMode"),

  showTagFilter: function() {
    return Discourse.SiteSettings.show_filter_by_tag;
  }.property("category"),

  showAdminControls: function() {
    return (
      !this.get("additionalTags") &&
      this.get("canAdminTag") &&
      !this.get("category")
    );
  }.property("additionalTags", "canAdminTag", "category"),

  loadMoreTopics() {
    return this.get("list").loadMore();
  },

  _showFooter: function() {
    this.set("application.showFooter", !this.get("list.canLoadMore"));
  }.observes("list.canLoadMore"),

  footerMessage: function() {
    if (this.get("loading") || this.get("list.topics.length") !== 0) {
      return;
    }

    if (this.get("list.topics.length") === 0) {
      return I18n.t("tagging.topics.none." + this.get("navMode"), {
        tag: this.get("tag.id")
      });
    } else {
      return I18n.t("tagging.topics.bottom." + this.get("navMode"), {
        tag: this.get("tag.id")
      });
    }
  }.property("navMode", "list.topics.length", "loading"),

  actions: {
    changeSort(sortBy) {
      if (sortBy === this.get("order")) {
        this.toggleProperty("ascending");
      } else {
        this.setProperties({ order: sortBy, ascending: false });
      }
      this.send("invalidateModel");
    },

    refresh() {
      const self = this;
      // TODO: this probably doesn't work anymore
      return this.store
        .findFiltered("topicList", { filter: "tags/" + this.get("tag.id") })
        .then(function(list) {
          self.set("list", list);
          self.resetSelected();
        });
    },

    deleteTag() {
      const self = this;
      const numTopics =
        this.get("list.topic_list.tags.firstObject.topic_count") || 0;
      const confirmText =
        numTopics === 0
          ? I18n.t("tagging.delete_confirm_no_topics")
          : I18n.t("tagging.delete_confirm", { count: numTopics });
      bootbox.confirm(confirmText, function(result) {
        if (!result) {
          return;
        }

        self
          .get("tag")
          .destroyRecord()
          .then(function() {
            self.transitionToRoute("tags.index");
          })
          .catch(function() {
            bootbox.alert(I18n.t("generic_error"));
          });
      });
    },

    changeTagNotification(id) {
      const tagNotification = this.get("tagNotification");
      tagNotification.update({ notification_level: id });
    }
  }
});
