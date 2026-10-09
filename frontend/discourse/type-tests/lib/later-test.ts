import type { Timer } from "@ember/runloop";
import { expectTypeOf } from "expect-type";
import discourseLater from "discourse/lib/later";

const target = {
  method(count: number) {
    return count;
  },
};

// The timer is what callers hold on to in order to `cancel()` later, so it has to
// survive the wrapper. Before this module was typed it inferred as `any`, which
// silently degraded every `ReturnType<typeof discourseLater>` field into `any`.
expectTypeOf(discourseLater(() => {}, 100)).toEqualTypeOf<Timer>();
expectTypeOf(discourseLater(() => {}, 100)).not.toBeAny();

// `later`'s three call forms all have to survive the wrapper: a bare method, a
// target plus a function, and a target plus a method name.
expectTypeOf(
  discourseLater(target, function () {}, 100)
).toEqualTypeOf<Timer>();
expectTypeOf(discourseLater(target, "method", 5, 100)).toEqualTypeOf<Timer>();

// Arguments destined for the scheduled function are still checked against it,
// rather than being swallowed by a variadic `any[]`.
expectTypeOf(discourseLater)
  .parameter(0)
  .not.toEqualTypeOf<ReadonlyArray<unknown>>();
