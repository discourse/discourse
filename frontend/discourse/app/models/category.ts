import { tracked } from "@glimmer/tracking";
import { warn } from "@ember/debug";
import { computed, get } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { trackedObject } from "@ember/reactive/collections";
import { service } from "@ember/service";
import { compare } from "@ember/utils";
import { ajax } from "discourse/lib/ajax";
import {
  addUniqueValueToArray,
  removeValueFromArray,
} from "discourse/lib/array-tools";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import getURL from "discourse/lib/get-url";
import {
  extraSavePropertiesFor,
  registerModelSaveProperty,
} from "discourse/lib/model-extensions";
import { MultiCache } from "discourse/lib/multi-cache";
import { NotificationLevels } from "discourse/lib/notification-levels";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import { applyValueTransformer } from "discourse/lib/transformer";
import { removeAccents } from "discourse/lib/utilities";
import PermissionType from "discourse/models/permission-type";
import RestModel from "discourse/models/rest";
import Site from "discourse/models/site";
import type User from "discourse/models/user";
import type StoreService from "discourse/services/store";
import Topic from "./topic.ts";

/** Category badge styles. */
export type CategoryStyle = "square" | "icon" | "emoji";

/** Who requires review before posting in a category. */
export type CategoryPostingReviewMode =
  | "no_one"
  | "everyone"
  | "everyone_except"
  | "no_one_except";

/** A group permission on a category, as edited in its settings. */
export interface CategoryPermission {
  group_name: string;
  permission_type: number | null;
  group_id: number;
}

/** A tag allowed in the category. */
export interface CategoryAllowedTag {
  id: number | string;
  name: string;
  slug?: string;
}

/** A tag group requirement on a category. */
export interface CategoryRequiredTagGroup {
  min_count: number;
  name?: string | null;
}

/** An uploaded image, including the empty upload placeholder. */
export type CategoryUpload =
  | { id: number; url: string; width?: number | null; height?: number | null }
  | { id: null; url: null };

/** Optional category settings sent by the server. */
export interface CategorySetting {
  auto_bump_cooldown_days?: number | null;
  num_auto_bump_daily?: number | null;
  require_reply_approval?: boolean;
  require_topic_approval?: boolean;
  nested_replies_default?: boolean;
  topic_posting_review_mode?: CategoryPostingReviewMode;
  reply_posting_review_mode?: CategoryPostingReviewMode;
}

/** A translated category name and description. */
export interface CategoryLocalization {
  id: number;
  locale: string;
  name: string;
  description: string | null;
}

/** A localization being edited; entries added before saving have no id yet. */
export type CategoryEditableLocalization = Omit<CategoryLocalization, "id"> & {
  id?: number;
  category_id?: number;
};

/** Metadata published by a category type, including type-specific additions. */
export interface CategoryTypeMetadata {
  id: string;
  name: string;
  title: string;
  available: boolean;
  visible: boolean;
  description?: string;
  icon?: string | null;
  configuration_schema: Record<string, Record<string, unknown>[]>;
  [key: string]: unknown;
}

type CategorySearchOptions = {
  onlyPostable?: boolean;
  parentCategoryId?: number;
  includeUncategorized?: boolean;
  selectCategoryIds?: number[];
  rejectCategoryIds?: number[];
  /**
   * Leaves out subcategories the current user mutes only through a muted parent or grandparent.
   * A category muted directly stays.
   */
  rejectIndirectlyMuted?: boolean;
  includeSubcategories?: boolean;
  includeAncestors?: boolean;
  prioritizedCategoryId?: number;
  limit?: number;
  page?: number;
  /**
   * With a term, keeps each family's rows together, ranked by its best match, with the key
   * category first. The result's `familyKeys` then names each row's family.
   */
  groupFamilies?: boolean;
  /**
   * Without a term, lists each category right after its parent, with siblings by topic count
   * or by position.
   */
  treeOrder?: "topics" | "position";
};

/**
 * Each returned category's family: its own id when it has an eligible descendant, otherwise
 * its parent's id when the parent does, otherwise null.
 */
type CategoryFamilyKeys = Record<number, number | null>;

type CategorySearchResponse = {
  categories: CategoryFields[];
  ancestors: CategoryFields[];
  categories_count: number;
  family_keys?: CategoryFamilyKeys;
};

type CategorySearchResult = {
  ancestors: Category[];
  categories: Category[];
  categoriesCount: number;
};

/** A search answer; `familyKeys` is set only when `groupFamilies` took effect. */
type CategorySearchAnswer = CategorySearchResult & {
  familyKeys: CategoryFamilyKeys | undefined;
};

/**
 * Server payload fields and values assigned by core; plugins can augment this interface.
 * The required fields are missing only on a new category before its first `save()`.
 */
export interface CategoryFields {
  id: number;
  name: string;
  /** Null after the edit form clears it; empty when the generated slug was taken. */
  slug: string | null;
  color: string;
  text_color: string;
  style_type: CategoryStyle;
  icon: string | null;
  emoji: string | null;
  description?: string | null;
  description_text?: string | null;
  description_excerpt?: string | null;
  topic_url?: string | null;
  topic_count?: number;
  post_count?: number;
  position?: number | null;
  read_restricted: boolean;
  permission?: number | null;
  parent_category_id?: number | null;
  notification_level?: number | null;
  can_edit?: boolean;
  can_delete?: true;
  cannot_delete_reason?: string;
  is_special?: true;
  is_uncategorized?: true;
  topic_template?: string | null;
  topic_title_placeholder?: string | null;
  has_children?: boolean | null;
  subcategory_count?: number | null;
  subcategory_ids?: number[] | null;
  subcategory_list?: object[];
  subcategory_list_style?: string | null;
  sort_order?: string | null;
  sort_ascending?: boolean | null;
  show_subcategory_list?: boolean | null;
  num_featured_topics?: number | null;
  default_view?: string | null;
  default_top_period?: string | null;
  default_list_filter?: string | null;
  minimum_required_tags?: number | null;
  navigate_to_first_post_after_read?: boolean;
  custom_fields?: Record<string, unknown>;
  uploaded_logo?: CategoryUpload | null;
  uploaded_logo_dark?: CategoryUpload | null;
  uploaded_background?: CategoryUpload | null;
  uploaded_background_dark?: CategoryUpload | null;
  allow_global_tags?: boolean;
  read_only_banner?: string | null;
  form_template_ids?: number[];
  category_types?: Record<string, CategoryTypeMetadata>;
  locale?: string | null;
  available_groups?: string[];
  allowed_tags?: (CategoryAllowedTag | string)[];
  allowed_tag_groups?: string[];
  auto_close_hours?: number | null;
  auto_close_based_on_last_post?: boolean | null;
  group_permissions?: CategoryPermission[];
  email_in?: string | null;
  email_in_allow_strangers?: boolean | null;
  mailinglist_mirror?: boolean;
  all_topics_wiki?: boolean;
  allow_unlimited_owner_edits_on_first_post?: boolean;
  allow_badges?: boolean;
  topic_featured_link_allowed?: boolean | null;
  search_priority?: number | null;
  default_slow_mode_seconds?: number | null;
  moderating_group_ids?: number[];
  topic_posting_review_group_ids?: number[];
  reply_posting_review_group_ids?: number[];
  category_setting?: CategorySetting | null;
  category_localizations?: CategoryLocalization[];
  available_category_types?: CategoryTypeMetadata[];
  category_type_settings?: Record<string, unknown>;
  category_type_site_settings?: Record<string, unknown>;
  site_texts?: Record<string, string>;
  topics?: object[];
  topics_day?: number;
  topics_week?: number;
  topics_month?: number;
  topics_year?: number;
  topics_all_time?: number;
  pickAll?: boolean;
  stat?: string;
  statTitle?: string;
  statTotal?: string;
}

