import { expectTypeOf } from "expect-type";
import { withPluginApi } from "discourse/lib/plugin-api";
import {
  BEHAVIOR_TRANSFORMERS,
  VALUE_TRANSFORMERS,
} from "discourse/lib/registry/transformers";
import {
  _registerTransformer,
  applyBehaviorTransformer,
  applyMutableValueTransformer,
  applyValueTransformer,
  type BehaviorTransformer,
  type BehaviorTransformerFor,
  type BehaviorTransformerRegistry,
  type BehaviorTransformerResult,
  type RegisterBehaviorTransformer,
  type RegisterValueTransformer,
  transformerTypes,
  type Untyped,
  type ValueTransformer,
  type ValueTransformerFor,
  type ValueTransformerRegistry,
} from "discourse/lib/transformer";

interface Ctx {
  id: number;
}

declare module "discourse/lib/transformer" {
  interface ValueTransformerRegistry {
    "test:req": { value: string[]; context: Ctx; mutable: false };
    "test:opt": { value: number; context: Ctx | undefined; mutable: false };
    "test:none": { value: string | null; context: undefined; mutable: false };
    "test:mut": { value: string[]; context: Ctx; mutable: true };
    "test:untyped": Untyped;
    "test:bad-mutable": { value: string; context: undefined; mutable: boolean };
    "test:bad-missing": { value: string; mutable: false };
    "test:bad-void": { value: void; context: undefined; mutable: false };
    "test:bad-union":
      | { value: string; context: undefined; mutable: false }
      | { value: number; context: undefined; mutable: false };
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    "test:bad-any": any;
    "test:bad-never": never;
    "test:bad-no-value": { context: undefined; mutable: false };
    "test:bad-no-mutable": { value: number; context: undefined };
  }

  interface BehaviorTransformerRegistry {
    "test:load": { result: Promise<number>; context: Ctx };
    "test:maybe": { result: number; context: Ctx | undefined };
    "test:plain": { result: void; context: undefined };
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    "test:bad-behavior-any": any;
    "test:bad-behavior-never": never;
    "test:bad-behavior-no-result": { context: undefined };
    "test:bad-behavior-no-context": { result: number };
    "test:bad-behavior-union":
      | { result: number; context: undefined }
      | { result: string; context: undefined };
  }
}

const apply = applyValueTransformer;
const applyMut = applyMutableValueTransformer;
const applyB = applyBehaviorTransformer;
const ctx: Ctx = { id: 1 };

declare const someName: string;
declare const two: "test:req" | "test:none";
declare const tmpl: `test:${string}`;
declare const brand: unique symbol;
declare const branded: "test:req" & { [brand]: true };
declare const brandedStr: string & { [brand]: true };

/* Apply: registered value hooks */
expectTypeOf(apply("test:req", ["a"], ctx)).toEqualTypeOf<string[]>();
expectTypeOf(apply("test:none", null)).toEqualTypeOf<string | null>();
expectTypeOf(apply("test:opt", 1)).toEqualTypeOf<number>();
expectTypeOf(apply("test:opt", 1, ctx)).toEqualTypeOf<number>();
expectTypeOf(applyMut("test:mut", ["a"], ctx)).toEqualTypeOf<string[]>();
// @ts-expect-error wrong default
apply("test:req", 42, ctx);
// @ts-expect-error missing context property
apply("test:req", ["a"], {});
// @ts-expect-error missing required context
apply("test:req", ["a"]);
// @ts-expect-error null required context
apply("test:req", ["a"], null);
// @ts-expect-error mutable hook through the immutable apply
apply("test:mut", ["a"], ctx);
// @ts-expect-error immutable hook through the mutable apply
applyMut("test:req", ["a"], ctx);
// @ts-expect-error opts can't turn an immutable hook mutable
apply("test:req", ["a"], ctx, { mutable: true });
// @ts-expect-error typed behavior hook through the value apply
apply("test:plain", 1);
// @ts-expect-error typed value hook through the behavior apply
applyB("test:req", () => 1);

