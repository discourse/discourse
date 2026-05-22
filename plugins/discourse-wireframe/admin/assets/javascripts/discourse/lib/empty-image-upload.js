// @ts-check

/**
 * Returns `true` when an entry's args schema declares one or more
 * `ui.control: "image-upload"` args AND none of them currently carry a value
 * whose `.url` is set. Used by `block-chrome` to decide whether to swap in the
 * canvas-only empty-state card while the author hasn't picked an image yet.
 *
 * Pure: no service reads, no DOM — block-chrome injects the live `args` from
 * `entry.args` and the schema from `metadata.args`, and this just enumerates.
 *
 * Treats nested object args as filled when `value.url` is a non-empty string.
 * Matches the shape `UppyImageUploader.onUploadDone` emits and the gate the
 * `wf:image` block uses in its own `{{#if @image.url}}` template.
 *
 * @param {Object|null|undefined} argsSchema - The block's args schema (the
 *   `args` field on block metadata, keyed by arg name).
 * @param {Object|null|undefined} liveArgs - The entry's live args object,
 *   keyed by arg name.
 * @returns {boolean}
 */
export function entryHasEmptyImageUploadArgs(argsSchema, liveArgs) {
  if (!argsSchema || typeof argsSchema !== "object") {
    return false;
  }
  const args = liveArgs ?? {};

  let sawImageUploadArg = false;
  for (const [name, def] of Object.entries(argsSchema)) {
    if (def?.ui?.control !== "image-upload") {
      continue;
    }
    sawImageUploadArg = true;
    const value = args[name];
    if (value && typeof value === "object" && value.url) {
      return false;
    }
  }
  return sawImageUploadArg;
}
