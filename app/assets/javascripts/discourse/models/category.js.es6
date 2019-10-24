import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";
import computed from "ember-addons/ember-computed-decorators";
import { on } from "ember-addons/ember-computed-decorators";
import PermissionType from "discourse/models/permission-type";
import { NotificationLevels } from "discourse/lib/notification-levels";

const Category = RestModel.extend({
  permissions: null,

  @on("init")
  setupGroupsAndPermissions() {
    const availableGroups = this.available_groups;
    if (!availableGroups) {
      return;
    }
    this.set("availableGroups", availableGroups);

    const groupPermissions = this.group_permissions;
    if (groupPermissions) {
      this.set(
        "permissions",
        groupPermissions.map(elem => {
          availableGroups.removeObject(elem.group_name);
          return {
            group_name: elem.group_name,
            permission: PermissionType.create({ id: elem.permission_type })
          };
        })
      );
    }
  },

  @computed
  availablePermissions() {
    return [
      PermissionType.create({ id: PermissionType.FULL }),
      PermissionType.create({ id: PermissionType.CREATE_POST }),
      PermissionType.create({ id: PermissionType.READONLY })
    ];
  },

  @computed("id")
  searchContext(id) {
    return { type: "category", id, category: this };
  },

  @computed("notification_level")
  isMuted(notificationLevel) {
    return notificationLevel === NotificationLevels.MUTED;
  },

  @computed("name")
  url() {
    return Discourse.getURL("/c/") + Category.slugFor(this);
  },

  @computed
  fullSlug() {
    return Category.slugFor(this).replace(/\//g, "-");
  },

  @computed("name")
  nameLower(name) {
    return name.toLowerCase();
  },

  @computed("url")
  unreadUrl(url) {
    return `${url}/l/unread`;
  },

  @computed("url")
  newUrl(url) {
    return `${url}/l/new`;
  },

  @computed("color", "text_color")
  style(color, textColor) {
    return `background-color: #${color}; color: #${textColor}`;
  },

  @computed("topic_count")
  moreTopics(topicCount) {
    return topicCount > (this.num_featured_topics || 2);
  },

  @computed("topic_count", "subcategories")
  totalTopicCount(topicCount, subcats) {
    let count = topicCount;
    if (subcats) {
      subcats.forEach(s => {
        count += s.get("topic_count");
      });
    }
    return count;
  },

  save() {
    const id = this.id;
    const url = id ? `/categories/${id}` : "/categories";

    return ajax(url, {
      data: {
        name: this.name,
        slug: this.slug,
        color: this.color,
        text_color: this.text_color,
        secure: this.secure,
        permissions: this._permissionsForUpdate(),
        auto_close_hours: this.auto_close_hours,
        auto_close_based_on_last_post: this.get(
          "auto_close_based_on_last_post"
        ),
        position: this.position,
        email_in: this.email_in,
        email_in_allow_strangers: this.email_in_allow_strangers,
        mailinglist_mirror: this.mailinglist_mirror,
        parent_category_id: this.parent_category_id,
        uploaded_logo_id: this.get("uploaded_logo.id"),
        uploaded_background_id: this.get("uploaded_background.id"),
        allow_badges: this.allow_badges,
        custom_fields: this.custom_fields,
        topic_template: this.topic_template,
        suppress_from_latest: this.suppress_from_latest,
        all_topics_wiki: this.all_topics_wiki,
        allowed_tags: this.allowed_tags,
        allowed_tag_groups: this.allowed_tag_groups,
        allow_global_tags: this.allow_global_tags,
        sort_order: this.sort_order,
        sort_ascending: this.sort_ascending,
        topic_featured_link_allowed: this.topic_featured_link_allowed,
        show_subcategory_list: this.show_subcategory_list,
        num_featured_topics: this.num_featured_topics,
        default_view: this.default_view,
        subcategory_list_style: this.subcategory_list_style,
        default_top_period: this.default_top_period,
        minimum_required_tags: this.minimum_required_tags,
        navigate_to_first_post_after_read: this.get(
          "navigate_to_first_post_after_read"
        ),
        search_priority: this.search_priority,
        reviewable_by_group_name: this.reviewable_by_group_name
      },
      type: id ? "PUT" : "POST"
    });
  },

  _permissionsForUpdate() {
    const permissions = this.permissions;
    let rval = {};
    permissions.forEach(p => (rval[p.group_name] = p.permission.id));
    return rval;
  },

  destroy() {
    return ajax(`/categories/${this.id || this.slug}`, {
      type: "DELETE"
    });
  },

  addPermission(permission) {
    this.permissions.addObject(permission);
    this.availableGroups.removeObject(permission.group_name);
  },

  removePermission(permission) {
    this.permissions.removeObject(permission);
    this.availableGroups.addObject(permission.group_name);
  },

  @computed("topics")
  latestTopic(topics) {
    if (topics && topics.length) {
      return topics[0];
    }
  },

  @computed("topics")
  featuredTopics(topics) {
    if (topics && topics.length) {
      return topics.slice(0, this.num_featured_topics || 2);
    }
  },

  @computed("id", "topicTrackingState.messageCount")
  unreadTopics(id) {
    return this.topicTrackingState.countUnread(id);
  },

  @computed("id", "topicTrackingState.messageCount")
  newTopics(id) {
    return this.topicTrackingState.countNew(id);
  },

  setNotification(notification_level) {
    this.set("notification_level", notification_level);
    const url = `/category/${this.id}/notifications`;
    return ajax(url, { data: { notification_level }, type: "POST" });
  },

  @computed("id")
  isUncategorizedCategory(id) {
    return id === Discourse.Site.currentProp("uncategorized_category_id");
  }
});

var _uncategorized;

Category.reopenClass({
  findUncategorized() {
    _uncategorized =
      _uncategorized ||
      Category.list().findBy(
        "id",
        Discourse.Site.currentProp("uncategorized_category_id")
      );
    return _uncategorized;
  },

  slugFor(category, separator = "/") {
    if (!category) return "";

    const parentCategory = Ember.get(category, "parentCategory");
    let result = "";

    if (parentCategory) {
      result = Category.slugFor(parentCategory) + separator;
    }

    const id = Ember.get(category, "id"),
      slug = Ember.get(category, "slug");

    return !slug || slug.trim().length === 0
      ? `${result}${id}-category`
      : result + slug;
  },

  list() {
    return Discourse.Site.currentProp("categoriesList");
  },

  listByActivity() {
    return Discourse.Site.currentProp("sortedCategories");
  },

  idMap() {
    return Discourse.Site.currentProp("categoriesById");
  },

  findSingleBySlug(slug) {
    if (Discourse.SiteSettings.slug_generation_method !== "encoded") {
      return Category.list().find(c => Category.slugFor(c) === slug);
    } else {
      return Category.list().find(c => Category.slugFor(c) === encodeURI(slug));
    }
  },

  findById(id) {
    if (!id) {
      return;
    }
    return Category.idMap()[id];
  },

  findByIds(ids = []) {
    const categories = [];
    ids.forEach(id => {
      const found = Category.findById(id);
      if (found) {
        categories.push(found);
      }
    });
    return categories;
  },

  findBySlug(slug, parentSlug) {
    const categories = Category.list();
    let category;

    if (parentSlug) {
      const parentCategory = Category.findSingleBySlug(parentSlug);
      if (parentCategory) {
        if (slug === "none") {
          return parentCategory;
        }

        category = categories.find(item => {
          return (
            item &&
            item.get("parentCategory") === parentCategory &&
            ((Discourse.SiteSettings.slug_generation_method !== "encoded" &&
              Category.slugFor(item) === parentSlug + "/" + slug) ||
              (Discourse.SiteSettings.slug_generation_method === "encoded" &&
                Category.slugFor(item) ===
                  encodeURI(parentSlug) + "/" + encodeURI(slug)))
          );
        });
      }
    } else {
      category = Category.findSingleBySlug(slug);

      // If we have a parent category, we need to enforce it
      if (category && category.get("parentCategory")) return;
    }

    // In case the slug didn't work, try to find it by id instead.
    if (!category) {
      category = categories.findBy("id", parseInt(slug, 10));
    }

    return category;
  },

  reloadById(id) {
    return ajax(`/c/${id}/show.json`);
  },

  reloadBySlug(slug, parentSlug) {
    return parentSlug
      ? ajax(`/c/${parentSlug}/${slug}/find_by_slug.json`)
      : ajax(`/c/${slug}/find_by_slug.json`);
  },

  search(term, opts) {
    var limit = 5;

    if (opts) {
      if (opts.limit === 0) {
        return [];
      } else if (opts.limit) {
        limit = opts.limit;
      }
    }

    const emptyTerm = term === "";
    let slugTerm = term;

    if (!emptyTerm) {
      term = term.toLowerCase();
      slugTerm = term;
      term = term.replace(/-/g, " ");
    }

    const categories = Category.listByActivity();
    const length = categories.length;
    var i;
    var data = [];

    const done = () => {
      return data.length === limit;
    };

    for (i = 0; i < length && !done(); i++) {
      const category = categories[i];
      if (
        (emptyTerm && !category.get("parent_category_id")) ||
        (!emptyTerm &&
          (category
            .get("name")
            .toLowerCase()
            .indexOf(term) === 0 ||
            category
              .get("slug")
              .toLowerCase()
              .indexOf(slugTerm) === 0))
      ) {
        data.push(category);
      }
    }

    if (!done()) {
      for (i = 0; i < length && !done(); i++) {
        const category = categories[i];

        if (
          !emptyTerm &&
          (category
            .get("name")
            .toLowerCase()
            .indexOf(term) > 0 ||
            category
              .get("slug")
              .toLowerCase()
              .indexOf(slugTerm) > 0)
        ) {
          if (data.indexOf(category) === -1) data.push(category);
        }
      }
    }

    return _.sortBy(data, category => {
      return category.get("read_restricted");
    });
  }
});

export default Category;
