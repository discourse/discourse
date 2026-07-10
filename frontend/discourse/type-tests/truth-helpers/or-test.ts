import { expectTypeOf } from "expect-type";
import { or } from "discourse/truth-helpers";

// No arguments: our runtime returns its initial `false` (upstream's class-based
// helper returns `undefined` here — we keep the plain-function behavior).
expectTypeOf(or()).toEqualTypeOf<false>();

// The motivating select-kit case: a maybe-undefined string OR-ed with a literal
// fallback must resolve to `string` — NOT `boolean`, which is the bug that the
// previously-untyped helper produced.
const maybeString = "x" as string | undefined;
expectTypeOf(or(maybeString, "fallback")).toEqualTypeOf<string>();
expectTypeOf(or(maybeString, "fallback")).not.toEqualTypeOf<boolean>();

// A leading falsy value is skipped; the first truthy argument wins with its
// precise (literal) type preserved.
const stringEnum = "foo" as "foo" | "bar";
expectTypeOf(or(false, stringEnum)).toEqualTypeOf<"foo" | "bar">();
