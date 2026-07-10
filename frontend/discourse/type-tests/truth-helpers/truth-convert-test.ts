import { expectTypeOf } from "expect-type";
import truthConvert, {
  type TruthConvert,
} from "discourse/truth-helpers/utils/truth-convert";

// The type-level truthiness mapping used by `and`/`or`.
expectTypeOf<TruthConvert<0>>().toEqualTypeOf<false>();
expectTypeOf<TruthConvert<1>>().toEqualTypeOf<true>();
expectTypeOf<TruthConvert<"">>().toEqualTypeOf<false>();
expectTypeOf<TruthConvert<"x">>().toEqualTypeOf<true>();
expectTypeOf<TruthConvert<never[]>>().toEqualTypeOf<false>();
expectTypeOf<TruthConvert<{ isTruthy: true }>>().toEqualTypeOf<true>();
expectTypeOf<TruthConvert<{ isTruthy: false }>>().toEqualTypeOf<false>();
// A wide `string` can't be resolved at compile time.
expectTypeOf<TruthConvert<string>>().toEqualTypeOf<boolean>();

// The runtime function always narrows to a plain `boolean`.
expectTypeOf(truthConvert).toEqualTypeOf<(result: unknown) => boolean>();
