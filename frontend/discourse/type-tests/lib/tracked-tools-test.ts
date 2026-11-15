import { expectTypeOf } from "expect-type";
import {
  autoTrackedArray,
  dedupeTracked,
  DeferredTrackedSet,
  defineTrackedProperty,
  enumerateTrackedEntries,
  enumerateTrackedKeys,
  isTrackedArray,
  manuallyTrack,
  resettableTracked,
  // eslint-disable-next-line discourse/deprecated-imports -- asserts the deprecated alias keeps its type
  trackedArray,
  trackedObjectWithComputedSupport,
} from "discourse/lib/tracked-tools";

// The decorators run as legacy field decorators, so TypeScript checks them as
// `(target, key)` calls returning `void`. Every field form below must compile.
export class Decorated {
  @autoTrackedArray tags: string[] = [];
  @autoTrackedArray maybeTags?: string[];
  @autoTrackedArray nullableTags: number[] | null = null;
  @autoTrackedArray readonlyTags: readonly string[] = [];
  @trackedArray legacyTags: string[] = [];

  @dedupeTracked name = "";
  @dedupeTracked count?: number;

  @resettableTracked label = "";
  @resettableTracked selection: { id: number } | null = null;
}

// `autoTrackedArray` throws at runtime for anything but an array, null or
// undefined, so a non-array field is a compile error.
export class NotAnArray {
  // @ts-expect-error a string field cannot hold a tracked array
  @autoTrackedArray name = "";

  // @ts-expect-error an object field cannot hold a tracked array
  @autoTrackedArray settings: { enabled: boolean } = { enabled: false };
}

// The deprecated alias is the same function.
expectTypeOf(trackedArray).toEqualTypeOf(autoTrackedArray);

// `trackedObjectWithComputedSupport` returns a proxy with the input's shape.
const tracked = trackedObjectWithComputedSupport({ id: 1, title: "x" });
expectTypeOf(tracked).toEqualTypeOf<{ id: number; title: string }>();
expectTypeOf(tracked).not.toBeAny();
// @ts-expect-error only objects can be proxied
trackedObjectWithComputedSupport("not an object");

// `DeferredTrackedSet` defers mutations to the next run loop, so `add` and
// `delete` return the set rather than a boolean.
const deferred = new DeferredTrackedSet<string>();
expectTypeOf(deferred.add("a")).toEqualTypeOf<DeferredTrackedSet<string>>();
expectTypeOf(deferred.delete("a")).toEqualTypeOf<DeferredTrackedSet<string>>();
expectTypeOf(deferred.has("a")).toEqualTypeOf<boolean>();
expectTypeOf(deferred.size).toEqualTypeOf<number>();
expectTypeOf(deferred.clear()).toEqualTypeOf<void>();
expectTypeOf([...deferred]).toEqualTypeOf<string[]>();
expectTypeOf([...deferred.values()]).toEqualTypeOf<string[]>();
expectTypeOf([...deferred.keys()]).toEqualTypeOf<string[]>();
expectTypeOf([...deferred.entries()]).toEqualTypeOf<[string, string][]>();
deferred.forEach((value) => expectTypeOf(value).toEqualTypeOf<string>());
// @ts-expect-error the set only holds strings
deferred.add(1);
expectTypeOf(new DeferredTrackedSet(["a", "b"])).toEqualTypeOf<
  DeferredTrackedSet<string>
>();
// An untyped set, as `services/breadcrumbs.js` creates, holds unknown values.
expectTypeOf(new DeferredTrackedSet()).toEqualTypeOf<
  DeferredTrackedSet<unknown>
>();

// `isTrackedArray` narrows to an array.
declare const maybeArray: unknown;
expectTypeOf(isTrackedArray(maybeArray)).toEqualTypeOf<boolean>();
if (isTrackedArray(maybeArray)) {
  expectTypeOf(maybeArray).toEqualTypeOf<unknown[]>();
}

// The enumerators accept a missing object and return keys or entries.
declare const instance: object | null | undefined;
expectTypeOf(enumerateTrackedKeys(instance)).toEqualTypeOf<string[]>();
expectTypeOf(enumerateTrackedEntries(instance)).toEqualTypeOf<
  [string, unknown][]
>();
// @ts-expect-error a primitive has no tracked properties to enumerate
enumerateTrackedKeys("text");

expectTypeOf(defineTrackedProperty({}, "title", "x")).toEqualTypeOf<void>();
// @ts-expect-error the target must be an object
defineTrackedProperty("text", "title", "x");

expectTypeOf(manuallyTrack(tracked.title)).toEqualTypeOf<void>();
