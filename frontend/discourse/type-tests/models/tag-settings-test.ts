import { expectTypeOf } from "expect-type";
import RestCompatModel from "discourse/data/rest-compat";
import type Category from "discourse/models/category";
import TagSettings, {
  type TagSettingsFields,
} from "discourse/models/tag-settings";
import type {
  default as StoreService,
  ModelFor,
} from "discourse/services/store";

declare const store: StoreService;
declare const tagSettings: TagSettings;

/** A `TagLocalizationSerializer` row. */
interface ExpectedTagLocalization {
  id: number;
  tag_id: number;
  locale: string;
  name: string;
  description: string | null;
  description_cooked: string | null;
}

/** `TagSettingsSerializer` fields, as the store hydrates them. */
interface ExpectedTagSettingsFields {
  id: number;
  name: string;
  /** The column is nullable. */
  locale: string | null;
  slug: string;
  description: string | null;
  description_cooked: string | null;
  synonyms: { id: number; name: string }[];
  /** Sent to admins, or when tags are listed by group. */
  tag_group_names?: string[];
  tag_groups?: { id: number; name: string }[];
  category_restricted: boolean;
  can_edit: boolean;
  can_admin: boolean;
  /** Hydrated from the category sideload. */
  categories: Category[];
  /** Sent only with content localization. */
  localizations?: ExpectedTagLocalization[];
}

declare module "discourse/models/tag-settings" {
  interface TagSettingsFields {
    type_test_plugin_flag?: boolean;
  }
}

expectTypeOf(tagSettings).toExtend<RestCompatModel>();
expectTypeOf(tagSettings).not.toBeAny();
expectTypeOf<ModelFor<"tag-settings">>().toEqualTypeOf<TagSettings>();
expectTypeOf<ModelFor<"tagSettings">>().toEqualTypeOf<TagSettings>();
expectTypeOf(
  store.find("tag-settings", 1)
).resolves.toEqualTypeOf<TagSettings>();

/* Fields. */

expectTypeOf<
  Omit<TagSettingsFields, "type_test_plugin_flag">
>().toEqualTypeOf<ExpectedTagSettingsFields>();
expectTypeOf<
  Pick<TagSettings, keyof ExpectedTagSettingsFields>
>().toEqualTypeOf<ExpectedTagSettingsFields>();
expectTypeOf(tagSettings.type_test_plugin_flag).toEqualTypeOf<
  boolean | undefined
>();
// The settings form applies the saved `tag_settings` payload back onto the record.
tagSettings.setProperties({ name: "renamed", slug: "renamed" });
// @ts-expect-error names are strings
tagSettings.setProperties({ name: 1 });
// @ts-expect-error synonym ids are numbers
tagSettings.setProperties({ synonyms: [{ id: "1", name: "alias" }] });
// Saving applies the response's raw category ids.
expectTypeOf(tagSettings.category_ids).toEqualTypeOf<number[] | undefined>();
// The settings serializer sends no topic count.
expectTypeOf(tagSettings).not.toHaveProperty("topic_count");

/** Audit only what TagSettings adds over its base. */
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
expectTypeOf<OwnAnyKeys<TagSettings, RestCompatModel>>().toEqualTypeOf<never>();
