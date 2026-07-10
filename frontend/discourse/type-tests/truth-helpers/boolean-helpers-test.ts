import { expectTypeOf } from "expect-type";
import { eq, gt, has, includes, not, notEq } from "discourse/truth-helpers";

// The comparison/membership helpers always return a plain `boolean`.
expectTypeOf(not("x")).toEqualTypeOf<boolean>();
expectTypeOf(eq(1, 2)).toEqualTypeOf<boolean>();
expectTypeOf(notEq(1, 2)).toEqualTypeOf<boolean>();
expectTypeOf(gt(2, 1)).toEqualTypeOf<boolean>();
expectTypeOf(gt(2, 1, { forceNumber: true })).toEqualTypeOf<boolean>();
expectTypeOf(has(new Set([1]), 1)).toEqualTypeOf<boolean>();
expectTypeOf(includes([1, 2], 1)).toEqualTypeOf<boolean>();
