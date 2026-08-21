import { expectTypeOf } from "expect-type";
import {
  createDragDwell,
  type DragDwell,
  type DragDwellOptions,
} from "discourse/ui-kit/modifiers/d-drag-dwell";

const destroyable = {};

/* Positive: Target infers from onDwell's parameter without an explicit type
   argument. */
const inferred = createDragDwell({
  destroyable,
  delay: 300,
  onDwell: (target: HTMLElement) => target.focus(),
});
expectTypeOf(inferred).toEqualTypeOf<DragDwell<HTMLElement>>();
expectTypeOf(inferred).not.toBeAny();
expectTypeOf(inferred.update).parameter(0).toEqualTypeOf<HTMLElement | null>();
expectTypeOf(inferred.reset).toEqualTypeOf<() => void>();

/* Positive: identity's parameter matches Target and its return is an
   unconstrained key. */
const keyed = createDragDwell({
  destroyable,
  delay: 300,
  identity: (target: { element: HTMLElement }) => target.element,
  onDwell: (target: { element: HTMLElement }) => target.element.focus(),
});
expectTypeOf(keyed).toEqualTypeOf<DragDwell<{ element: HTMLElement }>>();

/* Positive: identity may return null/undefined as a legitimate key. */
createDragDwell({
  destroyable,
  delay: 300,
  identity: (): undefined => undefined,
  onDwell: (target: object) => target,
});

expectTypeOf<DragDwellOptions<string>["identity"]>().toEqualTypeOf<
  ((target: string) => unknown) | undefined
>();

/* Positive: delay is optional and defaults. */
expectTypeOf(
  createDragDwell({ destroyable, onDwell: (target: string) => target })
).toEqualTypeOf<DragDwell<string>>();

/* Negatives. The repo tsconfig is not strict, so only arity, missing
   required properties, excess properties, and wrong primitives reliably
   error — nullability-based negatives would not fire. */

// @ts-expect-error — onDwell is required
createDragDwell({ destroyable, delay: 300 });

// @ts-expect-error — destroyable is required
createDragDwell({ delay: 300, onDwell: (target: string) => target });

createDragDwell({
  destroyable,
  delay: 300,
  onDwell: (target: string) => target,
  // @ts-expect-error — unknown options are rejected
  eagerness: "high",
});

// @ts-expect-error — delay is a number of milliseconds
createDragDwell({ destroyable, delay: "300", onDwell: (t: string) => t });

const stringDwell = createDragDwell({
  destroyable,
  delay: 300,
  onDwell: (target: string) => target,
});
// @ts-expect-error — update only accepts the inferred Target or null
stringDwell.update(42);
