import { warn } from "@ember/debug";
import { computed, get } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse/lib/decorators";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import getURL from "discourse/lib/get-url";
import { MultiCache } from "discourse/lib/multi-cache";
import { NotificationLevels } from "discourse/lib/notification-levels";
import { applyValueTransformer } from "discourse/lib/transformer";
import PermissionType from "discourse/models/permission-type";
import RestModel from "discourse/models/rest";
import Site from "discourse/models/site";
import Topic from "discourse/models/topic";

const STAFF_GROUP_NAME = "staff";
const CATEGORY_ASYNC_SEARCH_CACHE = {};
const CATEGORY_ASYNC_HIERARCHICAL_SEARCH_CACHE = {};

export default class Category extends RestModel {
  // Sort subcategories directly under parents
  static sortCategories(categories) {
    const children = new Map();

    categories.forEach((category) => {
      const parentId = parseInt(category.parent_category_id, 10) || -1;
      const group = children.get(parentId) || [];
      group.pushObject(category);

      children.set(parentId, group);
    });

    const reduce = (values) =>
      values.flatMap((c) => [c, reduce(children.get(c.id) || [])]).flat();

    return reduce(children.get(-1) || []);
  }

  static isUncategorized(categoryId) {
    return categoryId === Site.currentProp("uncategorized_category_id");
  }

  static slugEncoded() {
    let siteSettings = getOwnerWithFallback(this).lookup(
      "service:site-settings"
    );
    return siteSettings.slug_generation_method === "encoded";
  }

  static findUncategorized() {
    _uncategorized =
      _uncategorized ||
      Category.list().findBy(
        "id",
        Site.currentProp("uncategorized_category_id")
      );
    return _uncategorized;
  }

  static slugFor(category, separator = "/", depth = 3) {
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
  }

  static list() {
    return Site.currentProp("categoriesList");
  }

  static listByActivity() {
    return Site.currentProp("sortedCategories");
  }

  static _idMap() {
    return Site.currentProp("categoriesById");
  }

  static findSingleBySlug(slug) {
    if (!this.slugEncoded()) {
      return Category.list().find((c) => Category.slugFor(c) === slug);
    } else {
      return Category.list().find(
        (c) => Category.slugFor(c) === encodeURI(slug)
      );
    }
  }

  static findById(id) {
    if (!id) {
      return;
    }

    if (typeof id === "string") {
      // eslint-disable-next-line no-console
      console.warn("Category.findById called with a string ID");
      id = parseInt(id, 10);
    }

    return Category._idMap().get(id);
  }

  static findByIds(ids = []) {
    const categories = [];
    ids.forEach((id) => {
      const found = Category.findById(id);
      if (found) {
        categories.push(found);
      }
    });
    return categories;
  }

  static hasAsyncFoundAll(ids) {
    const loadedCategoryIds = Site.current().loadedCategoryIds || new Set();
    return ids.every((id) => loadedCategoryIds.has(id));
  }

  static async asyncFindByIds(ids = []) {
    ids = ids.map((x) => parseInt(x, 10));

    if (!Site.current().lazy_load_categories || this.hasAsyncFoundAll(ids)) {
      return this.findByIds(ids);
    }

    const result = await categoryMultiCache.fetch(ids);
    if (categoryMultiCache.hadTooManyCalls()) {
      warn(
        "Multiple calls to Category.asyncFindByIds within a second. Could they be combined?",
        {
          id: "discourse.category.multiple-async-find-by-ids-calls",
        }
      );
    }

    const categories = ids.map((id) =>
      Site.current().updateCategory(result.get(id))
    );

    // Update loadedCategoryIds list
    const loadedCategoryIds = Site.current().loadedCategoryIds || new Set();
    ids.forEach((id) => loadedCategoryIds.add(id));
    Site.current().set("loadedCategoryIds", loadedCategoryIds);

    return categories;
  }

  static async asyncFindById(id) {
    return (await Category.asyncFindByIds([id]))[0];
  }

  static findBySlugAndParent(slug, parentCategory) {
    if (this.slugEncoded()) {
      slug = encodeURI(slug);
    }
    return Category.list().find((category) => {
      return (
        category.slug === slug &&
        (category.parentCategory || null) === parentCategory
      );
    });
  }

  static findBySlugPath(slugPath) {
    let category = null;

    for (const slug of slugPath) {
      category = this.findBySlugAndParent(slug, category);

      if (!category) {
        return null;
      }
    }

    return category;
  }

