import { cached, tracked } from "@glimmer/tracking";
import EmberObject, { computed, get, set } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { trackedArray } from "@ember/reactive/collections";
import { service } from "@ember/service";
import { type TrustedHTML, trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import {
  arraySortedByProperties,
  removeValueFromArray,
} from "discourse/lib/array-tools";
import { AUTO_GROUPS } from "discourse/lib/constants";
import deprecated, { withSilencedDeprecations } from "discourse/lib/deprecated";
import { isRailsTesting, isTesting } from "discourse/lib/environment";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import Mobile from "discourse/lib/mobile";
import PreloadStore from "discourse/lib/preload-store";
import singleton from "discourse/lib/singleton";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import Archetype from "discourse/models/archetype";
import Category, {
  type CategoryFields,
  type CategoryTypeMetadata,
} from "discourse/models/category";
import PostActionType from "discourse/models/post-action-type";
import RestModel, {
  type RestModelAttrs,
  type RestModelClass,
} from "discourse/models/rest";
import type Tag from "discourse/models/tag";
import TrustLevel from "discourse/models/trust-level";
import type { CapabilitiesService } from "discourse/services/capabilities";
import type StoreService from "discourse/services/store";

/** A group as `SiteSerializer#groups` lists it. */
export interface SiteGroup {
  id: number;
  name: string;
  full_name: string;
  display_name: string;
  flair_url: string | null;
  flair_bg_color: string | null;
  flair_color: string | null;
  automatic: boolean;
}

/** An automatic group, which has only these keys until the server's group replaces it. */
export type SiteGroupLookupEntry = Pick<
  SiteGroup,
  "id" | "name" | "automatic"
> &
  Partial<Omit<SiteGroup, "id" | "name" | "automatic">>;

/** A custom user field, as `UserFieldSerializer` sends it. */
export interface SiteUserField {
  id: number;
  name: string;
  description: string;
  field_type:
    | "text"
    | "confirm"
    | "dropdown"
    | "multiselect"
    | "textarea"
    | "date";
  editable: boolean;
  required: boolean;
  requirement: "optional" | "for_all_users" | "on_signup";
  show_on_profile: boolean;
  show_on_user_card: boolean;
  show_on_signup: boolean;
  searchable: boolean;
  position: number | null;
  options?: string[];
}

/** A login method, as `AuthProviderSerializer` sends it. */
export interface SiteAuthProvider {
  can_connect: boolean;
  can_revoke: boolean;
  custom_url: string | null;
  frame_height: number | null;
  frame_width: number | null;
  icon_override: string | null;
  name: string;
  pretty_name_override: string | null;
  provider_url: string | null;
  title_override: string | null;
}

/** A tag in a top tags list. */
export interface SiteTopTag {
  id: number;
  name: string;
  slug: string;
}

/** A tag as the navigation menu lists it. */
export interface SiteSidebarTag extends SiteTopTag {
  description: string | null;
  pm_only: boolean;
}

/** A public navigation menu section, shown to anonymous visitors. */
export interface SiteSidebarSection {
  id: number;
  title: string;
  links: {
    id: number;
    name: string;
    value: string;
    icon: string;
    external: boolean;
    segment: "primary" | "secondary";
    locale: string | null;
  }[];
  slug: string;
  public: boolean;
  section_type: "community" | null;
  locale: string | null;
}

/** A theme visitors can choose. */
export interface SiteUserTheme {
  theme_id: number;
  name: string;
  default: boolean;
  color_scheme_id: number | null;
  dark_color_scheme_id: number | null;
  only_theme_color_schemes: boolean;
}

/** A color in a color scheme. `default_hex` is null when the base palette lacks the color. */
export interface SiteColor {
  name: string;
  hex: string;
  default_hex: string | null;
  is_advanced: boolean;
}

/** A color scheme visitors can choose. */
export interface SiteSelectableColorScheme {
  id: number;
  name: string;
  is_dark: boolean | null;
  theme_id: number | null;
  colors: SiteColor[];
}

/** The default theme's light or dark color scheme. */
export interface SiteColorScheme extends SiteSelectableColorScheme {
  is_base: boolean | null;
  base_scheme_id: number | null;
  theme_name: string | null;
  user_selectable: boolean;
  is_builtin_default: boolean | null;
}

/** A watched word, keyed in its list by the word's regular expression. */
export interface SiteWatchedWord {
  word: string;
  replacement?: string;
  case_sensitive: boolean;
  html?: true;
}

/** An access control entry that a target type always or never allows. */
export interface SiteAclEntry {
  type: "group" | "user";
  id: number;
  permission: string;
}

/** A category type as the site lists it, with every metadata key present. */
export interface SiteCategoryType extends CategoryTypeMetadata {
  description: string;
  icon: string | null;
}

/** The site banner; an empty object when no banner is set. */
export type SiteBanner = EmberObject & {
  html?: string;
  key?: number;
  url?: string;
};

/** A user's custom field values, keyed by user field id. */
export type SiteUserFieldValues = Record<
  string,
  string | string[] | boolean | null | undefined
>;

/**
 * Data fields on the site, as `SiteSerializer` sends them and as `create`
 * and core code reshape them.
 *
 * Most are optional because an anonymous visitor on a login-required site
 * receives only a few of them. Plugins add their own fields by augmenting this
 * interface.
 */
export interface SiteFields {
  default_archetype?: string;
  notification_types?: Record<string, number>;
  post_types?: Record<string, number>;
  user_tips?: Record<string, number>;
  /** Built by `create` from the server's `trust_levels`, which it removes. */
  trustLevels?: TrustLevel[];
  groups: SiteGroup[];
  filters: string[];
  anonymous_list_filters: string[];
  homepage_choices?: string[];
  homepage_options?: {
    id: string;
    path: string | null;
    server_side: boolean;
  }[];
  periods: string[];
  top_menu_items?: string[];
  anonymous_top_menu_items?: string[];
  uncategorized_category_id?: number;
  user_field_max_length?: number;
  post_action_types?: PostActionType[];
  topic_flag_types?: PostActionType[];
  can_create_tag?: boolean;
  can_search?: boolean;
  can_tag_topics?: boolean;
  can_tag_pms?: boolean;
  tags_filter_regexp?: string;
  top_tags?: SiteTopTag[];
  navigation_menu_site_top_tags?: SiteSidebarTag[];
  can_associate_groups?: boolean;
  wizard_required?: true;
  topic_featured_link_allowed_category_ids?: number[];
  user_themes?: SiteUserTheme[];
  user_color_schemes?: SiteSelectableColorScheme[];
  default_light_color_scheme?: SiteColorScheme | null;
  default_dark_color_scheme?: SiteColorScheme | null;
  censored_regexp?: Record<string, { case_sensitive: boolean }>[];
  shared_drafts_category_id?: number;
  custom_emoji_translation?: Record<string, string>;
  watched_words_replace?: Record<string, SiteWatchedWord> | null;
  watched_words_link?: Record<string, SiteWatchedWord> | null;
  categories: Category[];
  markdown_additional_options?: Record<string, unknown>;
  hashtag_configurations?: Record<string, string[]>;
  hashtag_icons?: Record<string, string>;
  anonymous_default_navigation_menu_tags?: SiteSidebarTag[];
  anonymous_sidebar_sections?: SiteSidebarSection[];
  whispers_allowed_groups_names?: string[];
  denied_emojis?: string[];
  tos_url?: string | null;
  privacy_policy_url?: string | null;
  system_user_avatar_template?: string;
  lazy_load_categories?: true;
  valid_flag_applies_to_types?: string[];
  full_name_required_for_signup: boolean;
  full_name_visible_in_signup: boolean;
  admin_config_login_routes?: string[];
  email_configured?: boolean;
  upcoming_changes_with_css: string[];
  permanent_upcoming_change_names?: string[];
  access_control?: {
    mandatory_acl: Record<string, SiteAclEntry[]>;
    banned_acl: Record<string, SiteAclEntry[]>;
  };
  category_types?: SiteCategoryType[];
  archetypes?: Archetype[];
  user_fields: (EmberObject & SiteUserField)[];
  auth_providers: SiteAuthProvider[];
  postActionByIdLookup?: EmberObject;
  topicFlagByIdLookup?: EmberObject;
  /** Ids of the categories loaded on demand when the site lazy-loads categories. */
  loadedCategoryIds?: Set<number>;
  narrowDesktopView?: boolean;
  banner?: SiteBanner | null;
  /** The top tags of the current category's topic list. */
  category_top_tags?: SiteTopTag[];
  is_readonly?: boolean;
  isStaffWritesOnly?: boolean;
}

/** The site's settings, as `RestModel` types them. */
type SiteSettings = RestModel["siteSettings"];

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging, @typescript-eslint/no-empty-object-type
export default interface Site extends SiteFields {}

@singleton
// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class Site extends RestModel {
  /** The site, created on first use. Added by `@singleton`. */
  declare static current: () => Site;

  /**
   * Reads a site property, or sets it when a value is given. Added by
   * `@singleton`. Any other string, such as a property path, reads or sets an
   * untyped value.
   */
  declare static currentProp: {
    <K extends keyof Site>(property: K): Site[K];
    <K extends keyof Site>(property: K, value: Site[K]): Site[K];
    <P extends string>(
      property: P extends keyof Site ? never : P,
      value?: unknown
    ): unknown;
  };

  /** Replaces the site returned by `current`. Added by `@singleton`. */
  declare static resetCurrent: <T extends Site | null | undefined = undefined>(
    value?: T
  ) => T;

  static createCurrent(): Site {
    const store = getOwnerWithFallback(this).lookup(
      "service:store"
    ) as StoreService;
    const siteAttributes = PreloadStore.get("site");
    siteAttributes["isReadOnly"] = PreloadStore.get("isReadOnly");
    siteAttributes["isStaffWritesOnly"] = PreloadStore.get("isStaffWritesOnly");
    return store.createRecord("site", siteAttributes);
  }

  static override create<C extends RestModelClass>(
    this: C,
    ...args: [attrs?: RestModelAttrs<InstanceType<C>>]
  ): InstanceType<C> {
    // The server's payload is still raw here; the blocks below replace its
    // arrays with model instances and its trust levels with `trustLevels`.
    const result = super.create.apply(this, args) as unknown as Site & {
      trust_levels?: Record<string, number>;
    };

    if (result.categories) {
      result.categories = (
        result.categories as unknown as RestModelAttrs<Category>[]
      ).map((c) => {
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
      result.post_action_types = (
        result.post_action_types as unknown as { id: number }[]
      ).map((p) => {
        const actionType = PostActionType.create(p);
        result.postActionByIdLookup!.set("action" + p.id, actionType);
        return actionType;
      });
    }

    if (result.topic_flag_types) {
      result.topicFlagByIdLookup = EmberObject.create();
      result.topic_flag_types = (
        result.topic_flag_types as unknown as { id: number }[]
      ).map((p) => {
        const actionType = PostActionType.create(p);
        result.topicFlagByIdLookup!.set("action" + p.id, actionType);
        return actionType;
      });
    }

    if (result.archetypes) {
      result.archetypes = (
        result.archetypes as unknown as { site?: Site }[]
      ).map((a) => {
        a.site = result;
        // TODO(typescript-pending): RestCompatModel.create is untyped; remove when it returns the subclass.
        return Archetype.create(a) as Archetype;
      });
    }

    if (result.user_fields) {
      result.user_fields = (result.user_fields as SiteUserField[]).map(
        (uf) => EmberObject.create(uf as object) as EmberObject & SiteUserField
      );
    }

    return result as unknown as InstanceType<C>;
  }

  @service declare siteSettings: SiteSettings;
  @service declare capabilities: CapabilitiesService;

  @tracked topicCountDesc: string[] = ["topic_count:desc"];
  @autoTrackedArray categories: Category[] = [];
  @autoTrackedArray groups: SiteGroup[] = [];

  #siteInitialized: boolean | undefined = false;

  @computed("is_readonly")
  get isReadOnly(): boolean | undefined {
    return this.is_readonly;
  }

  set isReadOnly(value: boolean | undefined) {
    set(this, "is_readonly", value);
  }

  get categoriesByCount(): Category[] {
    return arraySortedByProperties(this.categories, this.topicCountDesc);
  }

  get groupsById(): Record<number, SiteGroupLookupEntry> {
    const map: Record<number, SiteGroupLookupEntry> = {};
    Object.values(AUTO_GROUPS).forEach((g) => (map[g.id] = g));
    this.groups?.forEach((g) => (map[g.id] = g));
    return map;
  }

  @dependentKeyCompat
  get desktopView(): boolean {
    return !this.mobileView;
  }

  @dependentKeyCompat
  get mobileView(): boolean {
    this.#siteInitialized ||= (
      getOwnerWithFallback(this).lookup("-application-instance:main") as
        | { _booted?: boolean }
        | undefined
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

    return withSilencedDeprecations(
      "discourse.static-viewport-initialization",
      () => !this.capabilities.viewport.sm
    );
  }

  @dependentKeyCompat
  get isMobileDevice(): boolean {
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
    const map = new Map<Category["parent_category_id"], Category[]>();
    for (const category of this.categories) {
      const siblings = map.get(category.parent_category_id) || [];
      siblings.push(category);
      map.set(category.parent_category_id, siblings);
    }
    return map;
  }

  @computed("notification_types")
  get notificationLookup() {
    const result: string[] = [];
    Object.keys(this.notification_types!).forEach(
      (k) => (result[this.notification_types![k]] = k)
    );
    return result;
  }

  @computed("post_action_types.[]")
  get flagTypes(): PostActionType[] {
    const postActionTypes = this.post_action_types;
    if (!postActionTypes) {
      return [];
    }
    return trackedArray(postActionTypes.filter((type) => type.is_flag));
  }

  // Sort subcategories under parents
  @cached
  get sortedCategories(): Category[] {
    return Category.sortCategories(this.categoriesByCount);
  }

  // Returns it in the correct order, by setting
  @computed("categories.[]")
  get categoriesList(): Category[] {
    return this.siteSettings.fixed_category_positions
      ? this.categories
      : this.sortedCategories;
  }

  @computed("categories.[]", "categories.@each.notification_level")
  get trackedCategoriesList(): Category[] {
    const trackedCategories: Category[] = [];

    for (const category of this.categories) {
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

  get topTags(): Tag[] {
    return this.#transformTags(this.top_tags);
  }

  get categoryTopTags(): Tag[] {
    return this.#transformTags(this.category_top_tags);
  }

  groupName(groupId: number | string): string | null {
    const group = this.groupsById[groupId as number];
    return group ? group.name : null;
  }

  groupFullName(groupId: number | string): string | null | undefined {
    const group = this.groupsById[groupId as number];
    return group ? group.full_name : null;
  }

  collectUserFields(fields?: SiteUserFieldValues | null) {
    fields = fields || {};

    const siteFields = this.user_fields;

    if (!isEmpty(siteFields)) {
      return siteFields.map((f) => {
        let value:
          | SiteUserFieldValues[string]
          | TrustedHTML
          | null
          | undefined = fields ? fields[f.id.toString()] : null;
        value = value || trustHTML("&mdash;");
        return { name: f.name, value };
      });
    }
    return [];
  }

  postActionTypeById(id: number | string): PostActionType | undefined {
    return this.get("postActionByIdLookup.action" + id) as
      | PostActionType
      | undefined;
  }

  topicFlagTypeById(id: number | string): PostActionType | undefined {
    return this.get("topicFlagByIdLookup.action" + id) as
      | PostActionType
      | undefined;
  }

  removeCategory(id: number | string): void {
    const categories = this.categories;
    const existingCategory = categories.find((c) => c.id === id);
    if (existingCategory) {
      removeValueFromArray(categories, existingCategory);
    }
  }

  updateCategory(newCategory: CategoryFields): Category;
  updateCategory(
    newCategory: CategoryFields & { [key: string]: unknown }
  ): Category;

  updateCategory(
    newCategory: (CategoryFields & { [key: string]: unknown }) | Category
  ): Category {
    if (newCategory instanceof Category) {
      throw new Error(
        "updateCategory should be passed a pojo, not a category model instance"
      );
    }

    const categories = this.categories;
    const categoryId = get(newCategory, "id");
    const existingCategory = categories.find((c) => c.id === categoryId);

    if (newCategory.permission === null) {
      delete newCategory.permission;
    }

    if (newCategory.has_children == null) {
      delete newCategory.has_children;
    }

    if (existingCategory) {
      existingCategory.setProperties(newCategory);
      existingCategory.setupCategoryTypes();
      return existingCategory;
    } else {
      newCategory = this.store.createRecord("category", newCategory);
      categories.push(newCategory);
      return newCategory;
    }
  }

  #transformTags(tags: SiteTopTag[] | undefined): Tag[] {
    if (!tags) {
      return [];
    }
    // TODO(typescript-pending): the store registry has no tag entry; remove when it does.
    return tags.map(
      (tag) =>
        this.store.createRecord(
          "tag",
          tag as unknown as RestModelAttrs<RestModel>
        ) as unknown as Tag
    );
  }
}

/** The deprecated global namespace, present only on pages that still define it. */
declare const Discourse: object | undefined;

if (typeof Discourse !== "undefined") {
  let warned = false;

  Object.defineProperty(Discourse, "Site", {
    get() {
      if (!warned) {
        deprecated("Import the Site class instead of using Discourse.Site", {
          since: "2.4.0",
          id: "discourse.global.site",
        });
        warned = true;
      }
      return Site;
    },
  });
}
