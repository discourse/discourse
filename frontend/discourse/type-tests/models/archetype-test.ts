import { expectTypeOf } from "expect-type";
import RestCompatModel from "discourse/data/rest-compat";
import Archetype, { type ArchetypeFields } from "discourse/models/archetype";
import type Composer from "discourse/models/composer";
import type Site from "discourse/models/site";
import type Topic from "discourse/models/topic";

declare const archetype: Archetype;
declare const composer: Composer;
declare const site: Site;
declare const topic: Topic;

/** An `ArchetypeSerializer` option; plugins choose the option values. */
interface ExpectedArchetypeOption {
  key: string;
  title: string;
  description: string;
  option_type: unknown;
}

/** `ArchetypeSerializer` fields plus the site that `Site.create` stamps on. */
interface ExpectedArchetypeFields {
  /** Archetype ids are names such as `regular`, never numbers. */
  id: string;
  name: string;
  options: ExpectedArchetypeOption[];
  site: Site;
}

declare module "discourse/models/archetype" {
  interface ArchetypeFields {
    type_test_plugin_flag?: boolean;
  }
}

expectTypeOf(archetype).toExtend<RestCompatModel>();
expectTypeOf(archetype).not.toBeAny();

/* Fields. */

expectTypeOf<
  Omit<ArchetypeFields, "type_test_plugin_flag">
>().toEqualTypeOf<ExpectedArchetypeFields>();
expectTypeOf<
  Pick<Archetype, keyof ExpectedArchetypeFields>
>().toEqualTypeOf<ExpectedArchetypeFields>();
expectTypeOf(archetype.type_test_plugin_flag).toEqualTypeOf<
  boolean | undefined
>();
// @ts-expect-error archetype ids are strings
archetype.id = 1;

/* Derived state. */

expectTypeOf(archetype.hasOptions).toEqualTypeOf<boolean>();
expectTypeOf(archetype.isDefault).toEqualTypeOf<boolean>();
expectTypeOf(archetype.notDefault).toEqualTypeOf<boolean>();

/** Audit only what Archetype adds over its base. */
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
expectTypeOf<OwnAnyKeys<Archetype, RestCompatModel>>().toEqualTypeOf<never>();

/* Construction: `Site.create` passes each payload row with the site attached. */

declare const option: ExpectedArchetypeOption;
expectTypeOf(
  Archetype.create({ id: "regular", name: "Regular", options: [option], site })
).toEqualTypeOf<Archetype>();
// @ts-expect-error options are option rows, not names
Archetype.create({ options: ["key"] });

/* Consumers read archetypes without casts. */

expectTypeOf(site.archetypes).toEqualTypeOf<Archetype[] | undefined>();
expectTypeOf(composer.archetypes).toEqualTypeOf<Archetype[] | undefined>();
expectTypeOf(topic.archetypeObject).toEqualTypeOf<Archetype | undefined>();
expectTypeOf(site.archetypes![0].id).toEqualTypeOf<string>();
