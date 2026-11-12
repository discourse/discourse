import { expectTypeOf } from "expect-type";
import RestCompatModel from "discourse/data/rest-compat";
import type Category from "discourse/models/category";
import type Tag from "discourse/models/tag";
import TagInfo, { type TagInfoFields } from "discourse/models/tag-info";
import type {
  default as StoreService,
  ModelFor,
} from "discourse/services/store";

declare const store: StoreService;
declare const tagInfo: TagInfo;

/** A `TagLocalizationSerializer` row. */
interface ExpectedTagLocalization {
  id: number;
  tag_id: number;
  locale: string;
  name: string;
  description: string | null;
  description_cooked: string | null;
}

/** A `TagsController.tag_counts_json` row. */
interface ExpectedTagCountRow {
  id: number;
  text: string;
  name: string;
  slug: string;
  description: string | null;
  count: number;
  pm_only: boolean;
  /** Null unless the tag is a synonym whose target the viewer can see. */
  target_tag: { id: number; name: string; slug: string } | null;
  /** Sent only when the viewer can tag personal messages and PM tag counts are shown. */
  pm_count?: number;
}

/** `DetailedTagSerializer` fields, as the store hydrates them. */
interface ExpectedTagInfoFields {
  id: number;
  name: string;
  slug: string;
  description: string | null;
  description_cooked: string | null;
  topic_count: number;
  staff: boolean;
  /** Sent only with content localization, when the tag's localizations are preloaded. */
  localizations?: ExpectedTagLocalization[];
  /** The tag list wraps each row in Tag after loading. */
  synonyms: (ExpectedTagCountRow | Tag)[];
  /** Sent to admins, or when tags are listed by group. */
  tag_group_names?: string[];
  category_restricted: boolean;
  /** Hydrated from the category sideload. */
  categories: Category[];
}

declare module "discourse/models/tag-info" {
  interface TagInfoFields {
    type_test_plugin_flag?: boolean;
  }
}

expectTypeOf(tagInfo).toExtend<RestCompatModel>();
expectTypeOf(tagInfo).not.toBeAny();
expectTypeOf<ModelFor<"tag-info">>().toEqualTypeOf<TagInfo>();
expectTypeOf<ModelFor<"tagInfo">>().toEqualTypeOf<TagInfo>();
expectTypeOf(store.find("tag-info", 1)).resolves.toEqualTypeOf<TagInfo>();
expectTypeOf(
  store.find("tag-info", "tag-name")
).resolves.toEqualTypeOf<TagInfo>();

/* Fields. */

expectTypeOf<
  Omit<TagInfoFields, "type_test_plugin_flag">
>().toEqualTypeOf<ExpectedTagInfoFields>();
expectTypeOf<
  Pick<TagInfo, keyof ExpectedTagInfoFields>
>().toEqualTypeOf<ExpectedTagInfoFields>();
expectTypeOf(tagInfo.type_test_plugin_flag).toEqualTypeOf<
  boolean | undefined
>();
declare const tag: Tag;
declare const countRow: ExpectedTagCountRow;
tagInfo.synonyms = [tag];
tagInfo.synonyms = [countRow];
// @ts-expect-error synonyms are tag rows or tags, not names
tagInfo.synonyms = ["synonym"];
// Category ids stay on the record when the sideload has no matching category.
expectTypeOf(tagInfo.category_ids).toEqualTypeOf<number[] | undefined>();
// @ts-expect-error category ids are numbers
tagInfo.category_ids = ["1"];

/** Audit only what TagInfo adds over its base. */
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
expectTypeOf<OwnAnyKeys<TagInfo, RestCompatModel>>().toEqualTypeOf<never>();
