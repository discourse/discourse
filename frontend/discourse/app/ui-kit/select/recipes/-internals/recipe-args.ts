import type { DSelectSignature } from "discourse/ui-kit/select/d-select";

/** The select arguments every recipe accepts and forwards to its select unchanged. */
export const RECIPE_ARGS = [
  "identifier",
  "instanceContext",
  "legacyKind",
] as const;

/** The select arguments every recipe that can hold several values also forwards. */
export const MULTI_RECIPE_ARGS = [...RECIPE_ARGS, "lockedValues"] as const;

/** The arguments of {@link RECIPE_ARGS}, for a recipe signature to extend. */
export type SelectRecipeArgs = Pick<
  DSelectSignature["Args"],
  (typeof RECIPE_ARGS)[number]
>;

/** The names in {@link MULTI_RECIPE_ARGS}, for a recipe that picks its select arguments. */
export type MultiSelectRecipeArg = (typeof MULTI_RECIPE_ARGS)[number];

/** The arguments of {@link MULTI_RECIPE_ARGS}, for a multi-value recipe signature to extend. */
export type MultiSelectRecipeArgs = Pick<
  DSelectSignature["Args"],
  MultiSelectRecipeArg
>;