const CATEGORY_ASYNC_SEARCH_CACHE: Record<string, CategorySearchResponse> = {};
const CATEGORY_ASYNC_HIERARCHICAL_SEARCH_CACHE: Record<
  string,
  { categories: CategoryFields[] }
> = {};
const HTTP_NOT_FOUND = 404;

/** The entities the server's HTML escaping produces, and the characters they stand for. */
const ESCAPED_ENTITIES: Record<string, string> = {
  "&amp;": "&",
  "&lt;": "<",
  "&gt;": ">",
  "&quot;": '"',
  "&#39;": "'",
};

/** The server's page size limit for `/categories/search`, which the local answer mirrors. */
const SEARCH_PAGE_LIMIT = 25;
const SEARCH_TERM_LENGTH = 250;
const SEARCH_WORDS = 25;

/** Ruby's `strip` and `\S+` treat only ASCII whitespace as space, unlike JS `trim` and `\s`. */
const SEARCH_TERM_EDGES = /^[\0\t\n\v\f\r ]+|[\0\t\n\v\f\r ]+$/g;
const SEARCH_WORD_BREAK = /[\t\n\v\f\r ]+/;

function normalizeSearchText(text: string | null | undefined): string {
  return removeAccents((text ?? "").toLowerCase());
}

/** The trimmed, truncated term and its normalized words, as the server reads them. */
function parseSearchTerm(term: unknown): { text: string; words: string[] } {
  const text = Array.from(String(term ?? "").replace(SEARCH_TERM_EDGES, ""))
    .slice(0, SEARCH_TERM_LENGTH)
    .join("");
  const words = text
    .split(SEARCH_WORD_BREAK)
    .filter(Boolean)
    .slice(0, SEARCH_WORDS)
    .map(normalizeSearchText);
  return { text, words };
}

let _uncategorized: Category | undefined;

/**
 * @internal
 * Registers a property to include when saving a category.
 *
 * Intended to be used only in the plugin API.
 *
 * @param propertyKey - The key of the property to include.
 */
export function _addCategoryPropertyForSave(propertyKey: string) {
  registerModelSaveProperty("category", propertyKey);
}

