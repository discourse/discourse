import type EmberObject from "@ember/object";
import type { TrustedHTML } from "@ember/template";
import { expectTypeOf } from "expect-type";
import type Archetype from "discourse/models/archetype";
import type Category from "discourse/models/category";
import type PostActionType from "discourse/models/post-action-type";
import type RestModel from "discourse/models/rest";
import Site, { type SiteFields } from "discourse/models/site";
import type Tag from "discourse/models/tag";
import type TrustLevel from "discourse/models/trust-level";
import type {
  default as StoreService,
  ModelFor,
} from "discourse/services/store";

/** Independent of Site's exports: SiteSerializer#groups always emits these keys. */
interface ExpectedGroup {
  id: number;
  name: string;
  full_name: string;
  display_name: string;
  flair_url: string | null;
  flair_bg_color: string | null;
  flair_color: string | null;
  automatic: boolean;
}

/** AUTO_GROUPS supplies only id, name and automatic before server groups overwrite it. */
type ExpectedGroupLookupEntry = Pick<
  ExpectedGroup,
  "id" | "name" | "automatic"
> &
  Partial<Omit<ExpectedGroup, "id" | "name" | "automatic">>;

/** UserFieldSerializer, UserField's enums and the nullable position column. */
interface ExpectedUserField {
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

/** AuthProviderSerializer emits unset AuthProvider accessors as null, not missing keys. */
interface ExpectedAuthProvider {
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

interface ExpectedTopTag {
  id: number;
  name: string;
  slug: string;
}

interface ExpectedSidebarTag extends ExpectedTopTag {
  description: string | null;
  pm_only: boolean;
}

/** SidebarSectionSerializer does not request link localizations or can_localize. */
interface ExpectedSidebarSection {
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

interface ExpectedUserTheme {
  theme_id: number;
  name: string;
  default: boolean;
  color_scheme_id: number | null;
  dark_color_scheme_id: number | null;
  only_theme_color_schemes: boolean;
}

/** default_hex can miss a custom color in the base palette; is_dark? can return nil. */
interface ExpectedColor {
  name: string;
  hex: string;
  default_hex: string | null;
  is_advanced: boolean;
}

interface ExpectedSelectableColorScheme {
  id: number;
  name: string;
  is_dark: boolean | null;
  theme_id: number | null;
  colors: ExpectedColor[];
}

interface ExpectedColorScheme extends ExpectedSelectableColorScheme {
  is_base: boolean | null;
  base_scheme_id: number | null;
  theme_name: string | null;
  user_selectable: boolean;
  is_builtin_default: boolean | null;
}

/** WordWatcher#words_for_action compacts replacement and only includes truthy html. */
interface ExpectedWatchedWord {
  word: string;
  replacement?: string;
  case_sensitive: boolean;
  html?: true;
}

interface ExpectedAclEntry {
  type: "group" | "user";
  id: number;
  permission: string;
}

/** Categories::Types::Base#metadata and #resolved_configuration_schema. */
interface ExpectedCategoryType {
  id: string;
  name: string;
  title: string;
  description: string;
  icon: string | null;
  available: boolean;
  visible: boolean;
  configuration_schema: Record<string, Record<string, unknown>[]>;
  [key: string]: unknown;
}

/** The banner initializer also creates an empty EmberObject when there is no banner. */
type ExpectedBanner = EmberObject & {
  html?: string;
  key?: number;
  url?: string;
};

/**
 * Instance data, after Site.create's model wrapping and trust_levels deletion.
 * Site.json_for's login-required anonymous branch makes most server fields optional.
 * categories and groups instead have class-level empty-array defaults.
 */
interface ExpectedSiteFields {
  default_archetype?: string;
  notification_types?: Record<string, number>;
  post_types?: Record<string, number>;
  user_tips?: Record<string, number>;
  trustLevels?: TrustLevel[];
  groups: ExpectedGroup[];
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
  top_tags?: ExpectedTopTag[];
  navigation_menu_site_top_tags?: ExpectedSidebarTag[];
  can_associate_groups?: boolean;
  wizard_required?: true;
  topic_featured_link_allowed_category_ids?: number[];
  user_themes?: ExpectedUserTheme[];
  user_color_schemes?: ExpectedSelectableColorScheme[];
  default_light_color_scheme?: ExpectedColorScheme | null;
  default_dark_color_scheme?: ExpectedColorScheme | null;
  censored_regexp?: Record<string, { case_sensitive: boolean }>[];
  shared_drafts_category_id?: number;
  custom_emoji_translation?: Record<string, string>;
  watched_words_replace?: Record<string, ExpectedWatchedWord> | null;
  watched_words_link?: Record<string, ExpectedWatchedWord> | null;
  categories: Category[];
  markdown_additional_options?: Record<string, unknown>;
  hashtag_configurations?: Record<string, string[]>;
  hashtag_icons?: Record<string, string>;
  anonymous_default_navigation_menu_tags?: ExpectedSidebarTag[];
  anonymous_sidebar_sections?: ExpectedSidebarSection[];
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
    mandatory_acl: Record<string, ExpectedAclEntry[]>;
    banned_acl: Record<string, ExpectedAclEntry[]>;
  };
  category_types?: ExpectedCategoryType[];
  archetypes?: Archetype[];
  user_fields: (EmberObject & ExpectedUserField)[];
  auth_providers: ExpectedAuthProvider[];
  postActionByIdLookup?: EmberObject;
  topicFlagByIdLookup?: EmberObject;
  loadedCategoryIds?: Set<number>;
  narrowDesktopView?: boolean;
  banner?: ExpectedBanner | null;
  category_top_tags?: ExpectedTopTag[];
  is_readonly?: boolean;
  isStaffWritesOnly?: boolean;
}

declare module "discourse/models/site" {
  interface SiteFields {
    type_test_plugin_flag?: boolean;
  }
}

expectTypeOf<
  Omit<SiteFields, "type_test_plugin_flag">
>().toEqualTypeOf<ExpectedSiteFields>();

declare const site: Site;
declare const store: StoreService;
declare const fields: ExpectedSiteFields;

expectTypeOf<
  Pick<Site, keyof ExpectedSiteFields>
>().toEqualTypeOf<ExpectedSiteFields>();
expectTypeOf(site.type_test_plugin_flag).toEqualTypeOf<boolean | undefined>();

/** Audit only what Site adds; Ember's own _super and metaForProperty are excluded. */
type AnyKeys<T> = {
  [K in keyof T]-?: 0 extends 1 & T[K] ? K : never;
}[keyof T];
type AnyReturnKeys<T> = {
  [K in keyof T]-?: T[K] extends (...args: never) => infer R
    ? 0 extends 1 & R
      ? K
      : never
    : never;
}[keyof T];
type OwnAnyKeys<T, Base> = Exclude<
  AnyKeys<T> | AnyReturnKeys<T>,
  AnyKeys<Base> | AnyReturnKeys<Base>
>;
expectTypeOf<OwnAnyKeys<Site, EmberObject>>().toEqualTypeOf<never>();
// The inherited create is generic in this, and inferring its return through a
// conditional type gives any even though calls resolve to Site; assert calls below.
expectTypeOf<
  Exclude<OwnAnyKeys<typeof Site, typeof EmberObject>, "create">
>().toEqualTypeOf<never>();

expectTypeOf(site.topicCountDesc).toEqualTypeOf<string[]>();
expectTypeOf(site.isReadOnly).toEqualTypeOf<boolean | undefined>();
expectTypeOf(site.desktopView).toEqualTypeOf<boolean>();
expectTypeOf(site.mobileView).toEqualTypeOf<boolean>();
expectTypeOf(site.isMobileDevice).toEqualTypeOf<boolean>();
expectTypeOf(site.categoriesByCount).toEqualTypeOf<Category[]>();
expectTypeOf(site.categoriesById).toEqualTypeOf<Map<number, Category>>();
expectTypeOf(site.categoriesByParentId).toEqualTypeOf<
  Map<number | null | undefined, Category[]>
>();
expectTypeOf(site.groupsById).branded.toEqualTypeOf<
  Record<number, ExpectedGroupLookupEntry>
>();
expectTypeOf(site.notificationLookup).toEqualTypeOf<string[]>();
expectTypeOf(site.flagTypes).toEqualTypeOf<PostActionType[]>();
expectTypeOf(site.sortedCategories).toEqualTypeOf<Category[]>();
expectTypeOf(site.categoriesList).toEqualTypeOf<Category[]>();
expectTypeOf(site.trackedCategoriesList).toEqualTypeOf<Category[]>();
expectTypeOf(site.topTags).toEqualTypeOf<Tag[]>();
expectTypeOf(site.categoryTopTags).toEqualTypeOf<Tag[]>();
expectTypeOf(site.groupName(1)).toEqualTypeOf<string | null>();
expectTypeOf(site.groupName("1")).toEqualTypeOf<string | null>();
expectTypeOf(site.groupFullName(1)).toEqualTypeOf<string | null | undefined>();
expectTypeOf(site.postActionTypeById(1)).toEqualTypeOf<
  PostActionType | undefined
>();
expectTypeOf(site.postActionTypeById("1")).toEqualTypeOf<
  PostActionType | undefined
>();
expectTypeOf(site.topicFlagTypeById(1)).toEqualTypeOf<
  PostActionType | undefined
>();
expectTypeOf(site.topicFlagTypeById("1")).toEqualTypeOf<
  PostActionType | undefined
>();
// The smallest payload a saved category arrives with, from the badge serializer.
const badgeCategory = {
  id: 1,
  name: "Bugs",
  slug: "bugs",
  color: "0088CC",
  text_color: "FFFFFF",
  style_type: "square",
  icon: null,
  emoji: null,
  read_restricted: false,
} as const;
expectTypeOf(site.updateCategory(badgeCategory)).toEqualTypeOf<Category>();
expectTypeOf(
  site.updateCategory({ ...badgeCategory, permission: null })
).toEqualTypeOf<Category>();
expectTypeOf(
  site.updateCategory({
    ...badgeCategory,
    has_children: null,
    plugin_payload: true,
  })
).toEqualTypeOf<Category>();
expectTypeOf(site.removeCategory(1)).toEqualTypeOf<void>();
expectTypeOf(site.removeCategory("1")).toEqualTypeOf<void>();

// User#user_fields includes boolean confirmations and multiselect arrays.
// collectUserFields replaces false/null/missing values with a TrustedHTML dash.
expectTypeOf(site.collectUserFields).returns.toEqualTypeOf<
  { name: string; value: string | string[] | true | TrustedHTML }[]
>();
site.collectUserFields({
  "1": "Text",
  "2": ["a", "b"],
  "3": true,
  "4": false,
  "5": null,
});
site.collectUserFields(null);
site.collectUserFields(undefined);

site.isReadOnly = false;
// @ts-expect-error the read-only setter keeps the boolean backing field's type
site.isReadOnly = "false";
// @ts-expect-error category updates use numeric server ids
site.updateCategory({ ...badgeCategory, id: "1" });
// @ts-expect-error category removal accepts an id, not a category payload
site.removeCategory({ id: 1 });

expectTypeOf(Site.current()).toEqualTypeOf<Site>();
expectTypeOf(Site.createCurrent()).toEqualTypeOf<Site>();
expectTypeOf(Site.resetCurrent(site)).toEqualTypeOf<Site>();
expectTypeOf(Site.resetCurrent(null)).toEqualTypeOf<null>();
expectTypeOf(Site.resetCurrent(undefined)).toEqualTypeOf<undefined>();
expectTypeOf(Site.currentProp("categories")).toEqualTypeOf<Category[]>();
expectTypeOf(Site.currentProp("categories", [])).toEqualTypeOf<Category[]>();
expectTypeOf(Site.currentProp("top_tags")).toEqualTypeOf<
  ExpectedTopTag[] | undefined
>();
expectTypeOf(Site.currentProp("isReadOnly", true)).toEqualTypeOf<
  boolean | undefined
>();
expectTypeOf(Site.currentProp("categoriesById")).toEqualTypeOf<
  Map<number, Category>
>();
expectTypeOf(Site.currentProp("type_test_plugin_flag")).toEqualTypeOf<
  boolean | undefined
>();
expectTypeOf(Site.currentProp("type_test_plugin_flag", true)).toEqualTypeOf<
  boolean | undefined
>();
declare const dynamicKey: string;
expectTypeOf(Site.currentProp(dynamicKey)).toEqualTypeOf<unknown>();
expectTypeOf(
  Site.currentProp(dynamicKey, { enabled: true })
).toEqualTypeOf<unknown>();
expectTypeOf(Site.currentProp("a.b")).toEqualTypeOf<unknown>();
expectTypeOf(Site.currentProp("a.b", 1)).toEqualTypeOf<unknown>();
// @ts-expect-error the arbitrary-string overload must not loosen known keys
Site.currentProp("categories", "invalid");
// @ts-expect-error augmentation participates in the known-key setter
Site.currentProp("type_test_plugin_flag", "true");

expectTypeOf(site).toExtend<RestModel>();
expectTypeOf(Site.create()).toEqualTypeOf<Site>();
expectTypeOf(Site.create({ ...fields })).toEqualTypeOf<Site>();
expectTypeOf(
  Site.create({ type_test_plugin_flag: true, undeclared_server_field: 1 })
).toEqualTypeOf<Site>();
// @ts-expect-error transformed category data is an array of Category instances
Site.create({ categories: [1] });
// @ts-expect-error flags are omitted when false, rather than serialized as false
Site.create({ wizard_required: false });
// @ts-expect-error lazy_load_categories is also only sent as true
Site.create({ lazy_load_categories: false });
// @ts-expect-error tags are objects with numeric ids, not tag names
Site.create({ top_tags: ["tag"] });
// @ts-expect-error watched words are regexp-keyed objects, not serialized regexp arrays
Site.create({ watched_words_replace: [] });
// @ts-expect-error plugin augmentation keeps its declared value type in create attrs
Site.create({ type_test_plugin_flag: "true" });

expectTypeOf<ModelFor<"site">>().toEqualTypeOf<Site>();
expectTypeOf(store.createRecord("site")).toEqualTypeOf<Site>();
expectTypeOf(store.createRecord("site", { ...fields })).toEqualTypeOf<Site>();
// @ts-expect-error registry attrs retain the model's declared field types
store.createRecord("site", { filters: "latest" });
// @ts-expect-error registry attrs also retain plugin augmentations
store.createRecord("site", { type_test_plugin_flag: "true" });
