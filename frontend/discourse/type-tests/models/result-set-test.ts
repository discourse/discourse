import type EmberObject from "@ember/object";
import { expectTypeOf } from "expect-type";
import LegacyArrayLikeObject from "discourse/lib/legacy-array-like-object";
import RestModel from "discourse/models/rest";
import ResultSet from "discourse/models/result-set";
import type {
  default as StoreService,
  ResultSetOf,
} from "discourse/services/store";

class Gadget extends RestModel {
  declare label: string;
}

/** A subclass with its own fields, as CategoryList and ColorSchemes are. */
class Gadgets extends LegacyArrayLikeObject<Gadget> {
  page = 1;
  loading = false;
}

declare const store: StoreService;
declare const gadget: Gadget;
declare const results: ResultSet<Gadget>;

/* Construction: `create` returns the receiving subclass. */

expectTypeOf(LegacyArrayLikeObject.create()).toExtend<LegacyArrayLikeObject>();
expectTypeOf(
  LegacyArrayLikeObject.create({ content: [1, 2, 3], foo: "bar" })
).toExtend<LegacyArrayLikeObject>();
expectTypeOf(Gadgets.create({ content: [gadget] })).toEqualTypeOf<Gadgets>();
expectTypeOf(Gadgets.create().page).toEqualTypeOf<number>();
// Attributes other than content are applied after construction.
Gadgets.create({ content: [gadget], page: 2, loading: true });
expectTypeOf(ResultSet.create({ content: [] })).toExtend<ResultSet>();
// Non-array content throws at runtime.
// @ts-expect-error content must be an array
LegacyArrayLikeObject.create({ content: "x" });
// @ts-expect-error null content throws too
LegacyArrayLikeObject.create({ content: null });
// @ts-expect-error a subclass's content holds its element type
Gadgets.create({ content: ["x"] });
expectTypeOf(Gadgets).toExtend<typeof LegacyArrayLikeObject<Gadget>>();
expectTypeOf(Gadgets.create()).toExtend<EmberObject>();

/* Content: the proxied array is reached through `content`. */

expectTypeOf(Gadgets.create().content).toEqualTypeOf<Gadget[]>();
expectTypeOf(results.content).toEqualTypeOf<Gadget[]>();
results.content.push(gadget);
results.content.splice(0, Infinity, gadget);
expectTypeOf(results.content.find((g) => g.label === "x")).toEqualTypeOf<
  Gadget | undefined
>();
// Assigning content through the proxy throws.
// @ts-expect-error content is read-only
results.content = [];
// Direct array access is deprecated, so typed code goes through content.
// @ts-expect-error no direct array surface
expectTypeOf(results.length).toBeNumber();
// @ts-expect-error no direct array surface
results.filter(Boolean);
expectTypeOf(Gadgets.create().warnContext).toEqualTypeOf<string | undefined>();

/* ResultSet state. */

expectTypeOf(results).toExtend<LegacyArrayLikeObject<Gadget>>();
expectTypeOf(results.totalRows).toEqualTypeOf<number>();
expectTypeOf(results.loadMoreUrl).toEqualTypeOf<string | null | undefined>();
expectTypeOf(results.refreshUrl).toEqualTypeOf<string | null | undefined>();
expectTypeOf(results.loading).toEqualTypeOf<boolean>();
expectTypeOf(results.loadingMore).toEqualTypeOf<boolean>();
expectTypeOf(results.refreshing).toEqualTypeOf<boolean>();
// findAll forwards no args; find forwards its object or null.
expectTypeOf(results.findArgs).toEqualTypeOf<object | null | undefined>();
expectTypeOf(results.extras).not.toBeAny();
expectTypeOf(results.resultSetMeta).not.toBeAny();
// Response extras are assigned as received, or wrapped by an extras class.
results.extras = { type_filters: ["my"] };
expectTypeOf(results.store).toEqualTypeOf<StoreService | null>();
expectTypeOf(results.__type).toEqualTypeOf<string | undefined>();
expectTypeOf(results.warnContext).toEqualTypeOf<string>();
expectTypeOf(results.canLoadMore).toEqualTypeOf<boolean>();
expectTypeOf(results.loadMore()).resolves.toEqualTypeOf<void>();
expectTypeOf(results.refresh()).resolves.toEqualTypeOf<void>();
expectTypeOf(results.loadMore).parameters.toEqualTypeOf<[]>();

/* Store collections. */

expectTypeOf<ResultSetOf<Gadget>>().toExtend<ResultSet>();
expectTypeOf<ResultSet<Gadget>>().toExtend<ResultSetOf<Gadget>>();
expectTypeOf<ResultSetOf<Gadget>["content"]>().toEqualTypeOf<Gadget[]>();
expectTypeOf(
  store.appendResults(results, "gadget", "/gadgets?page=2")
).resolves.toEqualTypeOf<void>();
expectTypeOf(
  store.refreshResults(results, "gadget", "/gadgets")
).resolves.toEqualTypeOf<void>();

/* Subclass chains and the inherited factory. */

class Numbers extends LegacyArrayLikeObject<number> {
  page = 1;
}

class NestedNumbers extends Numbers {
  get warnContext() {
    return "numbers";
  }
}

const numbersClass: typeof LegacyArrayLikeObject<number> = Numbers;
expectTypeOf(numbersClass.create()).toExtend<EmberObject>();
expectTypeOf(
  NestedNumbers.create({ content: [1], page: 2 })
).toEqualTypeOf<NestedNumbers>();
expectTypeOf(
  ResultSet.create<ResultSet<number>>({ content: [1] }).content
).toEqualTypeOf<number[]>();
