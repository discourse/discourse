import type { ArgSchema } from "discourse/blocks/types";

/** An image argument and its current editor state. */
export type ImageArgEntry = {
  /** The image argument schema. */
  def: ArgSchema;

  /** Whether the value has no usable URL. */
  isEmpty: boolean;

  /** The argument name. */
  name: string;

  /** The current argument value. */
  value: ImageArgValue | null | undefined;
};

/** The persisted shape of an image argument. */
export type ImageArgValue = Record<string, unknown> & {
  /** Persisted image source kind. */
  source?: "upload" | "url";
  /** Server upload identifier used to retain uploaded files. */
  upload_id?: string;
  /** Display height in pixels. */
  height?: number;
  /** Intrinsic image height in pixels. */
  naturalHeight?: number;
  /** Intrinsic image width in pixels. */
  naturalWidth?: number;
  /** Display width in pixels. */
  width?: number;
  /** The image URL. */
  url?: string;
  /** Optional dark-scheme image variant. */
  dark?: ImageArgValue;
};

/**
 * Checks whether a runtime argument value can be read as an image value.
 *
 * @param value - Runtime argument value.
 * @returns Whether the value is a non-array object.
 */
export function isImageArgValue(value: unknown): value is ImageArgValue {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/**
 * Per-arg primitives for image-typed args. The chrome uses these to
 * decide which empty-state overlays to paint, which drop targets to
 * register, and which replace menus to open. Stays a pure module — no
 * service reads, no DOM — so it can be unit-tested with plain JS
 * fixtures.
 *
 * Supports multi-image blocks (e.g. `wf:media-card` with both an
 * avatar and a cover image) and the inline editing affordances on the
 * first-class `image` arg type.
 */

/**
 * Returns an array of image arg entries declared on the schema, in
 * declaration order. Each entry carries enough metadata for the chrome
 * to decide what overlay to paint:
 *
 *   - `name`: the arg name as it appears under `entry.args`
 *   - `def`: the raw schema entry (capability flags, ui hints, …)
 *   - `value`: the live value, or `undefined` when unset
 *   - `isEmpty`: `true` when no `url` is set (treats nullish and
 *     `{ width, height }` without `url` as empty)
 *
 * @param argsSchema - The block's args schema
 *   (the `args` field on block metadata, keyed by arg name).
 * @param liveArgs - The entry's live args
 *   object, keyed by arg name.
 * @returns Image arguments in schema declaration order.
 */
export function imageArgEntries(
  argsSchema: Record<string, ArgSchema> | null | undefined,
  liveArgs: Record<string, unknown> | null | undefined
): ImageArgEntry[] {
  if (!argsSchema || typeof argsSchema !== "object") {
    return [];
  }
  const args = liveArgs ?? {};
  const out: ImageArgEntry[] = [];
  for (const [name, def] of Object.entries(argsSchema)) {
    if (def?.type !== "image") {
      continue;
    }
    // TODO(devxp-typescript-pending): remove this cast once core's image
    // argument type is represented in `ArgSchema`/`LayoutEntry.args`. Core
    // currently exposes live argument values as `unknown` even after schema
    // validation, while an image value has this documented persisted shape.
    const value = args[name] as ImageArgValue | null | undefined;
    out.push({ name, def, value, isEmpty: isImageArgValueEmpty(value) });
  }
  return out;
}

/**
 * Returns `true` when the given image-arg value has no usable `url`.
 * Matches the gate every image-bearing block uses in its template
 * (`{{#if @image.url}}`), so the chrome's empty-state decision agrees
 * with what the renderer actually paints.
 *
 * @param value - The candidate image argument value.
 * @returns Whether the value lacks a usable URL.
 */
export function isImageArgValueEmpty(value: unknown): boolean {
  if (!value || typeof value !== "object") {
    return true;
  }
  return (
    !("url" in value) || typeof value.url !== "string" || value.url.length === 0
  );
}

/**
 * Convenience boolean predicate: `true` when the schema declares one or
 * more image args AND every one of them is empty. Keyed off the
 * arg's `type: "image"`.
 *
 * @param argsSchema - The block's argument schema.
 * @param liveArgs - The current argument values.
 * @returns Whether the schema has image args and all of them are empty.
 */
export function entryHasOnlyEmptyImageArgs(
  argsSchema: Record<string, ArgSchema> | null | undefined,
  liveArgs: Record<string, unknown> | null | undefined
): boolean {
  const entries = imageArgEntries(argsSchema, liveArgs);
  if (entries.length === 0) {
    return false;
  }
  return entries.every((e) => e.isEmpty);
}
