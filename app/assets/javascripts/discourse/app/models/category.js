import discourseComputed, { on } from "discourse-common/utils/decorators";
import { NotificationLevels } from "discourse/lib/notification-levels";
import PermissionType from "discourse/models/permission-type";
import RestModel from "discourse/models/rest";
import Site from "discourse/models/site";
import User from "discourse/models/user";
import { ajax } from "discourse/lib/ajax";
import { get } from "@ember/object";
import { getOwner } from "discourse-common/lib/get-owner";
import getURL from "discourse-common/lib/get-url";

const STAFF_GROUP_NAME = "staff";

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
        groupPermissions.map((elem) => {
          availableGroups.removeObject(elem.group_name);
          return elem;
        })
      );
    }
  },

  @on("init")
  setupRequiredTagGroups() {
    if (this.required_tag_group_name) {
      this.set("required_tag_groups", [this.required_tag_group_name]);
    }
  },

  @discourseComputed
  availablePermissions() {
    return [
      PermissionType.create({ id: PermissionType.FULL }),
      PermissionType.create({ id: PermissionType.CREATE_POST }),
      PermissionType.create({ id: PermissionType.READONLY }),
    ];
  },

  @discourseComputed("id")
  searchContext(id) {
    return { type: "category", id, category: this };
  },

  @discourseComputed("parentCategory.ancestors")
  ancestors(parentAncestors) {
    return [...(parentAncestors || []), this];
  },

  @discourseComputed("parentCategory.level")
  level(parentLevel) {
    return (parentLevel || -1) + 1;
  },

  @discourseComputed("subcategories")
  isParent(subcategories) {
    return subcategories && subcategories.length > 0;
  },

  @discourseComputed("subcategories")
  isGrandParent(subcategories) {
    return (
      subcategories &&
      subcategories.some(
        (cat) => cat.subcategories && cat.subcategories.length > 0
      )
    );
  },

  @discourseComputed("notification_level")
  isMuted(notificationLevel) {
    return notificationLevel === NotificationLevels.MUTED;
  },

  @discourseComputed("isMuted", "subcategories")
  isHidden(isMuted, subcategories) {
    if (!isMuted) {
      return false;
    } else if (!subcategories) {
      return true;
    }

    if (subcategories.some((cat) => !cat.isHidden)) {
      return false;
    }

    return true;
  },

  @discourseComputed("isMuted", "subcategories")
  hasMuted(isMuted, subcategories) {
    if (isMuted) {
      return true;
    } else if (!subcategories) {
      return false;
    }

    if (subcategories.some((cat) => cat.hasMuted)) {
      return true;
    }

    return false;
  },

  @discourseComputed("notification_level")
  notificationLevelString(notificationLevel) {
    // Get the key from the value
    const notificationLevelString = Object.keys(NotificationLevels).find(
      (key) => NotificationLevels[key] === notificationLevel
    );
    if (notificationLevelString) {
      return notificationLevelString.toLowerCase();
    }
  },

  @discourseComputed("name")
  path() {
    return `/c/${Category.slugFor(this)}/${this.id}`;
  },

  @discourseComputed("path")
  url(path) {
    return getURL(path);
  },

  @discourseComputed
  fullSlug() {
    return Category.slugFor(this).replace(/\//g, "-");
  },

  @discourseComputed("name")
  nameLower(name) {
    return name.toLowerCase();
  },

  @discourseComputed("url")
  unreadUrl(url) {
    return `${url}/l/unread`;
  },

  @discourseComputed("url")
  newUrl(url) {
    return `${url}/l/new`;
  },

  @discourseComputed("color", "text_color")
  style(color, textColor) {
    return `background-color: #${color}; color: #${textColor}`;
  },

  @discourseComputed("topic_count")
  moreTopics(topicCount) {
    return topicCount > (this.num_featured_topics || 2);
  },

  @discourseComputed("topic_count", "subcategories.[]")
  totalTopicCount(topicCount, subcategories) {
    if (subcategories) {
      subcategories.forEach((subcategory) => {
        topicCount += subcategory.topic_count;
      });
    }
    return topicCount;
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
        all_topics_wiki: this.all_topics_wiki,
        allow_unlimited_owner_edits_on_first_post: this
          .allow_unlimited_owner_edits_on_first_post,
        allowed_tags: this.allowed_tags,
        allowed_tag_groups: this.allowed_tag_groups,
        allow_global_tags: this.allow_global_tags,
        required_tag_group_name: this.required_tag_groups
          ? this.required_tag_groups[0]
          : null,
        min_tags_from_required_group: this.min_tags_from_required_group,
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
        reviewable_by_group_name: this.reviewable_by_group_name,
        read_only_banner: this.read_only_banner,
        default_list_filter: this.default_list_filter,
      },
      type: id ? "PUT" : "POST",
    });
  },

  _permissionsForUpdate() {
    const permissions = this.permissions;
    let rval = {};
    if (permissions.length) {
      permissions.forEach((p) => (rval[p.group_name] = p.permission_type));
    } else {
      // empty permissions => staff-only access
      rval[STAFF_GROUP_NAME] = PermissionType.FULL;
    }
    return rval;
  },

  destroy() {
    return ajax(`/categories/${this.id || this.slug}`, {
      type: "DELETE",
    });
  },

  addPermission(permission) {
    this.permissions.addObject(permission);
    this.availableGroups.removeObject(permission.group_name);
  },

  removePermission(group_name) {
    const permission = this.permissions.findBy("group_name", group_name);
    if (permission) {
      this.permissions.removeObject(permission);
      this.availableGroups.addObject(group_name);
    }
  },

  updatePermission(group_name, type) {
    this.permissions.forEach((p, i) => {
      if (p.group_name === group_name) {
        this.set(`permissions.${i}.permission_type`, type);
      }
    });
  },

  @discourseComputed("topics")
  latestTopic(topics) {
    if (topics && topics.length) {
      return topics[0];
    }
  },

  @discourseComputed("topics")
  featuredTopics(topics) {
    if (topics && topics.length) {
      return topics.slice(0, this.num_featured_topics || 2);
    }
  },

  @discourseComputed("id", "topicTrackingState.messageCount")
  unreadTopics(id) {
    return this.topicTrackingState.countUnread(id);
  },

  @discourseComputed("id", "topicTrackingState.messageCount")
  newTopics(id) {
    return this.topicTrackingState.countNew(id);
  },

  setNotification(notification_level) {
    this.set("notification_level", notification_level);

    User.currentProp(
      "muted_category_ids",
      User.current().calculateMutedIds(
        notification_level,
        this.id,
        "muted_category_ids"
      )
    );

    const url = `/category/${this.id}/notifications`;
    return ajax(url, { data: { notification_level }, type: "POST" });
  },

  @discourseComputed("id")
  isUncategorizedCategory(id) {
    return id === Site.currentProp("uncategorized_category_id");
  },
});