/* Apply: name boundaries */
// @ts-expect-error string-typed name
apply(someName, 1);
// @ts-expect-error union of names
apply(two, null);
// @ts-expect-error template literal overlapping typed names
apply(tmpl, 1);
// @ts-expect-error branded typed name
apply(branded, 42, ctx);
// @ts-expect-error branded string
apply(brandedStr, 1);
// @ts-expect-error legacy explicit type argument layout
apply<string | false>("plugin-hook", "default");
// @ts-expect-error an explicit name can't bypass the contract
apply<"test:req">("test:req", 42, ctx);

/* Apply: unregistered and Untyped hooks keep today's inference */
expectTypeOf(apply("plugin-hook", 5)).toEqualTypeOf<number>();
expectTypeOf(apply("test:untyped", "x")).toEqualTypeOf<string>();
expectTypeOf(apply("plugin-hook", null as string | null)).toEqualTypeOf<
  string | null
>();
expectTypeOf(apply("plugin-hook", "d", null, null)).toEqualTypeOf<string>();
expectTypeOf(
  apply("plugin-hook", [] as string[], undefined, { mutable: true })
).toEqualTypeOf<string[]>();
expectTypeOf(applyMut("plugin-hook", ["a"])).toEqualTypeOf<string[]>();

/* Apply: malformed entries are unusable */
// @ts-expect-error mutable: boolean
apply("test:bad-mutable", "x");
// @ts-expect-error mutable: boolean
applyMut("test:bad-mutable", "x");
// @ts-expect-error missing context field
apply("test:bad-missing", "x");
// @ts-expect-error union entry
apply("test:bad-union", "x");
// @ts-expect-error an `any` entry is not Untyped
apply("test:bad-any", "x");
// @ts-expect-error a `never` entry is not Untyped
apply("test:bad-never", "x");

/* Apply: behavior hooks */
expectTypeOf(
  applyB("test:load", ({ context }) => Promise.resolve(context.id), ctx)
).toEqualTypeOf<BehaviorTransformerResult<Promise<number>>>();
// @ts-expect-error missing required behavior context
applyB("test:load", () => Promise.resolve(1));
// @ts-expect-error wrong default result
applyB("test:load", () => 1, ctx);
applyB("test:maybe", ({ context }) => {
  expectTypeOf(context).toEqualTypeOf<
    Partial<Ctx> & { _unstable_self?: unknown }
  >();
  return 1;
});
applyB("test:plain", ({ context }) => {
  expectTypeOf(context).toEqualTypeOf<{ _unstable_self?: unknown }>();
});
expectTypeOf(applyB("plugin-behavior", () => 1)).toEqualTypeOf<
  BehaviorTransformerResult<number>
>();

/* .call and .bind */
const bound = apply.bind(null);
expectTypeOf(bound("test:req", ["a"], ctx)).toEqualTypeOf<string[]>();
expectTypeOf(bound("plugin-hook", 5)).toEqualTypeOf<number>();
// @ts-expect-error .call is unsupported for this overload surface
apply.call(null, "test:none", null);
const preBound = apply.bind(null, "test:none");
// @ts-expect-error pre-binding a hook name is unsupported
preBound(null);

