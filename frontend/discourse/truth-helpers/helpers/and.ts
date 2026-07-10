import truthConvert, {
  type MaybeTruthy,
  type TruthConvert,
} from "../utils/truth-convert";

/**
 * The type of the first falsy argument (or the last one if none are falsy),
 * mirroring the runtime short-circuit below. When an argument's truthiness
 * can't be resolved at compile time, both it and the result of continuing the
 * search are included.
 */
type FirstFalsy<T> = T extends [infer Item]
  ? Item
  : T extends [infer Head, ...infer Tail]
    ? TruthConvert<Head> extends false
      ? Head
      : TruthConvert<Head> extends true
        ? FirstFalsy<Tail>
        : Head | FirstFalsy<Tail>
    : false;

export default function and<const T extends MaybeTruthy[]>(
  ...args: T
): FirstFalsy<T>;

export default function and(...args: MaybeTruthy[]) {
  let arg: MaybeTruthy = false;

  for (arg of args) {
    if (truthConvert(arg) === false) {
      return arg;
    }
  }

  return arg;
}
