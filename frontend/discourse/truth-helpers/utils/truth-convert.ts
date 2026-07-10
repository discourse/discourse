import { isArray } from "@ember/array";
import { get } from "@ember/object";

/**
 * The set of values `truthConvert` treats as falsy. Mirrors the runtime checks
 * below (an `{ isTruthy: false }` box, the JS falsy primitives, and an empty
 * array). Used by `and`/`or` to compute their precise return types.
 */
export type Falsy =
  | { isTruthy: false }
  | undefined
  | null
  | false
  | 0
  | 0n
  | ""
  | never[];

/**
 * Type-level counterpart of `truthConvert`: maps a value type to `true`,
 * `false`, or `boolean` when it can't be determined at compile time. This is
 * what lets `and`/`or` return the actual matched value rather than `boolean`.
 */
export type TruthConvert<T> = T extends { isTruthy: true }
  ? true
  : T extends { isTruthy: false }
    ? false
    : T extends { isTruthy: boolean }
      ? boolean
      : T extends undefined | null
        ? false
        : T extends boolean
          ? T
          : T extends number
            ? T extends 0
              ? false
              : number extends T
                ? boolean
                : true
            : T extends bigint
              ? T extends 0n
                ? false
                : bigint extends T
                  ? boolean
                  : true
              : T extends string
                ? T extends ""
                  ? false
                  : string extends T
                    ? boolean
                    : true
                : T extends never[]
                  ? false
                  : T extends ArrayLike<unknown>
                    ? boolean
                    : T extends object
                      ? true
                      : boolean;

/** Any value the truth helpers accept as an argument. */
export type MaybeTruthy =
  | { isTruthy: boolean }
  | undefined
  | null
  | boolean
  | number
  | bigint
  | string
  | unknown[]
  | object;

export default function truthConvert(result: unknown): boolean {
  const truthy = result && get(result as object, "isTruthy");
  if (typeof truthy === "boolean") {
    return truthy;
  }

  if (isArray(result)) {
    return get(result, "length") !== 0;
  } else {
    return !!result;
  }
}
