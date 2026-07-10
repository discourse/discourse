import truthConvert, {
  type Falsy,
  type MaybeTruthy,
  type TruthConvert,
} from "../utils/truth-convert";

/**
 * The type of the first truthy argument (or the last one if none are truthy),
 * mirroring the runtime short-circuit below. When an argument's truthiness
 * can't be resolved at compile time, both it (minus its falsy members) and the
 * result of continuing the search are included.
 */
type FirstTruthy<T> = T extends [infer Item]
  ? Item
  : T extends [infer Head, ...infer Tail]
    ? TruthConvert<Head> extends true
      ? Head
      : TruthConvert<Head> extends false
        ? FirstTruthy<Tail>
        : Exclude<Head, Falsy> | FirstTruthy<Tail>
    : false;

export default function or<const T extends MaybeTruthy[]>(
  ...args: T
): FirstTruthy<T>;

export default function or(...args: MaybeTruthy[]) {
  let arg: MaybeTruthy = false;

  for (arg of args) {
    if (truthConvert(arg) === true) {
      return arg;
    }
  }

  return arg;
}