  static async asyncFindBySlugPath(slugPath, opts = {}) {
    const data = { slug_path: slugPath };
    if (opts.includePermissions) {
      data.include_permissions = true;
    }

    const result = await ajax("/categories/find", { data });

    const categories = result["categories"].map((category) => {
      category = Site.current().updateCategory(category);
      if (opts.includePermissions) {
        category.setupGroupsAndPermissions();
      }
      return category;
    });

    return categories[categories.length - 1];
  }

  static async asyncFindBySlugPathWithID(slugPathWithID) {
    const result = await ajax("/categories/find", {
      data: { slug_path_with_id: slugPathWithID },
    });

    const categories = result["categories"].map((category) =>
      Site.current().updateCategory(category)
    );

    return categories[categories.length - 1];
  }

  static findBySlugPathWithID(slugPathWithID) {
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
  }

  static findBySlug(slug, parentSlug) {
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
  }

  static fetchVisibleGroups(id) {
    return ajax(`/c/${id}/visible_groups.json`);
  }

  static reloadById(id) {
    return ajax(`/c/${id}/show.json`);
  }

  static reloadBySlugPath(slugPath) {
    return ajax(`/c/${slugPath}/find_by_slug.json`);
  }

  static reloadCategoryWithPermissions(params, store, site) {
    return this.reloadBySlugPath(params.slug).then((result) =>
      this._includePermissions(result.category, store, site)
    );
  }

  static _includePermissions(category, store, site) {
    const record = store.createRecord("category", category);
    record.setupGroupsAndPermissions();
    site.updateCategory(record);
    return record;
  }

