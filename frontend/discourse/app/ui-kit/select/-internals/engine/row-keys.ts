import { assert } from "@ember/debug";

/**
 * Starts every key the engine builds for a row of its own (group rows, the none row, loading
 * skeletons). A record key that already starts with it is escaped, so the two never collide.
 */
export const ENGINE_KEY_PREFIX = "__ds:";

/** A key for a row the engine builds. `tag` never starts with {@link ENGINE_KEY_PREFIX}. */
export function engineKey(tag: string): string {
  return `${ENGINE_KEY_PREFIX}${tag}`;
}

/** A record's key, escaped when it would read as an engine key. */
export function recordKey(key: string): string {
  return key.startsWith(ENGINE_KEY_PREFIX) ? engineKey(key) : key;
}

/**
 * The identity of a group key, shared by grouping and the keys of group rows. Keys that print
 * the same form one group; an unset key is tagged apart so it never joins the string
 * `"undefined"`.
 */
export function groupIdentity(key: unknown): string {
  assert(
    "DSelect: a group key must be a primitive",
    key === null || (typeof key !== "object" && typeof key !== "function")
  );
  return key === undefined ? "u" : `s:${String(key)}`;
}
