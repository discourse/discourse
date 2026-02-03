import { cached } from "@glimmer/tracking";
import EmberObject, { computed, get } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { alias, sort } from "@ember/object/computed";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { removeValueFromArray } from "discourse/lib/array-tools";
import discourseComputed from "discourse/lib/decorators";
import deprecated, { withSilencedDeprecations } from "discourse/lib/deprecated";
import { isRailsTesting, isTesting } from "discourse/lib/environment";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import Mobile from "discourse/lib/mobile";
import PreloadStore from "discourse/lib/preload-store";
import singleton from "discourse/lib/singleton";
import { trackedArray } from "discourse/lib/tracked-tools";
import Archetype from "discourse/models/archetype";
import Category from "discourse/models/category";
import PostActionType from "discourse/models/post-action-type";
import RestModel from "discourse/models/rest";
import TrustLevel from "discourse/models/trust-level";

@singleton
export default class Site extends RestModel {
  static createCurrent() {
    const store = getOwnerWithFallback(this).lookup("service:store");
    const siteAttributes = PreloadStore.get("site");
    siteAttributes["isReadOnly"] = PreloadStore.get("isReadOnly");
    siteAttributes["isStaffWritesOnly"] = PreloadStore.get("isStaffWritesOnly");
    return store.createRecord("site", siteAttributes);
  }

  static create() {
    const result = super.create.apply(this, arguments);

    if (result.categories) {
      result.categories = result.categories.map((c) => {
        return result.store.createRecord("category", c);
      });
    }

    if (result.trust_levels) {
      result.trustLevels = Object.entries(result.trust_levels).map(
        ([key, id]) => {
          return new TrustLevel(id, key);
        }
      );
      delete result.trust_levels;
    }

    if (result.post_action_types) {
      result.postActionByIdLookup = EmberObject.create();
      result.post_action_types = result.post_action_types.map((p) => {
        const actionType = PostActionType.create(p);
        result.postActionByIdLookup.set("action" + p.id, actionType);
        return actionType;
      });
    }

    if (result.topic_flag_types) {
      result.topicFlagByIdLookup = EmberObject.create();
      result.topic_flag_types = result.topic_flag_types.map((p) => {
        const actionType = PostActionType.create(p);
        result.topicFlagByIdLookup.set("action" + p.id, actionType);
        return actionType;
      });
    }

    if (result.archetypes) {
      result.archetypes = result.archetypes.map((a) => {
        a.site = result;
        return Archetype.create(a);
      });
    }

    if (result.user_fields) {
      result.user_fields = result.user_fields.map((uf) =>
        EmberObject.create(uf)
      );
    }

    return result;
  }

  @service siteSettings;
  @service capabilities;

  @trackedArray categories = [];
  @trackedArray groups = [];

  @alias("is_readonly") isReadOnly;

  @sort("categories", "topicCountDesc") categoriesByCount;

  #siteInitialized = false;

  init() {
    super.init(...arguments);

    this.topicCountDesc = ["topic_count:desc"];
  }

  @dependentKeyCompat
  get desktopView() {
    return !this.mobileView;
  }

  @dependentKeyCompat
  get mobileView() {
    this.#siteInitialized ||= getOwnerWithFallback(this).lookup(
      "-application-instance:main"
    )?._booted;

    if (!this.#siteInitialized) {
      if (isTesting() || isRailsTesting()) {
        throw new Error(
          "Accessing `site.mobileView` or `site.desktopView` during the site initialization phase. " +
            "Move these checks to a component, transformer, or API callback that executes during page rendering."
        );
      }

      deprecated(
        "Accessing `site.mobileView` or `site.desktopView` during the site initialization " +
          "can lead to errors and inconsistencies when the browser window is " +
          "resized. Please move these checks to a component, transformer, or API callback that executes during page" +
          " rendering.",
        {
          since: "3.5.0.beta9-dev",
          id: "discourse.static-viewport-initialization",
          url: "https://meta.discourse.org/t/367810",
        }
      );
    }

    if (Mobile.mobileForced) {
      return true;
    }