  static search(term, opts) {
    let limit = 5;
    let parentCategoryId;

    if (opts) {
      if (opts.limit === 0) {
        return [];
      } else if (opts.limit) {
        limit = opts.limit;
      }
      if (opts.parentCategoryId) {
        parentCategoryId = opts.parentCategoryId;
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

    const validCategoryParent = (category) => {
      return (
        !parentCategoryId ||
        category.get("parent_category_id") === parentCategoryId
      );
    };

    for (i = 0; i < length && !done(); i++) {
      const category = categories[i];
      if (
        ((emptyTerm && !category.get("parent_category_id")) ||
          (!emptyTerm &&
            (category.get("name").toLowerCase().startsWith(term) ||
              category.get("slug").toLowerCase().startsWith(slugTerm)))) &&
        validCategoryParent(category)
      ) {
        data.push(category);
      }
    }

    if (!done()) {
      for (i = 0; i < length && !done(); i++) {
        const category = categories[i];

        if (
          ((!emptyTerm &&
            category.get("name").toLowerCase().indexOf(term) > 0) ||
            category.get("slug").toLowerCase().indexOf(slugTerm) > 0) &&
          validCategoryParent(category)
        ) {
          if (!data.includes(category)) {
            data.push(category);
          }
        }
      }
    }

    return data.sortBy("read_restricted");
  }

  static async asyncHierarchicalSearch(term, opts) {
    opts ||= {};

    const data = {
      term,
      parent_category_id: opts.parentCategoryId,
      limit: opts.limit,
      only: opts.only,
      except: opts.except,
      page: opts.page,
      offset: opts.offset,
      include_uncategorized: opts.includeUncategorized,
    };

    const result = (CATEGORY_ASYNC_HIERARCHICAL_SEARCH_CACHE[
      JSON.stringify(data)
    ] ||= await ajax("/categories/hierarchical_search", {
      method: "GET",
      data,
    }));

    return result["categories"].map((category) =>
      Site.current().updateCategory(category)
    );
  }

  static async asyncSearch(term, opts) {
    opts ||= {};

    const data = {
      term,
      parent_category_id: opts.parentCategoryId,
      include_uncategorized: opts.includeUncategorized,
      select_category_ids: opts.selectCategoryIds,
      reject_category_ids: opts.rejectCategoryIds,
      include_subcategories: opts.includeSubcategories,
      include_ancestors: opts.includeAncestors,
      prioritized_category_id: opts.prioritizedCategoryId,
      limit: opts.limit,
      page: opts.page,
    };

    const result = (CATEGORY_ASYNC_SEARCH_CACHE[JSON.stringify(data)] ||=
      await ajax("/categories/search", { method: "POST", data }));

    if (opts.includeAncestors) {
      return {
        ancestors: result["ancestors"].map((category) =>
          Site.current().updateCategory(category)
        ),
        categories: result["categories"].map((category) =>
          Site.current().updateCategory(category)
        ),
        categoriesCount: result["categories_count"],
      };
    } else {
      return result["categories"].map((category) =>
        Site.current().updateCategory(category)
      );
    }
  }

  @service currentUser;

  permissions = null;

  init() {
    super.init(...arguments);
    this.setupGroupsAndPermissions();
  }

  setupGroupsAndPermissions() {
    if (!this.available_groups) {
      return;
    }

    this.set("availableGroups", this.available_groups);

    if (this.group_permissions) {
      this.set(
        "permissions",
        this.group_permissions.map((elem) => {
          this.available_groups.removeObject(elem.group_name);
          return elem;
        })
      );
    }
  }

  get descriptionText() {
    return applyValueTransformer(
      "category-description-text",
      this.get("description_text"),
      {
        category: this,
      }
    );
  }

  get displayName() {
    return applyValueTransformer("category-display-name", this.get("name"), {
      category: this,
    });
  }

  @computed("parent_category_id", "site.categories.[]")
  get parentCategory() {
    if (this.parent_category_id) {
      return Category.findById(this.parent_category_id);
    }
  }

  set parentCategory(newParentCategory) {
    this.set("parent_category_id", newParentCategory?.id);
  }

  @computed("site.categories.[]")
  get subcategories() {
    return this.site.categories.filterBy("parent_category_id", this.id);
  }

  @computed("subcategories")
  get unloadedSubcategoryCount() {
    return this.subcategory_count - this.subcategories.length;
  }

  @computed("subcategory_list")
  get serializedSubcategories() {
    return this.subcategory_list?.map((c) => Category.create(c));
  }

  @discourseComputed("required_tag_groups", "minimum_required_tags")
  minimumRequiredTags() {
    if (this.required_tag_groups?.length > 0) {
      // it should require the max between the bare minimum set in the category and the sum of the min_count of the
      // required_tag_groups
      return Math.max(
        this.required_tag_groups.reduce((sum, rtg) => sum + rtg.min_count, 0),
        this.minimum_required_tags || 0
      );
    } else {
      return this.minimum_required_tags > 0 ? this.minimum_required_tags : null;
    }
  }

  @discourseComputed
  availablePermissions() {
    return [
      PermissionType.create({ id: PermissionType.FULL }),
      PermissionType.create({ id: PermissionType.CREATE_POST }),
      PermissionType.create({ id: PermissionType.READONLY }),
    ];
  }

  @discourseComputed("id")
  searchContext(id) {
    return { type: "category", id, category: this };
  }

  @discourseComputed("parentCategory.ancestors")
  ancestors(parentAncestors) {
    return [...(parentAncestors || []), this];
  }

  @discourseComputed("parentCategory", "parentCategory.predecessors")
  predecessors(parentCategory, parentPredecessors) {
    if (parentCategory) {
      return [parentCategory, ...parentPredecessors];
    } else {
      return [];
    }
  }

  @discourseComputed("subcategories")
  descendants() {
    const descendants = [this];
    for (let i = 0; i < descendants.length; i++) {
      if (descendants[i].subcategories) {
        descendants.push(...descendants[i].subcategories);
      }
    }
    return descendants;
  }

  @discourseComputed("parentCategory.level")
  level(parentLevel) {
    if (!parentLevel) {
      return parentLevel === 0 ? 1 : 0;
    } else {
      return parentLevel + 1;
    }
  }

  @discourseComputed("has_children", "subcategories")
  isParent(hasChildren, subcategories) {
    return hasChildren || (subcategories && subcategories.length > 0);
  }

  @discourseComputed("subcategories")
  isGrandParent(subcategories) {
    return (
      subcategories &&
      subcategories.some(
        (cat) => cat.subcategories && cat.subcategories.length > 0
      )
    );
  }

  @discourseComputed("notification_level")
  isMuted(notificationLevel) {
    return notificationLevel === NotificationLevels.MUTED;
  }

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
  }

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
  }

  @discourseComputed("notification_level")
  notificationLevelString(notificationLevel) {
    // Get the key from the value
    const notificationLevelString = Object.keys(NotificationLevels).find(
      (key) => NotificationLevels[key] === notificationLevel
    );
    if (notificationLevelString) {
      return notificationLevelString.toLowerCase();
    }
  }

  @discourseComputed("name")
  path() {
    return `/c/${Category.slugFor(this)}/${this.id}`;
  }

  @discourseComputed("path")
  url(path) {
    return getURL(path);
  }