// `create()` assigns the server fields at runtime, so the class declares none of
// them. Merging an interface of the same name adds them to the class type, and
// lets plugins add theirs by augmenting `CategoryFields`.
// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface Category extends CategoryFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class Category extends RestModel {
  // Sort subcategories directly under parents
  static sortCategories<
    T extends Pick<CategoryFields, "id" | "parent_category_id">,
  >(categories: T[]): T[] {
    const children = new Map<number | undefined, T[]>();

    categories.forEach((category) => {
      // parseInt coerces numeric and missing parent IDs at runtime.
      const parentId =
        parseInt(category.parent_category_id as unknown as string, 10) || -1;
      const group = children.get(parentId) || [];
      group.push(category);

      children.set(parentId, group);
    });

    // The flattened entries are category objects, not nested array values.
    const reduce = (values: T[]): T[] =>
      values
        .flatMap((c) => [c, reduce(children.get(c.id) || [])])
        .flat() as T[];

    return reduce(children.get(-1) || []);
  }

  static isUncategorized(categoryId: number | null | undefined): boolean {
    return categoryId === Site.currentProp("uncategorized_category_id");
  }

  static slugEncoded(): boolean {
    const siteSettings: RestModel["siteSettings"] = getOwnerWithFallback(
      this
    ).lookup("service:site-settings");
    return siteSettings.slug_generation_method === "encoded";
  }

  static findUncategorized(): Category | undefined {
    _uncategorized =
      _uncategorized ||
      Category.list().find(
        (category) =>
          category.id === Site.currentProp("uncategorized_category_id")
      );
    return _uncategorized;
  }

  static slugFor(
    category:
      | Pick<Category, "id" | "slug" | "parentCategory">
      | null
      | undefined,
    separator = "/",
    depth = 3
  ): string {
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

  static list(): Category[] {
    return Site.currentProp("categoriesList");
  }

  static listByActivity(): Category[] {
    return Site.currentProp("sortedCategories");
  }

  static _idMap(): Map<number | undefined, Category> {
    return Site.currentProp("categoriesById");
  }

  static findSingleBySlug(slug: string): Category | undefined {
    if (!this.slugEncoded()) {
      return Category.list().find((c) => Category.slugFor(c) === slug);
    } else {
      return Category.list().find(
        (c) => Category.slugFor(c) === encodeURI(slug)
      );
    }
  }

  static findById(
    id: number | string | null | undefined
  ): Category | undefined {
    if (!id) {
      return;
    }

    if (typeof id === "string") {
      id = parseInt(id, 10);
    }

    return Category._idMap().get(id);
  }

  static findByIds(ids: (number | string)[] = []): Category[] {
    // Boolean filtering removes missing lookups without changing the predicate.
    return ids.map((id) => Category.findById(id)).filter(Boolean) as Category[];
  }

  static hasAsyncFoundAll(ids: (number | string)[]): boolean {
    const loadedCategoryIds = Site.current().loadedCategoryIds || new Set();
    // Only parsed numeric ids are loaded, so a string id never matches.
    return ids.every((id) => loadedCategoryIds.has(id as number));
  }

  static async asyncFindByIds(
    ids: (number | string)[] = []
  ): Promise<Category[]> {
    // parseInt also coerces numeric IDs supplied by callers.
    ids = ids.map((x) => parseInt(x as string, 10));
    const site = Site.current();

    if (!site.lazy_load_categories || this.hasAsyncFoundAll(ids)) {
      return this.findByIds(ids);
    }

    // TODO(typescript-pending): MultiCache loses its callback's value type; remove when generic.
    const result = (await categoryMultiCache.fetch(ids)) as Map<
      number | string,
      CategoryFields | undefined
    >;
    if (categoryMultiCache.hadTooManyCalls()) {
      warn(
        "Multiple calls to Category.asyncFindByIds within a second. Could they be combined?",
        {
          id: "discourse.category.multiple-async-find-by-ids-calls",
        }
      );
    }

    const loadedCategoryIds = site.loadedCategoryIds || new Set();
    for (const id of ids) {
      const category = result.get(id);
      if (category) {
        site.updateCategory(category);
      } else {
        site.removeCategory(id);
      }
      // `ids` holds the numbers parsed at the top of this method.
      loadedCategoryIds.add(id as number);
    }
    site.set("loadedCategoryIds", loadedCategoryIds);

    return this.findByIds(ids);
  }

  /**
   * The category and every descendant in breadth-first order. A lazy site pages each level from
   * the server, skipping categories known to have no children.
   */
  static async asyncFindDescendants(category: Category): Promise<Category[]> {
    if (!Site.current().lazy_load_categories) {
      return category.descendants;
    }

    const descendants = [category];
    const seen = new Set([category.id]);
    for (let index = 0; index < descendants.length; index++) {
      const parent = descendants[index];
      if (parent.has_children === false) {
        continue;
      }

      for (let page = 1, received = 0; ; page++) {
        const { categories, categoriesCount } = await this.asyncSearch("", {
          parentCategoryId: parent.id,
          includeAncestors: true,
          page,
        });
        received += categories.length;
        for (const child of categories) {
          if (!seen.has(child.id)) {
            seen.add(child.id);
            descendants.push(child);
          }
        }
        if (!categories.length || received >= categoriesCount) {
          break;
        }
      }
    }
    return descendants;
  }

  static async asyncFindById(
    id: number | string
  ): Promise<Category | undefined> {
    return (await Category.asyncFindByIds([id]))[0];
  }

  static findBySlugAndParent(
    slug: string,
    parentCategory: Category | null | undefined
  ): Category | undefined {
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

  static findBySlugPath(slugPath: string[]): Category | null {
    let category: Category | null | undefined = null;

    for (const slug of slugPath) {
      category = this.findBySlugAndParent(slug, category);

      if (!category) {
        return null;
      }
    }

    return category;
  }

  static async asyncFindBySlugPath(
    slugPath: string,
    opts: { includePermissions?: boolean } = {}
  ): Promise<Category | undefined> {
    const data: { slug_path: string; include_permissions?: boolean } = {
      slug_path: slugPath,
    };
    if (opts.includePermissions) {
      data.include_permissions = true;
    }

    // TODO(typescript-pending): ajax does not type response payloads yet.
    const result = (await ajax("/categories/find", { data })) as {
      categories: CategoryFields[];
    };

    const categories = result["categories"].map(
      (category: CategoryFields | Category) => {
        category = Site.current().updateCategory(category);
        // `Category` extends `CategoryFields`, so the reassignment above does not
        // narrow the union; `updateCategory` returns the model.
        if (opts.includePermissions) {
          (category as Category).setupGroupsAndPermissions();
        }
        return category as Category;
      }
    );

    return categories[categories.length - 1];
  }

  static async asyncFindBySlugPathWithID(
    slugPathWithID: string
  ): Promise<Category | undefined> {
    // TODO(typescript-pending): ajax does not type response payloads yet.
    const result = (await ajax("/categories/find", {
      data: { slug_path_with_id: slugPathWithID },
    })) as { categories: CategoryFields[] };

    const categories = result["categories"].map((category) =>
      Site.current().updateCategory(category)
    );

    return categories[categories.length - 1];
  }

  static findBySlugPathWithID(
    slugPathWithID: string
  ): Category | null | undefined {
    let parts = slugPathWithID.split("/").filter(Boolean);
    // slugs found by star/glob pathing in ember do not automatically url decode - ensure that these are decoded
    if (this.slugEncoded()) {
      parts = parts.map((urlPart) => decodeURI(urlPart));
    }
    let category;

    if (parts.length > 0 && parts[parts.length - 1].match(/^\d+$/)) {
      // The branch's length check guarantees a final path segment.
      const id = parseInt(parts.pop()!, 10);

      category = Category.findById(id);
    } else {
      category = Category.findBySlugPath(parts);

      if (
        !category &&
        parts.length > 0 &&
        parts[parts.length - 1].match(/^\d+-category/)
      ) {
        // The branch's length check guarantees a final path segment.
        const id = parseInt(parts.pop()!, 10);

        category = Category.findById(id);
      }
    }

    return category;
  }

  static findBySlug(slug: string, parentSlug?: string): Category | undefined {
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
      category = categories.find((c) => c.id === parseInt(slug, 10));
    }

    return category;
  }

  static fetchVisibleGroups(id: number): Promise<{ groups: string[] }> {
    return ajax(`/c/${id}/visible_groups.json`);
  }

  static reloadById(
    id: number | string
  ): Promise<{ category: CategoryFields }> {
    return ajax(`/c/${id}/show.json`);
  }

  static reloadBySlugPath(
    slugPath: string
  ): Promise<{ category: CategoryFields }> {
    return ajax(`/c/${slugPath}/find_by_slug.json`);
  }

  static reloadCategoryWithPermissions(
    params: { slug: string },
    store: StoreService,
    site: Site
  ): Promise<Category> {
    return this.reloadBySlugPath(params.slug).then((result) =>
      this._includePermissions(result.category, store, site)
    );
  }

  static _includePermissions(
    category: CategoryFields,
    store: StoreService,
    site: Site
  ): Category {
    const model = site.updateCategory(category);
    model.setupGroupsAndPermissions();
    model.setupCategoryTypes();
    return model;
  }

  static search(
    term: string,
    opts?: Pick<CategorySearchOptions, "limit" | "parentCategoryId">
  ): Category[] {
    let limit = 5;
    let parentCategoryId: number | undefined;

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

    // Search assumes the loaded categories have names and slugs.
    const normalize = (str: string | null | undefined): string =>
      removeAccents(str!.toLowerCase());

    if (!emptyTerm) {
      term = normalize(term);
      slugTerm = term;
      term = term.replace(/-/g, " ");
    }

    const categories = Category.listByActivity();
    const length = categories.length;
    let i;
    const data: Category[] = [];

    const done = () => {
      return data.length === limit;
    };

    const validCategoryParent = (category: Category) => {
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
            (normalize(category.get("name")).startsWith(term) ||
              normalize(category.get("slug")).startsWith(slugTerm)))) &&
        validCategoryParent(category)
      ) {
        data.push(category);
      }
    }

    if (!done()) {
      for (i = 0; i < length && !done(); i++) {
        const category = categories[i];

        if (
          ((!emptyTerm && normalize(category.get("name")).indexOf(term) > 0) ||
            normalize(category.get("slug")).indexOf(slugTerm) > 0) &&
          validCategoryParent(category)
        ) {
          if (!data.includes(category)) {
            data.push(category);
          }
        }
      }
    }

    return data.sort((a, b) => compare(a?.read_restricted, b?.read_restricted));
  }

  static async asyncHierarchicalSearch(
    term: string,
    opts?: { only?: number[]; except?: number[]; page?: number }
  ): Promise<Category[]> {
    opts ||= {};

    const data = {
      term,
      only: opts.only,
      except: opts.except,
      page: opts.page,
    };

    const cacheKey = JSON.stringify(data);
    CATEGORY_ASYNC_HIERARCHICAL_SEARCH_CACHE[cacheKey] ||= await ajax(
      "/categories/hierarchical_search",
      {
        method: "GET",
        data,
      }
    );
    const result = CATEGORY_ASYNC_HIERARCHICAL_SEARCH_CACHE[cacheKey];

    return result["categories"].map((category) =>
      Site.current().updateCategory(category)
    );
  }

  static clearAsyncHierarchicalSearchCache() {
    Object.keys(CATEGORY_ASYNC_HIERARCHICAL_SEARCH_CACHE).forEach((key) => {
      delete CATEGORY_ASYNC_HIERARCHICAL_SEARCH_CACHE[key];
    });
  }

  static clearAsyncSearchCache() {
    Object.keys(CATEGORY_ASYNC_SEARCH_CACHE).forEach((key) => {
      delete CATEGORY_ASYNC_SEARCH_CACHE[key];
    });
  }

  static asyncSearch(
    term: string,
    opts: CategorySearchOptions & { includeAncestors: true }
  ): Promise<CategorySearchResult>;

  static asyncSearch(
    term: string,
    opts?: CategorySearchOptions & { includeAncestors?: false }
  ): Promise<Category[]>;

  static asyncSearch(
    term: string,
    opts?: CategorySearchOptions
  ): Promise<Category[] | CategorySearchResult>;

  static async asyncSearch(
    term: string,
    opts?: CategorySearchOptions
  ): Promise<Category[] | CategorySearchResult> {
    const { ancestors, categories, categoriesCount } =
      await this.searchCategories(term, opts);

    if (opts?.includeAncestors) {
      return { ancestors, categories, categoriesCount };
    } else {
      return categories;
    }
  }

  /**
   * Searches categories with the server's matching and order. A site that loads every category
   * answers from them synchronously, so callers get no input delay; a lazy site asks the server
   * and returns a promise. Without a `limit`, a local answer returns every match as one page.
   * A local answer folds fewer characters than the server's `unaccent` (such as `ß` or
   * fullwidth forms) and matches the name the site serialized, which may be localized.
   */
  static searchCategories(
    term: string,
    opts: CategorySearchOptions = {}
  ): CategorySearchAnswer | Promise<CategorySearchAnswer> {
    if (Site.current().lazy_load_categories) {
      return this.#searchServer(term, opts);
    }
    return this.#searchLocal(term, opts);
  }

  /**
   * The ids' categories: synchronously when they are already known, otherwise the promise of
   * loading them.
   */
  static findByIdsOrLoad(
    ids: (number | string)[] = []
  ): Category[] | Promise<Category[]> {
    const parsedIds = ids.map((id) => parseInt(id as string, 10));
    if (
      !Site.current().lazy_load_categories ||
      this.hasAsyncFoundAll(parsedIds)
    ) {
      return this.findByIds(parsedIds);
    }
    return this.asyncFindByIds(parsedIds);
  }

  /** Whether the category's name contains every word of the term, as a search matches it. */
  static matchesSearch(category: Category, term: string): boolean {
    const name = normalizeSearchText(category.name);
    return parseSearchTerm(term).words.every((word) => name.includes(word));
  }

  /**
   * The categories a local search reads, or `undefined` on a lazy site. Reading it consumes
   * the site's collection, so a caller that keys work on it sees categories being added.
   */
  static localSearchCategories(): Category[] | undefined {
    const site = Site.current();
    return site.lazy_load_categories ? undefined : [...site.categories];
  }

  static async #searchServer(
    term: string,
    opts: CategorySearchOptions
  ): Promise<CategorySearchAnswer> {
    const data = {
      term,
      only_postable: opts.onlyPostable,
      parent_category_id: opts.parentCategoryId,
      include_uncategorized: opts.includeUncategorized,
      select_category_ids: opts.selectCategoryIds,
      reject_category_ids: opts.rejectCategoryIds,
      reject_indirectly_muted: opts.rejectIndirectlyMuted,
      include_subcategories: opts.includeSubcategories,
      include_ancestors: opts.includeAncestors,
      prioritized_category_id: opts.prioritizedCategoryId,
      limit: opts.limit,
      page: opts.page,
      group_families: opts.groupFamilies,
      tree_order: opts.treeOrder,
    };

    // Ordered requests are never cached: topic counts change, and one list must not mix pages
    // fetched at different times. Nor are muted ones, because the user's mutes change too.
    const uncacheable =
      data.group_families !== undefined ||
      data.tree_order !== undefined ||
      data.reject_indirectly_muted !== undefined;
    const fetch = (): Promise<CategorySearchResponse> =>
      ajax("/categories/search", { method: "POST", data });
    const result = uncacheable
      ? await fetch()
      : (CATEGORY_ASYNC_SEARCH_CACHE[JSON.stringify(data)] ||= await fetch());

    return {
      ancestors: opts.includeAncestors
        ? this.#registerLoaded(result["ancestors"])
        : [],
      categories: this.#registerLoaded(result["categories"]),
      categoriesCount: result["categories_count"],
      familyKeys: result["family_keys"],
    };
  }

  /** Mirrors the server's search over the site's categories. */
  static #searchLocal(
    term: string,
    opts: CategorySearchOptions
  ): CategorySearchAnswer {
    const visible = Site.current().categories;
    const { text, words } = parseSearchTerm(term);
    const muted = opts.rejectIndirectlyMuted
      ? this.#indirectlyMutedIds()
      : undefined;
    const eligible = visible.filter(
      (category) =>
        this.#passesSearchFilters(category, opts) && !muted?.has(category.id!)
    );
    const matched = eligible.filter((category) => {
      const name = normalizeSearchText(category.name);
      return words.every((word) => name.includes(word));
    });

    let ordered: Category[];
    let keys: Map<Category, number | null> | undefined;
    if (text && opts.groupFamilies) {
      const ranked = this.#rankBySearch(
        matched,
        normalizeSearchText(text),
        opts.prioritizedCategoryId
      );
      keys = this.#familyKeys(visible, eligible, ranked);
      ordered = this.#groupFamilies(ranked, keys);
    } else if (!text && opts.treeOrder) {
      ordered = this.#treeOrder(
        visible,
        matched,
        opts.treeOrder,
        opts.prioritizedCategoryId
      );
    } else {
      ordered = this.#rankBySearch(
        matched,
        normalizeSearchText(text),
        opts.prioritizedCategoryId
      );
    }

    const page = Math.max(1, parseInt(String(opts.page), 10) || 0);
    let categories: Category[];
    if (opts.limit == null) {
      categories = page === 1 ? ordered : [];
    } else {
      const limit = Math.min(
        Math.max(parseInt(String(opts.limit), 10) || 0, 1),
        SEARCH_PAGE_LIMIT
      );
      categories = ordered.slice((page - 1) * limit, page * limit);
    }

    return {
      ancestors: opts.includeAncestors ? this.#searchAncestors(categories) : [],
      categories,
      categoriesCount: matched.length,
      familyKeys: keys
        ? Object.fromEntries(
            categories.map((category) => [category.id!, keys.get(category)!])
          )
        : undefined,
    };
  }

  static #passesSearchFilters(
    category: Category,
    opts: CategorySearchOptions
  ): boolean {
    const parentId = category.parent_category_id ?? null;
    if (opts.parentCategoryId != null) {
      const wanted =
        opts.parentCategoryId === -1 ? null : opts.parentCategoryId;
      if (parentId !== wanted) {
        return false;
      }
    }
    if (
      opts.includeUncategorized === false &&
      this.isUncategorized(category.id)
    ) {
      return false;
    }
    // The client never sends an empty list, so an empty one is no filter.
    if (
      opts.selectCategoryIds?.length &&
      !opts.selectCategoryIds.map(Number).includes(category.id!)
    ) {
      return false;
    }
    if (opts.rejectCategoryIds?.map(Number).includes(category.id!)) {
      return false;
    }
    if (opts.includeSubcategories === false && parentId !== null) {
      return false;
    }
    if (opts.onlyPostable && !this.#canCreateTopicIn(category)) {
      return false;
    }
    return true;
  }

  /** The current user's indirectly muted category ids, kept current by the message bus. */
  static #indirectlyMutedIds(): Set<number> {
    const currentUser = getOwnerWithFallback(this).lookup(
      "service:current-user"
    ) as User | null;
    const ids = currentUser?.get("indirectly_muted_category_ids") as
      | number[]
      | undefined;
    return new Set(ids ?? []);
  }

  /** The server's `topic_create_allowed`, which also keeps non-staff out of Uncategorized. */
  static #canCreateTopicIn(category: Category): boolean {
    if (!category.canCreateTopic) {
      return false;
    }
    if (!this.isUncategorized(category.id)) {
      return true;
    }
    const owner = getOwnerWithFallback(this);
    const siteSettings: RestModel["siteSettings"] = owner.lookup(
      "service:site-settings"
    );
    const currentUser = owner.lookup("service:current-user") as User | null;
    return !!siteSettings.allow_uncategorized_topics || !!currentUser?.staff;
  }

  /** The rows in the server's base search order. */
  static #rankBySearch(
    rows: Category[],
    prefix: string,
    prioritizedId: number | undefined
  ): Category[] {
    const rank = new Map(
      rows.map((category) => [
        category,
        [
          normalizeSearchText(category.name).startsWith(prefix) ? 0 : 1,
          category.parent_category_id == null ? 0 : 1,
          prioritizedId != null && category.id === prioritizedId ? 0 : 1,
          prioritizedId != null && category.parent_category_id === prioritizedId
            ? 0
            : 1,
          category.id!,
        ],
      ])
    );
    return [...rows].sort((a, b) => {
      const left = rank.get(a)!;
      const right = rank.get(b)!;
      const index = left.findIndex((value, i) => value !== right[i]);
      return index === -1 ? 0 : left[index] - right[index];
    });
  }

  /**
   * Each row's family key. A family is a visible category with an eligible descendant, one that
   * passes every filter but the term, reached through visible categories; two hops reach every
   * level, since nesting is capped at three.
   */
  static #familyKeys(
    visible: Category[],
    eligible: Category[],
    rows: Category[]
  ): Map<Category, number | null> {
    const eligibleParents = new Set(
      eligible.map((category) => category.parent_category_id).filter(Boolean)
    );
    const visibleIds = new Set(visible.map((category) => category.id!));
    const families = new Set<number>();
    for (const category of visible) {
      if (!eligibleParents.has(category.id!)) {
        continue;
      }
      families.add(category.id!);
      const parentId = category.parent_category_id;
      if (parentId && visibleIds.has(parentId)) {
        families.add(parentId);
      }
    }

    return new Map(
      rows.map((category) => {
        const parentId = category.parent_category_id;
        if (families.has(category.id!)) {
          return [category, category.id!];
        } else if (parentId && families.has(parentId)) {
          return [category, parentId];
        }
        return [category, null];
      })
    );
  }

  /** Keeps each family's rows together, by its best-ranked row, with the key category first. */
  static #groupFamilies(
    ranked: Category[],
    keys: Map<Category, number | null>
  ): Category[] {
    const groupOf = (category: Category) => keys.get(category) ?? -category.id!;
    const groupRank = new Map<number, number>();
    ranked.forEach((category, index) => {
      const group = groupOf(category);
      if (!groupRank.has(group)) {
        groupRank.set(group, index);
      }
    });
    const position = new Map(
      ranked.map((category, index) => [category, index])
    );

    return [...ranked].sort(
      (a, b) =>
        groupRank.get(groupOf(a))! - groupRank.get(groupOf(b))! ||
        Number(keys.get(b) === b.id) - Number(keys.get(a) === a.id) ||
        position.get(a)! - position.get(b)!
    );
  }

  /**
   * The rows in the tree order of every visible category, so filters only remove rows. A
   * category whose parent is hidden sorts as a root.
   */
  static #treeOrder(
    visible: Category[],
    rows: Category[],
    mode: "topics" | "position",
    prioritizedId: number | undefined
  ): Category[] {
    const visibleById = new Map(
      visible.map((category) => [category.id!, category])
    );
    const parentOf = (category: Category) => {
      const parentId = category.parent_category_id;
      return parentId && visibleById.has(parentId) ? parentId : null;
    };
    const children = new Map<number | null, Category[]>();
    for (const category of visible) {
      const parentId = parentOf(category);
      const siblings = children.get(parentId);
      if (siblings) {
        siblings.push(category);
      } else {
        children.set(parentId, [category]);
      }
    }

    const byPosition = (a: Category, b: Category) =>
      (a.position ?? Infinity) - (b.position ?? Infinity) || a.id! - b.id!;
    const compareSiblings =
      mode === "topics"
        ? (a: Category, b: Category) =>
            (b.topic_count ?? 0) - (a.topic_count ?? 0) || byPosition(a, b)
        : byPosition;

    const treeIndex = new Map<Category, number>();
    const rootOf = new Map<Category, number>();
    const visit = (parentId: number | null, root: number | null) => {
      for (const category of (children.get(parentId) ?? []).sort(
        compareSiblings
      )) {
        treeIndex.set(category, treeIndex.size);
        rootOf.set(category, root ?? category.id!);
        visit(category.id!, root ?? category.id!);
      }
    };
    visit(null, null);

    const prioritized =
      prioritizedId == null ? undefined : visibleById.get(prioritizedId);
    const priorityRoot = prioritized ? rootOf.get(prioritized) : undefined;
    const firstForPriority = (category: Category) =>
      priorityRoot !== undefined && rootOf.get(category) === priorityRoot
        ? 0
        : 1;

    return [...rows].sort(
      (a, b) =>
        firstForPriority(a) - firstForPriority(b) ||
        treeIndex.get(a)! - treeIndex.get(b)!
    );
  }

  /** The visible ancestors of the rows, as the server's `ancestors_of` walks them. */
  static #searchAncestors(rows: Category[]): Category[] {
    const ancestors = new Set<Category>();
    for (const row of rows) {
      let parent = this.findById(row.parent_category_id);
      while (parent && !ancestors.has(parent)) {
        ancestors.add(parent);
        parent = this.findById(parent.parent_category_id);
      }
    }
    return [...ancestors];
  }

  /**
   * Adds server records to the site and marks them loaded. Search and find serialize the same
   * fields, so a searched record needs no later `asyncFindByIds` round trip.
   */
  static #registerLoaded(pojos: CategoryFields[]): Category[] {
    const site = Site.current();
    const records = pojos.map((category) => site.updateCategory(category));
    const loadedCategoryIds = site.loadedCategoryIds || new Set<number>();
    for (const { id } of records) {
      if (id != null) {
        loadedCategoryIds.add(id);
      }
    }
    site.set("loadedCategoryIds", loadedCategoryIds);
    return records;
  }

  @service declare currentUser: User | null;

  @tracked color!: string;
  @tracked emoji!: string | null;
  @tracked icon!: string | null;
  @tracked
  localizations: CategoryEditableLocalization[] | undefined =
    this.category_localizations;
  @tracked minimum_required_tags?: number | null;
  @tracked styleType: CategoryStyle | undefined = this.style_type;
  @tracked allowed_tags?: (CategoryAllowedTag | string)[];
  @tracked categoryTypes!: Record<string, CategoryTypeMetadata>;
  @autoTrackedArray available_groups?: string[];
  @autoTrackedArray permissions?: CategoryPermission[];
  @autoTrackedArray required_tag_groups?: CategoryRequiredTagGroup[];

  init(...args: Parameters<RestModel["init"]>) {
    super.init(...args);
    this.setupGroupsAndPermissions();
    this.setupCategoryTypes();
  }

  @computed("parent_category_id", "site.categories.[]")
  get parentCategory(): Category | undefined {
    if (this.parent_category_id) {
      return Category.findById(this.parent_category_id);
    }
  }

  set parentCategory(newParentCategory: Category | undefined) {
    this.set("parent_category_id", newParentCategory?.id);
  }

  @dependentKeyCompat
  get availableGroups() {
    return this.available_groups;
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

  /**
   * The description as plain text, for places that render it escaped. The server sends
   * `description_text` HTML-escaped, so this reverses exactly that escaping and never parses
   * markup: tags stay literal text.
   */
  get descriptionPlainText(): string | undefined {
    const text = this.descriptionText;
    if (typeof text !== "string") {
      return;
    }
    return text.replace(
      /&(?:amp|lt|gt|quot|#39);/g,
      (entity) => ESCAPED_ENTITIES[entity]
    );
  }

  get displayName() {
    return applyValueTransformer("category-display-name", this.get("name"), {
      category: this,
    });
  }

  get textColor() {
    return applyValueTransformer(
      "category-text-color",
      this.get("text_color"),
      {
        category: this,
      }
    );
  }

  get subcategories(): Category[] {
    return applyValueTransformer(
      "category-subcategories",
      this.site.categoriesByParentId.get(this.id) || [],
      { category: this }
    );
  }

  get unloadedSubcategoryCount() {
    // This count is read on payloads that include the subcategory count.
    return this.subcategory_count! - this.subcategories.length;
  }

  @computed("subcategory_list")
  get serializedSubcategories() {
    // TODO(typescript-pending): serialized subcategories include topic payloads; remove when typed at the source.
    return (
      this.subcategory_list as
        | (Omit<CategoryFields, "topics"> & {
            topics?: Record<string, unknown>[];
          })[]
        | undefined
    )?.map((c) => {
      const subcategory = Category.create({
        ...c,
        topics: c.topics?.map((t) => Topic.create(t)),
      });
      return subcategory;
    });
  }

  @dependentKeyCompat
  get minimumRequiredTags() {
    // An absent group list still follows the original comparison's false branch.
    if ((this.required_tag_groups?.length as number) > 0) {
      // it should require the max between the bare minimum set in the category and the sum of the min_count of the
      // required_tag_groups
      return Math.max(
        // The length comparison above guarantees the group list exists.
        this.required_tag_groups!.reduce((sum, rtg) => sum + rtg.min_count, 0),
        this.minimum_required_tags || 0
      );
    } else {
      // Missing/null minima still compare false without introducing a fallback.
      return this.minimum_required_tags! > 0
        ? this.minimum_required_tags
        : null;
    }
  }

  @computed
  get availablePermissions() {
    // TODO(typescript-pending): PermissionType reads its create-assigned id but does not declare it.
    return [
      PermissionType.create({
        id: PermissionType.FULL,
      } as Partial<PermissionType> & { id: number }),
      PermissionType.create({
        id: PermissionType.CREATE_POST,
      } as Partial<PermissionType> & { id: number }),
      PermissionType.create({
        id: PermissionType.READONLY,
      } as Partial<PermissionType> & { id: number }),
    ];
  }

  @computed("id")
  get searchContext(): {
    type: string;
    id: number | undefined;
    category: Category;
  } {
    return {
      type: "category",
      id: this.id,
      /** The category model. */
      category: this,
    };
  }

  @computed("parentCategory.ancestors")
  get ancestors(): Category[] {
    return [...(this.parentCategory?.ancestors || []), this];
  }

  @computed("parentCategory", "parentCategory.predecessors")
  get predecessors(): Category[] {
    if (this.parentCategory) {
      return [
        this.parentCategory,
        ...(this.parentCategory?.predecessors || []),
      ];
    } else {
      return [];
    }
  }

  get descendants(): Category[] {
    const descendants: Category[] = [this];
    for (let i = 0; i < descendants.length; i++) {
      if (descendants[i].subcategories) {
        descendants.push(...descendants[i].subcategories);
      }
    }
    return descendants;
  }

  @computed("parentCategory.level")
  get level(): number {
    if (!this.parentCategory?.level) {
      return this.parentCategory?.level === 0 ? 1 : 0;
    } else {
      return this.parentCategory?.level + 1;
    }
  }

  @computed("has_children", "subcategories")
  get isParent() {
    return (
      this.has_children || (this.subcategories && this.subcategories.length > 0)
    );
  }

  @computed("subcategories")
  get isGrandParent() {
    return (
      this.subcategories &&
      this.subcategories.some(
        (cat) => cat.subcategories && cat.subcategories.length > 0
      )
    );
  }

  @computed("notification_level")
  get isMuted() {
    return this.notification_level === NotificationLevels.MUTED;
  }

  @computed("isMuted", "subcategories")
  get isHidden(): boolean {
    if (!this.isMuted) {
      return false;
    } else if (!this.subcategories) {
      return true;
    }

    if (this.subcategories.some((cat) => !cat.isHidden)) {
      return false;
    }

    return true;
  }

  @computed("isMuted", "subcategories")
  get hasMuted(): boolean {
    if (this.isMuted) {
      return true;
    } else if (!this.subcategories) {
      return false;
    }

    if (this.subcategories.some((cat) => cat.hasMuted)) {
      return true;
    }

    return false;
  }

  @computed("notification_level")
  get notificationLevelString() {
    // Get the key from the value
    const notificationLevelString = Object.keys(NotificationLevels).find(
      (key) =>
        NotificationLevels[key as keyof typeof NotificationLevels] ===
        this.notification_level
    );
    if (notificationLevelString) {
      return notificationLevelString.toLowerCase();
    }
  }

  @computed("name")
  get path() {
    return `/c/${Category.slugFor(this)}/${this.id}`;
  }

  @computed("path")
  get url(): string {
    return getURL(this.path);
  }

  @computed
  get fullSlug() {
    return Category.slugFor(this).replace(/\//g, "-");
  }

  @computed("name")
  get nameLower() {
    // Name-dependent views assume the category name is loaded.
    return this.name!.toLowerCase();
  }

  @computed("url")
  get unreadUrl() {
    return `${this.url}/l/unread`;
  }

  @computed("url")
  get newUrl() {
    return `${this.url}/l/new`;
  }

  @computed("color", "text_color")
  get style() {
    return `background-color: #${this.color}; color: #${this.text_color}`;
  }

  @computed("topic_count")
  get moreTopics() {
    // The comparison keeps JavaScript's handling of a missing count.
    return this.topic_count! > (this.num_featured_topics || 2);
  }

  @computed("topic_count", "subcategories.[]")
  get totalTopicCount(): number | undefined {
    // Transient preview categories have no topic count; the sum keeps JavaScript's
    // handling of a missing one.
    let topicCount = this.topic_count as number;
    if (this.subcategories) {
      this.subcategories.forEach((subcategory) => {
        topicCount += subcategory.topic_count!;
      });
    }
    return topicCount;
  }

  @computed("default_slow_mode_seconds")
  get defaultSlowModeMinutes() {
    return this.default_slow_mode_seconds
      ? this.default_slow_mode_seconds / 60
      : null;
  }

  @computed("notification_level")
  get isTracked() {
    // Preserve the comparison when notification_level is absent or null.
    return this.notification_level! >= NotificationLevels.TRACKING;
  }

  get unreadTopicsCount(): number {
    return this.topicTrackingState.countUnread({ categoryId: this.id });
  }

  get newTopicsCount(): number {
    return this.topicTrackingState.countNew({ categoryId: this.id });
  }

  @computed("topics")
  get latestTopic() {
    if (this.topics && this.topics.length) {
      return this.topics[0];
    }
  }

  @computed("topics")
  get featuredTopics() {
    if (this.topics && this.topics.length) {
      return this.topics.slice(0, this.num_featured_topics || 2);
    }
  }

  @computed("id")
  get isUncategorizedCategory() {
    return Category.isUncategorized(this.id);
  }

  get canCreateTopic() {
    return this.permission === PermissionType.FULL;
  }

  get subcategoryWithCreateTopicPermission() {
    return this.subcategories?.find(
      (subcategory) => subcategory.canCreateTopic
    );
  }

  setupCategoryTypes() {
    this.categoryTypes = trackedObject(this.category_types);
  }

  setupGroupsAndPermissions() {
    if (!this.available_groups) {
      return;
    }

    if (this.group_permissions) {
      this.permissions = this.group_permissions.map((elem) => {
        // setup requires available_groups; the guard above established it before mapping.
        removeValueFromArray(this.available_groups!, elem.group_name);
        return trackedObject(elem);
      });
    }
  }

  /**
   * @param categoryTypeIds - ids of the category's types; when
   *   omitted, the server leaves the category's types unchanged.
   */
  save(categoryTypeIds?: string[]): Promise<{ category: CategoryFields }> {
    const id = this.id;
    const url = id ? `/categories/${id}` : "/categories";

    this.styleType = this.style_type;

    return ajax(url, {
      contentType: "application/json",
      data: JSON.stringify({
        name: this.name,
        slug: this.slug,
        color: this.color,
        text_color: this.text_color,
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
        topic_title_placeholder: this.topic_title_placeholder,
        form_template_ids: this.form_template_ids,
        all_topics_wiki: this.all_topics_wiki,
        allow_unlimited_owner_edits_on_first_post:
          this.allow_unlimited_owner_edits_on_first_post,
        allowed_tags: this.allowed_tags?.map((t) =>
          typeof t === "object" ? t.name : t
        ),
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
        topic_posting_review_group_ids: this.topic_posting_review_group_ids,
        reply_posting_review_group_ids: this.reply_posting_review_group_ids,
        read_only_banner: this.read_only_banner,
        default_list_filter: this.default_list_filter,
        style_type: this.style_type,
        emoji: this.emoji,
        icon: this.icon,
        // TODO(typescript-pending): the settings factory does not publish property types yet.
        ...((this.siteSettings.content_localization_enabled as boolean) && {
          locale: this.locale,
          category_localizations: this.localizations,
        }),
        ...this._categoryTypeSaveProperties(id, categoryTypeIds),
        ...this._pluginSaveProperties(),
        category_types: categoryTypeIds,
      }),
      type: id ? "PUT" : "POST",
    });
  }

  destroy(this: never, ...args: never[]): never;
  destroy(): Promise<unknown>;
  destroy(): Promise<unknown> {
    return ajax(`/categories/${this.id || this.slug}`, {
      type: "DELETE",
    });
  }

  addPermission(permission: CategoryPermission) {
    // Permission editing requires the edit form's initialized permission/group arrays.
    addUniqueValueToArray(this.permissions!, trackedObject(permission));
    removeValueFromArray(this.available_groups!, permission.group_name);
  }

  removePermission(group_name: string) {
    // Permission editing requires the edit form's initialized permission/group arrays.
    const permission = this.permissions!.find(
      (p) => p.group_name === group_name
    );

    if (permission) {
      removeValueFromArray(this.permissions!, permission);
      addUniqueValueToArray(this.available_groups!, group_name);
    }
  }

  updatePermission(group_name: string, type: number | null) {
    // Permission editing requires the edit form's initialized permission array.
    this.permissions!.forEach((p, i) => {
      if (p.group_name === group_name) {
        this.permissions![i].permission_type = type;
      }
    });
  }

  isType(type: string) {
    return Object.keys(this.categoryTypes ?? {}).includes(type);
  }

  getType(type: string): CategoryTypeMetadata | undefined {
    return this.categoryTypes?.[type];
  }

  removeType(type: string) {
    delete this.categoryTypes[type];
  }

  setNotification(notification_level: number): Promise<void> {
    // Notification changes require a signed-in user.
    this.currentUser!.set(
      "muted_category_ids",
      this.currentUser!.calculateMutedIds(
        notification_level,
        this.id,
        "muted_category_ids"
      )
    );

    const url = `/category/${this.id}/notifications`;
    return ajax(url, { data: { notification_level }, type: "POST" }).then(
      (data) => {
        // Notification changes require a signed-in user through completion.
        this.currentUser!.set(
          "indirectly_muted_category_ids",
          data.indirectly_muted_category_ids
        );
        this.set("notification_level", notification_level);
        this.notifyPropertyChange("notification_level");
      }
    );
  }

  _categoryTypeSaveProperties(
    id: number | undefined,
    categoryTypeIds?: string[]
  ) {
    const props: {
      category_type_site_settings: CategoryFields["category_type_site_settings"];
      category_type_settings: CategoryFields["category_type_settings"];
      category_type?: string;
    } = {
      category_type_site_settings: this.category_type_site_settings,
      category_type_settings: this.category_type_settings,
    };

    if (!id && this.categoryTypes) {
      const primaryType = Object.keys(this.categoryTypes)[0];
      if (categoryTypeIds?.includes(primaryType)) {
        props.category_type = primaryType;
      }
    }

    return props;
  }

  _pluginSaveProperties() {
    return extraSavePropertiesFor("category", this);
  }

  _permissionsForUpdate() {
    // Saving permissions requires the edit form's initialized permission array.
    const permissions = this.permissions!;
    const rval: Record<string, number | null> = {};
    if (permissions.length) {
      permissions.forEach((p) => (rval[p.group_name] = p.permission_type));
    } else {
      // empty permissions => staff-only access
      rval[Site.currentProp("groupsById")[AUTO_GROUPS.staff.id].name] =
        PermissionType.FULL;
    }
    return rval;
  }
}

const categoryMultiCache = new MultiCache(async (ids: number[]) => {
  try {
    // TODO(typescript-pending): ajax does not type response payloads yet.
    const { categories } = (await ajax("/categories/find", {
      data: { ids },
    })) as { categories: CategoryFields[] };
    return new Map(categories.map((category) => [category.id, category]));
  } catch (error) {
    // TODO(typescript-pending): ajax rejects with its jqXHR wrapper; remove when errors are typed.
    if (
      (error as { jqXHR?: { status?: number } }).jqXHR?.status ===
      HTTP_NOT_FOUND
    ) {
      return new Map();
    }

    throw error;
  }
});

export function resetCategoryCache() {
  categoryMultiCache.reset();
  _uncategorized = undefined;
}