/* Registration: value hooks */
withPluginApi((api) => {
  api.registerValueTransformer("test:req", ({ value, context }) => {
    expectTypeOf(value).toEqualTypeOf<string[]>();
    expectTypeOf(context).toEqualTypeOf<Ctx>();
    return value;
  });
  api.registerValueTransformer("test:opt", ({ context }) => {
    expectTypeOf(context).toEqualTypeOf<Ctx | null | undefined>();
    return 1;
  });
  api.registerValueTransformer("test:none", ({ context }) => {
    expectTypeOf(context).toEqualTypeOf<null | undefined>();
    return null;
  });
  api.registerValueTransformer("test:mut", ({ value }) => {
    value.push("x");
  });

  // @ts-expect-error an immutable hook's callback must return its value
  api.registerValueTransformer("test:req", ({ value }) => {
    value.push("x");
  });
  // @ts-expect-error wrong return type
  api.registerValueTransformer("test:none", () => 42);
  // @ts-expect-error union of names
  api.registerValueTransformer(two, () => null);
  // @ts-expect-error string-typed name
  api.registerValueTransformer(someName, () => 1);
  // @ts-expect-error branded typed name
  api.registerValueTransformer(branded, () => "wrong");
  // @ts-expect-error typed behavior hook through value registration
  api.registerValueTransformer("test:plain", () => 1);
  // @ts-expect-error immutable void entries are invalid
  api.registerValueTransformer("test:bad-void", () => 42);
  // @ts-expect-error mutable: boolean
  api.registerValueTransformer("test:bad-mutable", () => "x");
  // @ts-expect-error an `any` entry is not Untyped
  api.registerValueTransformer("test:bad-any", () => "x");
  // @ts-expect-error a `never` entry is not Untyped
  api.registerValueTransformer("test:bad-never", () => "x");

  const annotated: ValueTransformer<number, Ctx> = ({ value }) => value + 1;
  expectTypeOf(
    api.registerValueTransformer("plugin-hook", annotated)
  ).toEqualTypeOf<boolean>();
  api.registerValueTransformer("test:untyped", annotated);

  const pre: ValueTransformerFor<"test:req"> = ({ value }) => [...value, "x"];
  api.registerValueTransformer("test:req", pre);
});

/* Registration: behavior hooks */
withPluginApi((api) => {
  api.registerBehaviorTransformer("test:load", async ({ next, context }) => {
    expectTypeOf(context.id).toEqualTypeOf<number>();
    return await next();
  });
  api.registerBehaviorTransformer("test:plain", () => {});
  // A void result ignores the middleware's return value.
  api.registerBehaviorTransformer("test:plain", async () => "ignored");

  // @ts-expect-error wrong middleware result
  api.registerBehaviorTransformer("test:maybe", () => "x");
  // @ts-expect-error async middleware on a synchronous hook
  api.registerBehaviorTransformer("test:maybe", async ({ next }) => next());
  // @ts-expect-error typed value hook through behavior registration
  api.registerBehaviorTransformer("test:req", () => {});

  const preB: BehaviorTransformerFor<"test:load"> = ({ next }) => next();
  api.registerBehaviorTransformer("test:load", preB);

  const annotatedB: BehaviorTransformer<Promise<number>, Ctx> = ({ next }) =>
    next();
  api.registerBehaviorTransformer("plugin-behavior", annotatedB);
});

/* Internal registration */
const preInternal: ValueTransformerFor<"test:req"> = ({ value }) => value;
_registerTransformer("test:req", transformerTypes.VALUE, preInternal);
// @ts-expect-error wrong callback through internal registration
_registerTransformer("test:req", transformerTypes.VALUE, () => "wrong");

/* Callback helper types */
expectTypeOf<ValueTransformerFor<"test:mut">>().returns.toEqualTypeOf<void>();
expectTypeOf<ValueTransformerFor<"test:req">>().returns.toEqualTypeOf<
  string[]
>();
expectTypeOf<ValueTransformerFor<"test:req" | "test:none">>().toBeNever();
expectTypeOf<BehaviorTransformerFor<"test:load" | "test:plain">>().toBeNever();

/* Drift: core runtime names and core registry keys are the same set */
type CoreValueKey = Exclude<keyof ValueTransformerRegistry, `test:${string}`>;
type CoreBehaviorKey = Exclude<
  keyof BehaviorTransformerRegistry,
  `test:${string}`
>;
type ValueName = (typeof VALUE_TRANSFORMERS)[number];
type BehaviorName = (typeof BEHAVIOR_TRANSFORMERS)[number];

expectTypeOf<ValueName>().not.toEqualTypeOf<string>();
expectTypeOf<BehaviorName>().not.toEqualTypeOf<string>();
expectTypeOf<Exclude<CoreValueKey, ValueName>>().toBeNever();
expectTypeOf<Exclude<ValueName, CoreValueKey>>().toBeNever();
expectTypeOf<Exclude<CoreBehaviorKey, BehaviorName>>().toBeNever();
expectTypeOf<Exclude<BehaviorName, CoreBehaviorKey>>().toBeNever();
expectTypeOf<
  Extract<keyof ValueTransformerRegistry, keyof BehaviorTransformerRegistry>
