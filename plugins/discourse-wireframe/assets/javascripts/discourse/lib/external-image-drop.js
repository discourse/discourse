// @ts-check

/**
 * The synthetic drag source fed into the positional drop pipeline when an
 * OS image file is dragged over an empty, block-accepting slot. Shaped
 * exactly like a palette drag of the builtin image block, so the existing
 * descriptor / validation / dispatch builders treat a file drop the same
 * way they treat dropping an image block from the palette — the file lands
 * in the slot under the cursor as a fresh image block, which is then filled
 * by the upload.
 *
 * Frozen because it is shared, read-only, and must never be mutated by a
 * descriptor builder.
 */
export const EXTERNAL_IMAGE_DROP_SOURCE = Object.freeze({
  type: "wf-palette-block",
  data: Object.freeze({ blockName: "image", defaultArgs: {} }),
});

/**
 * Returns the first image `File` in a list (a `File[]`, `FileList`, or any
 * iterable of files), or `null` when none is an image. Used at drop time to
 * pick the single file an image-file drop will upload; per-file MIME types
 * aren't reliably exposed during dragover, so this check only runs once the
 * drop has landed and the files are readable.
 *
 * @param {Iterable<File>|null|undefined} files
 * @returns {File|null}
 */
export function firstImageFile(files) {
  for (const file of Array.from(files ?? [])) {
    if (file?.type?.startsWith("image/")) {
      return file;
    }
  }
  return null;
}