    if (this.siteSettings.viewport_based_mobile_mode) {
      return withSilencedDeprecations(
        "discourse.static-viewport-initialization",
        () => !this.capabilities.viewport.sm
      );
    } else {
      return Mobile.mobileView;
    }
  }

  @dependentKeyCompat
  get isMobileDevice() {
    deprecated(
      "Site.isMobileDevice is deprecated. Use `site.mobileView` and `site.desktopView` instead for " +
        "viewport-based values or `capabilities.isMobileDevice` for user-agent based detection.",
      {
        id: "discourse.site.is-mobile-device",
        since: "3.5.0.beta9-dev",
        url: "https://meta.discourse.org/t/367810",
      }
    );

    return this.mobileView;
  }

  @dependentKeyCompat
  get categoriesById() {
    return new Map(this.categories.map((c) => [c.id, c]));
  }

  @computed("categories.@each.parent_category_id")
  get categoriesByParentId() {
    const map = new Map();
    for (const category of this.categories) {
      const siblings = map.get(category.parent_category_id) || [];
      siblings.push(category);
      map.set(category.parent_category_id, siblings);
    }
    return map;
  }

  @discourseComputed("notification_types")
  notificationLookup(notificationTypes) {
    const result = [];
    Object.keys(notificationTypes).forEach(
      (k) => (result[notificationTypes[k]] = k)
    );
    return result;
  }

  @discourseComputed("post_action_types.[]")
  flagTypes() {
    const postActionTypes = this.post_action_types;
    if (!postActionTypes) {
      return [];
    }
    return new TrackedArray(postActionTypes.filter((type) => type.is_flag));
  }

  collectUserFields(fields) {
    fields = fields || {};

    let siteFields = this.user_fields;

    if (!isEmpty(siteFields)) {
      return siteFields.map((f) => {
        let value = fields ? fields[f.id.toString()] : null;
        value = value || htmlSafe("&mdash;");
        return { name: f.name, value };
      });
    }
    return [];
  }

  // Sort subcategories under parents
  @cached
  get sortedCategories() {
    return Category.sortCategories(this.categoriesByCount);
  }

  // Returns it in the correct order, by setting
  @discourseComputed("categories.[]")
  categoriesList(categories) {
    return this.siteSettings.fixed_category_positions
      ? categories
      : this.sortedCategories;
  }

  @discourseComputed("categories.[]", "categories.@each.notification_level")
  trackedCategoriesList(categories) {
    const trackedCategories = [];

    for (const category of categories) {
      if (category.isTracked) {
        if (
          this.siteSettings.allow_uncategorized_topics ||
          !category.isUncategorizedCategory
        ) {
          trackedCategories.push(category);
        }
      }
    }

    return trackedCategories;
  }

  postActionTypeById(id) {
    return this.get("postActionByIdLookup.action" + id);
  }

  topicFlagTypeById(id) {
    return this.get("topicFlagByIdLookup.action" + id);
  }

  #transformTags(tags) {
    if (!tags) {
      return [];
    }
    return tags.map((tag) => this.store.createRecord("tag", tag));
  }

  get topTags() {
    return this.#transformTags(this.top_tags);
  }

  get categoryTopTags() {
    return this.#transformTags(this.category_top_tags);
  }

  removeCategory(id) {
    const categories = this.categories;
    const existingCategory = categories.find((c) => c.id === id);
    if (existingCategory) {
      removeValueFromArray(categories, existingCategory);
    }
  }

  updateCategory(newCategory) {
    if (newCategory instanceof Category) {
      throw new Error(
        "updateCategory should be passed a pojo, not a category model instance"
      );
    }

    const categories = this.categories;
    const categoryId = get(newCategory, "id");
    const existingCategory = categories.find((c) => c.id === categoryId);

    // Don't update null permissions
    if (newCategory.permission === null) {
      delete newCategory.permission;
    }

    if (existingCategory) {
      existingCategory.setProperties(newCategory);
      return existingCategory;
    } else {
      // TODO insert in right order?
      newCategory = this.store.createRecord("category", newCategory);
      categories.push(newCategory);
      return newCategory;
    }
  }
}

if (typeof Discourse !== "undefined") {
  let warned = false;
  // eslint-disable-next-line no-undef
  Object.defineProperty(Discourse, "Site", {
    get() {
      if (!warned) {
        deprecated("Import the Site class instead of using Discourse.Site", {
          since: "2.4.0",
          id: "discourse.globals.site",
        });
        warned = true;
      }
      return Site;
    },
  });
}