>().toBeNever();

/* Malformed entries: every apply and registration path rejects them */
// @ts-expect-error immutable void
apply("test:bad-void", undefined);
// @ts-expect-error any
applyMut("test:bad-any", []);
// @ts-expect-error never
applyMut("test:bad-never", []);
// @ts-expect-error any
applyB("test:bad-behavior-any", () => 1);
// @ts-expect-error never
applyB("test:bad-behavior-never", () => 1);
// @ts-expect-error union entry
applyB("test:bad-behavior-union", () => 1);
// @ts-expect-error any
_registerTransformer("test:bad-any", "VALUE", () => 1);
// @ts-expect-error never
_registerTransformer("test:bad-behavior-never", "BEHAVIOR", () => 1);
// @ts-expect-error missing context field
_registerTransformer("test:bad-behavior-no-context", "BEHAVIOR", () => 1);
withPluginApi((api) => {
  // @ts-expect-error missing result field
  api.registerBehaviorTransformer("test:bad-behavior-no-result", () => 1);
  // @ts-expect-error union entry
  api.registerBehaviorTransformer("test:bad-behavior-union", () => 1);
  // @ts-expect-error any
  api.registerBehaviorTransformer("test:bad-behavior-any", () => 1);
  // @ts-expect-error never
  api.registerBehaviorTransformer("test:bad-behavior-never", () => 1);
});
expectTypeOf<ValueTransformerFor<"test:bad-no-value">>().toBeNever();
expectTypeOf<ValueTransformerFor<"test:bad-any">>().toBeNever();
expectTypeOf<ValueTransformerFor<"test:bad-never">>().toBeNever();
expectTypeOf<BehaviorTransformerFor<"test:bad-behavior-union">>().toBeNever();
expectTypeOf<BehaviorTransformerFor<"test:bad-behavior-any">>().toBeNever();
expectTypeOf<BehaviorTransformerFor<"test:bad-behavior-never">>().toBeNever();

/* Malformed entries name the problem in the diagnostic */
declare const registerValue: RegisterValueTransformer;
declare const registerBehavior: RegisterBehaviorTransformer;
type DiagnosticMessage<T> = T[keyof T];
type MalformedEntryMessage = "The registry entry for this hook is malformed";
expectTypeOf<
  DiagnosticMessage<Parameters<typeof applyValueTransformer<"test:bad-any">>[1]>
>().toEqualTypeOf<MalformedEntryMessage>();
expectTypeOf<
  DiagnosticMessage<
    Parameters<typeof applyMutableValueTransformer<"test:bad-never">>[1]
  >
>().toEqualTypeOf<MalformedEntryMessage>();
expectTypeOf<
  DiagnosticMessage<
    Parameters<
      typeof applyBehaviorTransformer<"test:bad-behavior-no-result">
    >[1]
  >
>().toEqualTypeOf<MalformedEntryMessage>();
expectTypeOf<
  DiagnosticMessage<Parameters<typeof registerValue<"test:bad-no-mutable">>[1]>
>().toEqualTypeOf<MalformedEntryMessage>();
expectTypeOf<
  DiagnosticMessage<
    Parameters<typeof registerBehavior<"test:bad-behavior-no-context">>[1]
  >
>().toEqualTypeOf<MalformedEntryMessage>();

/* Branded names */
declare const brandedTemplate: `test:${string}` & { [brand]: true };
type BrandedOpt = "test:opt" & { [brand]: true };
// @ts-expect-error branded template overlapping typed names
apply(brandedTemplate, 1);
withPluginApi((api) => {
  // @ts-expect-error branded template overlapping typed names
  api.registerValueTransformer(brandedTemplate, () => 1);
});
expectTypeOf<ValueTransformerFor<BrandedOpt>>().returns.toEqualTypeOf<number>();
// @ts-expect-error branding can't hide the registered callback result
const wrongBranded: ValueTransformerFor<BrandedOpt> = () => "wrong";

export { registerBehavior, registerValue, wrongBranded };
