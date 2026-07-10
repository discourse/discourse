import { expectTypeOf } from "expect-type";
import { and } from "discourse/truth-helpers";

// No arguments: our runtime returns its initial `false`.
expectTypeOf(and()).toEqualTypeOf<false>();

// First falsy argument wins.
expectTypeOf(and(1, false)).toEqualTypeOf<false>();

// All truthy: the last argument's type is returned, preserving its literal type.
const stringEnum = "foo" as "foo" | "bar";
expectTypeOf(and("x", stringEnum)).toEqualTypeOf<"foo" | "bar">();