  @discourseComputed
  fullSlug() {
    return Category.slugFor(this).replace(/\//g, "-");
  }

  @discourseComputed("name")
  nameLower(name) {
    return name.toLowerCase();
  }

  @discourseComputed("url")
  unreadUrl(url) {
    return `${url}/l/unread`;
  }

  @discourseComputed("url")
  newUrl(url) {
    return `${url}/l/new`;
  }

  @discourseComputed("color", "text_color")
  style(color, textColor) {
    return `background-color: #${color}; color: #${textColor}`;
  }

  @discourseComputed("topic_count")
  moreTopics(topicCount) {
    return topicCount > (this.num_featured_topics || 2);
  }

  @discourseComputed("topic_count", "subcategories.[]")
  totalTopicCount(topicCount, subcategories) {
    if (subcategories) {
      subcategories.forEach((subcategory) => {
        topicCount += subcategory.topic_count;
      });
    }
    return topicCount;
  }

  @discourseComputed("default_slow_mode_seconds")
  defaultSlowModeMinutes(seconds) {
    return seconds ? seconds / 60 : null;
  }

  @discourseComputed("notification_level")
  isTracked(notificationLevel) {
    return notificationLevel >= NotificationLevels.TRACKING;
  }

  get unreadTopicsCount() {
    return this.topicTrackingState.countUnread({ categoryId: this.id });
  }

  get newTopicsCount() {
    return this.topicTrackingState.countNew({ categoryId: this.id });
  }

  save() {
    const id = this.id;
    const url = id ? `/categories/${id}` : "/categories";

    return ajax(url, {
      contentType: "application/json",
      data: JSON.stringify({
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
        default_slow_mode_seconds: this.default_slow_mode_seconds,
        position: this.position,
        email_in: this.email_in,
        email_in_allow_strangers: this.email_in_allow_strangers,
        mailinglist_mirror: this.mailinglist_mirror,
        parent_category_id: this.parent_category_id,
        uploaded_logo_id: this.get("uploaded_logo.id"),
        uploaded_logo_dark_id: this.get("uploaded_logo_dark.id"),
        uploaded_background_id: this.get("uploaded_background.id"),
        uploaded_background_dark_id: this.get("uploaded_background_dark.id"),
        allow_badges: this.allow_badges,
        category_setting_attributes: this.category_setting,
        custom_fields: this.custom_fields,
        topic_template: this.topic_template,
        form_template_ids: this.form_template_ids,
        all_topics_wiki: this.all_topics_wiki,
        allow_unlimited_owner_edits_on_first_post:
          this.allow_unlimited_owner_edits_on_first_post,
        allowed_tags: this.allowed_tags,
        allowed_tag_groups: this.allowed_tag_groups,
        allow_global_tags: this.allow_global_tags,
        required_tag_groups: this.required_tag_groups,
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
        moderating_group_ids: this.moderating_group_ids,
        read_only_banner: this.read_only_banner,
        default_list_filter: this.default_list_filter,
      }),
      type: id ? "PUT" : "POST",
    });
  }

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
  }

  destroy() {
    return ajax(`/categories/${this.id || this.slug}`, {
      type: "DELETE",
    });
  }

  addPermission(permission) {
    this.permissions.addObject(permission);
    this.availableGroups.removeObject(permission.group_name);
  }

  removePermission(group_name) {
    const permission = this.permissions.findBy("group_name", group_name);
    if (permission) {
      this.permissions.removeObject(permission);
      this.availableGroups.addObject(group_name);
    }
  }

  updatePermission(group_name, type) {
    this.permissions.forEach((p, i) => {
      if (p.group_name === group_name) {
        this.set(`permissions.${i}.permission_type`, type);
      }
    });
  }

  @discourseComputed("topics")
  latestTopic(topics) {
    if (topics && topics.length) {
      return topics[0];
    }
  }

  @discourseComputed("topics")
  featuredTopics(topics) {
    if (topics && topics.length) {
      return topics
        .slice(0, this.num_featured_topics || 2)
        .map((t) => Topic.create(t));
    }
  }

  setNotification(notification_level) {
    this.currentUser.set(
      "muted_category_ids",
      this.currentUser.calculateMutedIds(
        notification_level,
        this.id,
        "muted_category_ids"
      )
    );

    const url = `/category/${this.id}/notifications`;
    return ajax(url, { data: { notification_level }, type: "POST" }).then(
      (data) => {
        this.currentUser.set(
          "indirectly_muted_category_ids",
          data.indirectly_muted_category_ids
        );
        this.set("notification_level", notification_level);
        this.notifyPropertyChange("notification_level");
      }
    );
  }

  @discourseComputed("id")
  isUncategorizedCategory(id) {
    return Category.isUncategorized(id);
  }

  get canCreateTopic() {
    return this.permission === PermissionType.FULL;
  }

  get subcategoryWithCreateTopicPermission() {
    return this.subcategories?.find(
      (subcategory) => subcategory.canCreateTopic
    );
  }
}

let _uncategorized;

const categoryMultiCache = new MultiCache(async (ids) => {
  const result = await ajax("/categories/find", { data: { ids } });

  return new Map(
    result["categories"].map((category) => [category.id, category])
  );
});

export function resetCategoryCache() {
  categoryMultiCache.reset();
}