let _uncategorized;

Category.reopenClass({
  slugEncoded() {
    let siteSettings = getOwner(this).lookup("site-settings:main");
    return siteSettings.slug_generation_method === "encoded";
  },

  findUncategorized() {
    _uncategorized =
      _uncategorized ||
      Category.list().findBy(
        "id",
        Site.currentProp("uncategorized_category_id")
      );
    return _uncategorized;
  },

  slugFor(category, separator = "/", depth = 3) {
    if (!category) {
      return "";
    }

    const parentCategory = get(category, "parentCategory");
    let result = "";

    if (parentCategory && depth > 1) {
      result =
        Category.slugFor(parentCategory, separator, depth - 1) + separator;
    }

    const id = get(category, "id"),
      slug = get(category, "slug");

    return !slug || slug.trim().length === 0
      ? `${result}${id}-category`
      : result + slug;
  },

  list() {
    return Site.currentProp("categoriesList");
  },

  listByActivity() {
    return Site.currentProp("sortedCategories");
  },

  _idMap() {
    return Site.currentProp("categoriesById");
  },

  findSingleBySlug(slug) {
    if (!this.slugEncoded()) {
      return Category.list().find((c) => Category.slugFor(c) === slug);
    } else {
      return Category.list().find(
        (c) => Category.slugFor(c) === encodeURI(slug)
      );
    }
  },

  findById(id) {
    if (!id) {
      return;
    }
    return Category._idMap()[id];
  },

  findByIds(ids = []) {
    const categories = [];
    ids.forEach((id) => {
      const found = Category.findById(id);
      if (found) {
        categories.push(found);
      }
    });
    return categories;
  },

  findBySlugAndParent(slug, parentCategory) {
    if (this.slugEncoded()) {
      slug = encodeURI(slug);
    }
    return Category.list().find((category) => {
      return (
        category.slug === slug &&
        (category.parentCategory || null) === parentCategory
      );
    });
  },

  findBySlugPath(slugPath) {
    let category = null;

    for (const slug of slugPath) {
      category = this.findBySlugAndParent(slug, category);

      if (!category) {
        return null;
      }
    }

    return category;
  },

  findBySlugPathWithID(slugPathWithID) {
    let parts = slugPathWithID.split("/").filter(Boolean);
    // slugs found by star/glob pathing in ember do not automatically url decode - ensure that these are decoded
    if (this.slugEncoded()) {
      parts = parts.map((urlPart) => decodeURI(urlPart));
    }
    let category = null;

    if (parts.length > 0 && parts[parts.length - 1].match(/^\d+$/)) {
      const id = parseInt(parts.pop(), 10);

      category = Category.findById(id);
    } else {
      category = Category.findBySlugPath(parts);

      if (
        !category &&
        parts.length > 0 &&
        parts[parts.length - 1].match(/^\d+-category/)
      ) {
        const id = parseInt(parts.pop(), 10);

        category = Category.findById(id);
      }
    }

    return category;
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

        category = categories.find((item) => {
          return (
            item &&
            item.get("parentCategory") === parentCategory &&
            ((!this.slugEncoded() &&
              Category.slugFor(item) === parentSlug + "/" + slug) ||
              (this.slugEncoded() &&
                Category.slugFor(item) ===
                  encodeURI(parentSlug) + "/" + encodeURI(slug)))
          );
        });
      }
    } else {
      category = Category.findSingleBySlug(slug);

      // If we have a parent category, we need to enforce it
      if (category && category.get("parentCategory")) {
        return;
      }
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

  reloadBySlugPath(slugPath) {
    return ajax(`/c/${slugPath}/find_by_slug.json`);
  },

  reloadCategoryWithPermissions(params, store, site) {
    return this.reloadBySlugPath(params.slug).then((result) =>
      this._includePermissions(result.category, store, site)
    );
  },

  _includePermissions(category, store, site) {
    const record = store.createRecord("category", category);
    record.setupGroupsAndPermissions();
    site.updateCategory(record);
    return record;
  },

  search(term, opts) {
    let limit = 5;

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
    let i;
    let data = [];

    const done = () => {
      return data.length === limit;
    };

    for (i = 0; i < length && !done(); i++) {
      const category = categories[i];
      if (
        (emptyTerm && !category.get("parent_category_id")) ||
        (!emptyTerm &&
          (category.get("name").toLowerCase().indexOf(term) === 0 ||
            category.get("slug").toLowerCase().indexOf(slugTerm) === 0))
      ) {
        data.push(category);
      }
    }

    if (!done()) {
      for (i = 0; i < length && !done(); i++) {
        const category = categories[i];

        if (
          !emptyTerm &&
          (category.get("name").toLowerCase().indexOf(term) > 0 ||
            category.get("slug").toLowerCase().indexOf(slugTerm) > 0)
        ) {
          if (data.indexOf(category) === -1) {
            data.push(category);
          }
        }
      }
    }

    return data.sortBy("read_restricted");
  },
});

export default Category;
