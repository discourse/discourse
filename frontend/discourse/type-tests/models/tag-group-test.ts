import { expectTypeOf } from "expect-type";
import RestCompatModel from "discourse/data/rest-compat";
import TagGroup, { type TagGroupFields } from "discourse/models/tag-group";
import type {
  default as StoreService,
  ModelFor,
} from "discourse/services/store";

declare const store: StoreService;
declare const tagGroup: TagGroup;

/** A tag as `TagGroupSerializer` lists it. */
interface ExpectedTagGroupTag {
  id: number;
  name: string;
  slug: string;
}

/**
 * `TagGroupSerializer` fields. The new tag group route builds a draft with
 * only a name, so the other fields are optional.
 */
interface ExpectedTagGroupFields {
  id: number;
  name: string;
  tags?: ExpectedTagGroupTag[];
  /** Empty, or the single parent tag. */
  parent_tag?: ExpectedTagGroupTag[];
  /** The column is nullable despite its default. */
  one_per_topic?: boolean | null;
  /** Permission types keyed by group id; `0` means everyone. */
  permissions?: Record<string, number>;
}

declare module "discourse/models/tag-group" {
  interface TagGroupFields {
    type_test_plugin_flag?: boolean;
  }
}

expectTypeOf(tagGroup).toExtend<RestCompatModel>();
expectTypeOf(tagGroup).not.toBeAny();
expectTypeOf<ModelFor<"tag-group">>().toEqualTypeOf<TagGroup>();
expectTypeOf<ModelFor<"tagGroup">>().toEqualTypeOf<TagGroup>();
expectTypeOf<ModelFor<"tag_group">>().toEqualTypeOf<TagGroup>();
expectTypeOf(
  store.createRecord("tagGroup", { name: "New group" })
).toEqualTypeOf<TagGroup>();
expectTypeOf(store.find("tagGroup", 1)).resolves.toEqualTypeOf<TagGroup>();

/* Fields. */

expectTypeOf<
  Omit<TagGroupFields, "type_test_plugin_flag">
>().toEqualTypeOf<ExpectedTagGroupFields>();
expectTypeOf<
  Pick<TagGroup, keyof ExpectedTagGroupFields>
>().toEqualTypeOf<ExpectedTagGroupFields>();
expectTypeOf(tagGroup.type_test_plugin_flag).toEqualTypeOf<
  boolean | undefined
>();
tagGroup.permissions = { 0: 1 };
// @ts-expect-error permissions map group ids to permission types
tagGroup.permissions = [1];

/* Derived state. */

expectTypeOf(tagGroup.permissionName).toEqualTypeOf<
  "public" | "visible" | "private"
>();

/** Audit only what TagGroup adds over its base. */
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
expectTypeOf<OwnAnyKeys<TagGroup, RestCompatModel>>().toEqualTypeOf<never>();

/* Construction. */

expectTypeOf(TagGroup.create({ name: "New group" })).toEqualTypeOf<TagGroup>();
// @ts-expect-error tags are tag rows, not names
TagGroup.create({ tags: ["tag"] });
// @ts-expect-error parent tags are arrays
TagGroup.create({ parent_tag: { id: 1, name: "parent", slug: "parent" } });
