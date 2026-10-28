import type EmberObject from "@ember/object";
import { expectTypeOf } from "expect-type";
import Category, {
  type CategoryAllowedTag,
  type CategoryFields,
  type CategoryLocalization,
  type CategoryPermission,
  type CategoryPostingReviewMode,
  type CategoryRequiredTagGroup,
  type CategorySetting,
  type CategoryStyle,
  type CategoryTypeMetadata,
  type CategoryUpload,
} from "discourse/models/category";
import type RestModel from "discourse/models/rest";
import type {
  default as StoreService,
  ModelFor,
} from "discourse/services/store";

// Independent of the model's own definitions, so a wrong export cannot hide here.
type ExpectedStyle = "square" | "icon" | "emoji";
type ExpectedReviewMode =
  | "no_one"
  | "everyone"
  | "everyone_except"
  | "no_one_except";

interface ExpectedPermission {
  group_name: string;
  permission_type: number | null;
  group_id: number;
}

interface ExpectedAllowedTag {
  id: number | string;
  name: string;
  slug?: string;
}

interface ExpectedRequiredTagGroup {
  min_count: number;
  name?: string | null;
}

type ExpectedUpload =
  | { id: number; url: string; width?: number | null; height?: number | null }
  | { id: null; url: null };

interface ExpectedSetting {
  auto_bump_cooldown_days?: number | null;
  num_auto_bump_daily?: number | null;
  require_reply_approval?: boolean;
  require_topic_approval?: boolean;
  nested_replies_default?: boolean;
  topic_posting_review_mode?: ExpectedReviewMode;
  reply_posting_review_mode?: ExpectedReviewMode;
}

interface ExpectedLocalization {
  id: number;
  locale: string;
  name: string;
  description: string | null;
}

expectTypeOf<CategoryStyle>().toEqualTypeOf<ExpectedStyle>();
expectTypeOf<CategoryPostingReviewMode>().toEqualTypeOf<ExpectedReviewMode>();
expectTypeOf<CategoryPermission>().toEqualTypeOf<ExpectedPermission>();
expectTypeOf<CategoryAllowedTag>().toEqualTypeOf<ExpectedAllowedTag>();
expectTypeOf<CategoryRequiredTagGroup>().toEqualTypeOf<ExpectedRequiredTagGroup>();
expectTypeOf<CategoryUpload>().toEqualTypeOf<ExpectedUpload>();
expectTypeOf<CategorySetting>().toEqualTypeOf<ExpectedSetting>();
expectTypeOf<CategoryLocalization>().toEqualTypeOf<ExpectedLocalization>();

// Category type metadata, as `Categories::Types::Base#metadata` builds it.
declare const typeMetadata: CategoryTypeMetadata;
expectTypeOf(typeMetadata.id).toEqualTypeOf<string>();
expectTypeOf(typeMetadata.name).toEqualTypeOf<string>();
expectTypeOf(typeMetadata.title).toEqualTypeOf<string>();
expectTypeOf(typeMetadata.available).toEqualTypeOf<boolean>();
expectTypeOf(typeMetadata.visible).toEqualTypeOf<boolean>();
// The new-category route stores a projection without these two.
expectTypeOf(typeMetadata.description).toEqualTypeOf<string | undefined>();
expectTypeOf(typeMetadata.icon).toEqualTypeOf<string | null | undefined>();
expectTypeOf(typeMetadata.configuration_schema).not.toBeAny();
expectTypeOf(typeMetadata["type_specific_extra"]).toEqualTypeOf<unknown>();

