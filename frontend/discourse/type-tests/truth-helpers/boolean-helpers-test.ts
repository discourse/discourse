import { expectTypeOf } from "expect-type";
import { has, includes } from "discourse/truth-helpers";

// The membership helpers always return a plain `boolean`.
expectTypeOf(has(new Set([1]), 1)).toEqualTypeOf<boolean>();
expectTypeOf(includes([1, 2], 1)).toEqualTypeOf<boolean>();
