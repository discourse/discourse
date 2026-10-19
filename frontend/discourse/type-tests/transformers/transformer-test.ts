import { expectTypeOf } from "expect-type";
import { withPluginApi } from "discourse/lib/plugin-api";
import {
  _registerTransformer,
  applyBehaviorTransformer,
  applyMutableValueTransformer,
  applyValueTransformer,
  type BehaviorTransformer,
  type BehaviorTransformerContext,
  type MutableValueTransformer,
  transformerTypes,
  type ValueTransformer,
} from "discourse/lib/transformer";

interface HookContext {
  categoryId: number;
}

const context: HookContext = { categoryId: 42 };
const labels: string[] = [];
expectTypeOf(applyValueTransformer("labels", labels, context)).toEqualTypeOf<
  string[]
>();
expectTypeOf(
  applyMutableValueTransformer("labels", labels, context)
).toEqualTypeOf<string[]>();
expectTypeOf(
  applyValueTransformer<string | false>("label", "default")
).toEqualTypeOf<string | false>();
expectTypeOf(
  applyValueTransformer("label", "default", null, null)
).toEqualTypeOf<string>();

const valueCallback: ValueTransformer<number, HookContext> = ({
  value,
  context: hookContext,
}) => {
  expectTypeOf(value).toEqualTypeOf<number>();
  expectTypeOf(hookContext).toEqualTypeOf<HookContext | null | undefined>();
  return value + (hookContext?.categoryId ?? 0);
};
expectTypeOf(
  _registerTransformer("count", transformerTypes.VALUE, valueCallback)
).toEqualTypeOf<boolean>();

const mutableCallback: MutableValueTransformer<string[], HookContext> = ({
  value,
}) => {
  value.push("added");
};
_registerTransformer("labels", transformerTypes.VALUE, mutableCallback);

const behaviorCallback: BehaviorTransformer<Promise<number>, HookContext> = ({
  next,
  context: hookContext,
}) => {
  expectTypeOf(next()).toEqualTypeOf<Promise<number> | void>();
  expectTypeOf(hookContext).toEqualTypeOf<
    BehaviorTransformerContext<HookContext>
  >();
  expectTypeOf(hookContext._unstable_self).toEqualTypeOf<unknown>();
  return next();
};
_registerTransformer("load", transformerTypes.BEHAVIOR, behaviorCallback);
_registerTransformer("stop", transformerTypes.BEHAVIOR, () => {});

expectTypeOf(
  applyBehaviorTransformer(
    "load",
    ({ context: hookContext }) => {
      expectTypeOf(hookContext.categoryId).toEqualTypeOf<number>();
      return Promise.resolve(hookContext.categoryId);
    },
    context
  )
).toEqualTypeOf<Promise<number> | void>();
expectTypeOf(applyBehaviorTransformer("stop", () => {})).toEqualTypeOf<void>();

withPluginApi((api) => {
  expectTypeOf(api.addValueTransformerName)
    .parameter(0)
    .toEqualTypeOf<string>();
  expectTypeOf(api.addBehaviorTransformerName)
    .parameter(0)
    .toEqualTypeOf<string>();
  expectTypeOf(
    api.registerValueTransformer("count", valueCallback)
  ).toEqualTypeOf<boolean>();
  expectTypeOf(
    api.registerBehaviorTransformer("load", behaviorCallback)
  ).toEqualTypeOf<boolean>();
  api.registerValueTransformer("labels", mutableCallback);
  api.registerValueTransformer<number, HookContext>(
    "count",
    ({ value, context: hookContext }) => {
      expectTypeOf(value).toEqualTypeOf<number>();
      expectTypeOf(hookContext).toEqualTypeOf<HookContext | null | undefined>();
      return value;
    }
  );
  api.registerBehaviorTransformer<Promise<number>, HookContext>(
    "load",
    ({ next, context: hookContext }) => {
      expectTypeOf(next()).toEqualTypeOf<Promise<number> | void>();
      expectTypeOf(hookContext.categoryId).toEqualTypeOf<number>();
      return next();
    }
  );
});

expectTypeOf<
  ValueTransformer<number, HookContext>
>().returns.toEqualTypeOf<number>();
expectTypeOf<
  MutableValueTransformer<string[], HookContext>
>().returns.toEqualTypeOf<void>();
expectTypeOf<MutableValueTransformer<string[], HookContext>>()
  .parameter(0)
  .toEqualTypeOf<Parameters<ValueTransformer<string[], HookContext>>[0]>();
expectTypeOf<
  ({ value }: { value: number; context: HookContext }) => string
>().not.toExtend<ValueTransformer<number, HookContext>>();
