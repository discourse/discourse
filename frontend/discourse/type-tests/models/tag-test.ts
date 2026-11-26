import { expectTypeOf } from "expect-type";
import RestCompatModel from "discourse/data/rest-compat";
import type ResultSet from "discourse/models/result-set";
import type { default as Site, SiteTopTag } from "discourse/models/site";
import Tag, { type TagFields } from "discourse/models/tag";
import type {
  default as StoreService,
  ModelFor,
} from "discourse/services/store";

declare const store: StoreService;
declare const tag: Tag;
declare const site: Site;

/** A `TagLocalizationSerializer` row. */
interface ExpectedTagLocalization {
  id: number;
  tag_id: number;
  locale: string;
  name: string;
  description: string | null;
  description_cooked: string | null;
}

/**
 * Fields across the tag payloads: the tag list's count rows, the site's top
 * tags, and `TagSerializer` rows, which themes wrap directly. Only `name` is
 * always present; the tag page builds a placeholder from the URL before loading.
 */
interface ExpectedTagFields {
  /** Absent on tags built from a name only; null on the tag page when the URL names no tag id. */
  id?: number | null;
  name: string;
  slug?: string;
  description?: string | null;
  /** `TagSerializer` rows only. */
  description_cooked?: string | null;
  /** Tag list rows repeat the name here. */
  text?: string;
  /** Tag list rows only: the visible topic count. */
  count?: number;
  /** Sent only when the viewer can tag personal messages and PM tag counts are shown. */
  pm_count?: number;
  pm_only?: boolean;
  /** `TagSerializer` rows only. */
  topic_count?: number;
  staff?: boolean;
  /** Null unless the tag is a synonym whose target the viewer can see. */
  target_tag?: { id: number; name: string; slug: string } | null;
  /** Sent only with content localization, when localizations are preloaded. */
  localizations?: ExpectedTagLocalization[];
}

declare module "discourse/models/tag" {
  interface TagFields {
    type_test_plugin_flag?: boolean;
  }
}

expectTypeOf(tag).toExtend<RestCompatModel>();
expectTypeOf(tag).not.toBeAny();
expectTypeOf<ModelFor<"tag">>().toEqualTypeOf<Tag>();
expectTypeOf(store.createRecord("tag", { name: "x" })).toEqualTypeOf<Tag>();
declare const topTag: SiteTopTag;
expectTypeOf(store.createRecord("tag", topTag)).toEqualTypeOf<Tag>();
// @ts-expect-error counts are numbers
store.createRecord("tag", { count: "1" });
expectTypeOf(store.findAll("tag")).resolves.toEqualTypeOf<
  ResultSet<Tag> | undefined
>();

/* Fields. */

expectTypeOf<
  Omit<TagFields, "type_test_plugin_flag">
>().toEqualTypeOf<ExpectedTagFields>();
expectTypeOf<
  Pick<Tag, keyof ExpectedTagFields>
>().toEqualTypeOf<ExpectedTagFields>();
expectTypeOf(tag.type_test_plugin_flag).toEqualTypeOf<boolean | undefined>();
tag.setProperties({ id: 1, name: "x", slug: "x", staff: false });
// @ts-expect-error tag ids are numbers
tag.setProperties({ id: "1" });
// The store attaches `extras` to the result set, not to each tag.
expectTypeOf(tag).not.toHaveProperty("extras");

/* Derived state. */

expectTypeOf(tag.pmOnly).toEqualTypeOf<boolean | undefined>();
expectTypeOf(tag.url).toEqualTypeOf<string>();
expectTypeOf(tag.totalCount).toEqualTypeOf<number | undefined>();
expectTypeOf(tag.searchContext).toEqualTypeOf<{
  type: "tag";
  id: number | null | undefined;
  tag: Tag;
  name: string;
}>();

/** Audit only what Tag adds over its base. */
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
expectTypeOf<OwnAnyKeys<Tag, RestCompatModel>>().toEqualTypeOf<never>();

/* Construction. */

expectTypeOf(Tag.create({ name: "x" })).toEqualTypeOf<Tag>();
expectTypeOf(
  Tag.create({ id: 1, name: "x", slug: "x", count: 2, pm_only: false })
).toEqualTypeOf<Tag>();
// @ts-expect-error counts are numbers
Tag.create({ count: "2" });
expectTypeOf(Tag.create({ id: null, name: "legacy" })).toEqualTypeOf<Tag>();
// @ts-expect-error targets are complete tag references
Tag.create({ target_tag: { name: "target" } });
declare const localization: ExpectedTagLocalization;
// @ts-expect-error localization descriptions are nullable strings
Tag.create({ localizations: [{ ...localization, description: 1 }] });

/* Consumers. */

expectTypeOf(site.topTags).toEqualTypeOf<Tag[]>();
expectTypeOf(site.topTags[0].slug).toEqualTypeOf<string | undefined>();
