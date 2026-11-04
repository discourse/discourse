import { expectTypeOf } from "expect-type";
import RestModel from "discourse/models/rest";
import type ResultSet from "discourse/models/result-set";
import UserDraft from "discourse/models/user-draft";
import type {
  default as StoreService,
  ModelFor,
  ResultSetOf,
  StoreAdapter,
} from "discourse/services/store";

class Gadget extends RestModel {
  declare label: string;
}

class Widget extends RestModel {
  declare size: number;
}

// Plugins register their models the same way.
declare module "discourse/services/store" {
  interface ModelRegistry {
    "test-gadget": Gadget;
    "test-draft": UserDraft;
    "test-widget": Widget;
  }

  interface ModelCreateAttrsRegistry {
    "test-widget": { size?: number | string };
  }
}

declare const store: StoreService;
declare const dynamicType: string;

// The registry maps a type name to its model; anything else is a RestModel.
expectTypeOf<ModelFor<"test-gadget">>().toEqualTypeOf<Gadget>();
expectTypeOf<ModelFor<"test-draft">>().toEqualTypeOf<UserDraft>();
expectTypeOf<ModelFor<"not-registered">>().toEqualTypeOf<RestModel>();
expectTypeOf<ModelFor<string>>().toEqualTypeOf<RestModel>();

// createRecord
expectTypeOf(store.createRecord("test-gadget")).toEqualTypeOf<Gadget>();
expectTypeOf(store.createRecord("test-draft")).toEqualTypeOf<UserDraft>();
expectTypeOf(store.createRecord("not-registered")).toEqualTypeOf<RestModel>();
expectTypeOf(store.createRecord(dynamicType)).toEqualTypeOf<RestModel>();
expectTypeOf(
  store.createRecord("test-gadget", { label: "x", extra_field: 1 })
).toEqualTypeOf<Gadget>();
// @ts-expect-error a declared field keeps its type
store.createRecord("test-gadget", { label: 1 });
// @ts-expect-error the type name is a string
store.createRecord(1);

// A registered creation shape replaces the model's field types as input.
expectTypeOf(
  store.createRecord("test-widget", { size: "3" })
).toEqualTypeOf<Widget>();
// @ts-expect-error the registered creation shape is still checked
store.createRecord("test-widget", { size: true });

// find: an id, or no find args, gives one model; an object or null gives a
// ResultSet, or nothing when the response lacks the collection key
expectTypeOf(store.find("test-gadget", 1)).resolves.toEqualTypeOf<Gadget>();
expectTypeOf(
  store.find("test-gadget", "slug")
).resolves.toEqualTypeOf<Gadget>();
expectTypeOf(store.find("test-gadget")).resolves.toEqualTypeOf<Gadget>();
expectTypeOf(store.find("test-gadget", { q: "x" })).resolves.toEqualTypeOf<
  ResultSetOf<Gadget> | undefined
>();
expectTypeOf(store.find("test-gadget", null)).resolves.toEqualTypeOf<
  ResultSetOf<Gadget> | undefined
>();
expectTypeOf(
  store.find("test-gadget", { q: "x" }, { cacheKey: "k" })
).resolves.toEqualTypeOf<ResultSetOf<Gadget> | undefined>();
expectTypeOf(
  store.find("not-registered", 1)
).resolves.toEqualTypeOf<RestModel>();

// findAll can resolve to nothing when the payload lacks the expected key
expectTypeOf(store.findAll("test-gadget")).resolves.toEqualTypeOf<
  ResultSetOf<Gadget> | undefined
>();
expectTypeOf(store.findAll("test-gadget", { page: 2 })).resolves.toEqualTypeOf<
  ResultSetOf<Gadget> | undefined
>();

// findFiltered builds a single model from the response
expectTypeOf(
  store.findFiltered("test-gadget", { filter: "latest" })
).resolves.toEqualTypeOf<Gadget>();

// A ResultSetOf is a ResultSet whose content holds the model
declare const results: ResultSetOf<Gadget>;
expectTypeOf(results).toExtend<ResultSet>();
expectTypeOf(results.content).toEqualTypeOf<Gadget[]>();

// findStale reports whether cached results exist and can refresh them
const stale = store.findStale("test-gadget", { q: "x" });
expectTypeOf(stale.hasResults).toEqualTypeOf<boolean>();
expectTypeOf(stale.refresh).returns.not.toBeAny();

// adapters
const adapter = store.adapterFor("test-gadget");
expectTypeOf(adapter).toEqualTypeOf<StoreAdapter>();
expectTypeOf(adapter.primaryKey).toEqualTypeOf<string>();
expectTypeOf(adapter.apiNameFor("test-gadget")).toEqualTypeOf<string>();

// plural names
expectTypeOf(store.pluralize("category")).toEqualTypeOf<string>();
expectTypeOf(store.addPluralization("child", "children")).toEqualTypeOf<void>();

// updates and deletes go through the adapter
declare const gadget: Gadget;
expectTypeOf(store.update("test-gadget", 1, { label: "y" })).not.toBeAny();
expectTypeOf(store.destroyRecord("test-gadget", gadget)).not.toBeAny();
// @ts-expect-error destroyRecord needs a model
store.destroyRecord("test-gadget", { id: 1 });
