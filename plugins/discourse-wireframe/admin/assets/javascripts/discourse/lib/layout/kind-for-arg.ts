import type { BlockMetadata } from "discourse/blocks/types";

/** An in-place editor supported by block chrome. */
export type InPlaceEditKind = "rich-text" | "icon" | "url" | "image";

/**
 * Derives the in-place edit "kind" for a block arg from the block's
 * schema metadata. Used by `block-chrome.gts`'s onClick handler to
 * dispatch a click on a `[data-block-arg="..."]` element to the right
 * edit-state (rich text editor, icon picker, link popover, …).
 *
 * The kind is intentionally NOT emitted on the rendered DOM — it's
 * derivable from the single source of truth (the block's arg schema),
 * so duplicating it as a data-attr would just be a way to drift out
 * of sync. Add a new kind by:
 *
 *   1. Adding a clause here that maps the arg's schema shape to the
 *      kind key.
 *   2. Handling the kind in `block-chrome.gts`'s onClick switch.
 *
 * @param blockMetadata - The block's metadata
 *   object (returned by `blocks.getBlock(blockName)?.metadata` or
 *   passed in from a block-chrome instance via `this.metadata`).
 * @param argName - The arg name from `data-block-arg`.
 * @returns The in-place edit kind,
 *   or `null` when the arg's schema doesn't match a supported kind (the
 *   click should fall through to block selection).
 */
export function kindForArg(
  blockMetadata: BlockMetadata | null | undefined,
  argName: string
): InPlaceEditKind | null {
  const arg = blockMetadata?.args?.[argName];
  if (!arg) {
    return null;
  }
  if (arg.type === "richInline") {
    return "rich-text";
  }
  if (arg.type === "image") {
    return "image";
  }
  if (arg.ui?.control === "icon") {
    return "icon";
  }
  if (arg.ui?.control === "url") {
    return "url";
  }
  return null;
}