// Every data field core sends or assigns, with its presence and nullability.
interface ExpectedCategoryFields {
  id: number;
  name: string;
  slug: string | null;
  color: string;
  text_color: string;
  style_type: ExpectedStyle;
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
  uploaded_logo?: ExpectedUpload | null;
  uploaded_logo_dark?: ExpectedUpload | null;
  uploaded_background?: ExpectedUpload | null;
  uploaded_background_dark?: ExpectedUpload | null;
  allow_global_tags?: boolean;
  read_only_banner?: string | null;
  form_template_ids?: number[];
  category_types?: Record<string, CategoryTypeMetadata>;
  locale?: string | null;
  available_groups?: string[];
  allowed_tags?: (ExpectedAllowedTag | string)[];
  allowed_tag_groups?: string[];
  auto_close_hours?: number | null;
  auto_close_based_on_last_post?: boolean | null;
  group_permissions?: ExpectedPermission[];
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
  category_setting?: ExpectedSetting | null;
  category_localizations?: ExpectedLocalization[];
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

declare module "discourse/models/category" {
  interface CategoryFields {
    type_test_plugin_flag?: boolean;
  }
}

expectTypeOf<
  Omit<CategoryFields, "type_test_plugin_flag">
>().toEqualTypeOf<ExpectedCategoryFields>();

declare const category: Category;

// Data fields reach instances; decorated class fields keep these types.
expectTypeOf<
  Pick<Category, keyof ExpectedCategoryFields>
>().toEqualTypeOf<ExpectedCategoryFields>();
expectTypeOf(category.type_test_plugin_flag).toEqualTypeOf<
  boolean | undefined
>();

// Class fields the model declares itself.
expectTypeOf(category.permissions).toEqualTypeOf<
  ExpectedPermission[] | undefined
>();
expectTypeOf(category.categoryTypes).toEqualTypeOf<
  Record<string, CategoryTypeMetadata>
>();
expectTypeOf(category.styleType).toEqualTypeOf<ExpectedStyle | undefined>();
expectTypeOf(category.localizations).not.toBeAny();

// Category adds no member that is, or returns, `any`, on instances or on the
// class. Ember's own `_super` and `metaForProperty` are excluded.
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
expectTypeOf<OwnAnyKeys<Category, EmberObject>>().toEqualTypeOf<never>();
// The inherited `create` is generic in `this`, and inferring its return through a
// conditional type gives `any` even though calls resolve to Category; its result
// is asserted directly below.
expectTypeOf<
  Exclude<OwnAnyKeys<typeof Category, typeof EmberObject>, "create">
>().toEqualTypeOf<never>();

// Accessors with exact types.
expectTypeOf(category.parentCategory).toEqualTypeOf<Category | undefined>();
expectTypeOf(category.subcategories).toEqualTypeOf<Category[]>();
expectTypeOf(category.ancestors).toEqualTypeOf<Category[]>();
expectTypeOf(category.predecessors).toEqualTypeOf<Category[]>();
expectTypeOf(category.descendants).toEqualTypeOf<Category[]>();
expectTypeOf(category.level).toEqualTypeOf<number>();
expectTypeOf(category.path).toEqualTypeOf<string>();
expectTypeOf(category.url).toEqualTypeOf<string>();
expectTypeOf(category.fullSlug).toEqualTypeOf<string>();
expectTypeOf(category.nameLower).toEqualTypeOf<string>();
expectTypeOf(category.isUncategorizedCategory).toEqualTypeOf<boolean>();
expectTypeOf(category.canCreateTopic).toEqualTypeOf<boolean>();
// Transient preview categories have no topic count.
expectTypeOf(category.totalTopicCount).toEqualTypeOf<number | undefined>();

// Static lookups.
expectTypeOf(Category.findById(1)).toEqualTypeOf<Category | undefined>();
expectTypeOf(Category.findById("1")).toEqualTypeOf<Category | undefined>();
expectTypeOf(Category.list()).toEqualTypeOf<Category[]>();
// The server splits the slug path on "/", so callers pass one string.
expectTypeOf(
  Category.asyncFindBySlugPath("parent/child")
).resolves.toEqualTypeOf<Category | undefined>();
// @ts-expect-error the slug path is a single slash-separated string
Category.asyncFindBySlugPath(["parent", "child"]);
// The result shape follows `includeAncestors`.
expectTypeOf(Category.asyncSearch("x")).resolves.toEqualTypeOf<Category[]>();
expectTypeOf(
  Category.asyncSearch("x", { includeAncestors: true })
).resolves.toEqualTypeOf<{
  ancestors: Category[];
  categories: Category[];
  categoriesCount: number;
}>();

// `destroy` deletes through the API and resolves with its response.
expectTypeOf(category.destroy()).resolves.not.toBeAny();
expectTypeOf(category.destroy).returns.toExtend<Promise<unknown>>();
// Category is a proper RestModel subclass, so the typed `create` applies.
expectTypeOf(category).toExtend<RestModel>();
expectTypeOf(Category.create()).toEqualTypeOf<Category>();
expectTypeOf(
  Category.create({ id: 1, name: "Bugs", extra_server_field: true })
).toEqualTypeOf<Category>();
// @ts-expect-error a declared field keeps its type in create attrs
Category.create({ color: 1 });
// @ts-expect-error can_delete is only ever sent as true
Category.create({ can_delete: false });
// @ts-expect-error style_type is one of the three styles
Category.create({ style_type: "circle" });

// The store registry maps "category" to Category.
declare const store: StoreService;
expectTypeOf<ModelFor<"category">>().toEqualTypeOf<Category>();
expectTypeOf(store.createRecord("category")).toEqualTypeOf<Category>();

// New categories are built without an id until they are saved.
expectTypeOf(Category.create({ name: "Draft" })).toEqualTypeOf<Category>();
expectTypeOf(
  store.createRecord("category", { name: "Draft" })
).toEqualTypeOf<Category>();
