import {
  type BlockCategory,
  type BlockNamespaceType,
  type BlockThumbnail,
} from "discourse/blocks/types";
import {
  type BlockDisplayCategory,
  getBlockDisplayMetadata,
} from "discourse/lib/blocks/-internals/display-metadata";
import type BlocksService from "discourse/services/blocks";

/**
 * What the palette's Recent group offers before a layout has taught it
 * anything: the blocks a page is most likely to start with, in the order they
 * are usually reached for.
 */
export const RECENT_FALLBACK: readonly string[] = [
  "layout",
  "heading",
  "paragraph",
  "image",
  "card",
  "list",
];

/**
 * Within each group, the blocks worth reaching first, in that order. Blocks
 * not named here follow alphabetically, which is where a plugin's block lands.
 */
export const CATEGORY_LEADS: Readonly<
  Record<BlockCategory, readonly string[]>
> = {
  layout: [
    "layout",
    "section",
    "head",
    "spacer",
    "divider",
    "tabs",
    "accordion",
    "carousel",
    "table",
  ],
  text: ["heading", "paragraph", "list", "quote", "callout", "stats"],
  media: ["image", "video", "embed", "icon"],
  actions: [
    "card",
    "media-card",
    "wf:cta-card",
    "cta-banner",
    "wf:cta-actions",
    "button-link",
    "new-topic-button",
    "link-list",
  ],
  community: [
    "recent-topics",
    "topic-card",
    "featured-topics",
    "featured-categories",
    "featured-tags",
    "featured-badges",
    "featured-users",
    "category-banner",
    "tag-banner",
  ],
};

/**
 * Orders two entries of the same group: by their place in the group's lead
 * list, then by display name for everything after it.
 *
 * @param a - One entry.
 * @param b - The other entry.
 * @returns A comparator result for `Array#sort`.
 */
export function compareWithinCategory(
  a: BlockPaletteEntry,
  b: BlockPaletteEntry
): number {
  const leads =
    a.category === "uncategorized" ? [] : (CATEGORY_LEADS[a.category] ?? []);
  const rank = (name: string) => {
    const index = leads.indexOf(name);
    return index === -1 ? leads.length : index;
  };
  return (
    rank(a.name) - rank(b.name) || a.displayName.localeCompare(b.displayName)
  );
}

/**
 * A single row of the block palette, as returned by {@link buildBlockPalette}.
 * Every face of the palette consumes this shape.
 */
export interface BlockPaletteEntry {
  /** The registered block name. */
  name: string;

  /** Human-readable display label. */
  displayName: string;

  /** Icon ID representing the block. */
  icon: string;

  /** The group the block is listed under (`"uncategorized"` when unknown). */
  category: BlockDisplayCategory;

  /** Human-readable description of the block (empty when unset). */
  description: string;

  /** Where the block was registered from (defaults to `"core"`). */
  namespaceType: BlockNamespaceType;

  /**
   * The optional preview a block may declare — a URL string, a light/dark
   * image pair, a component, or a lazy loader — or `null` when the tile falls
   * back to a default placeholder.
   */
  thumbnail: BlockThumbnail | null;

  /** Whether the block is omitted from block-selection listings. */
  paletteHidden: boolean;
}

/**
 * Builds the editor's block palette: every registered block, filtered
 * to those the author can pick (`paletteHidden !== true`) and sorted by
 * displayName.
 *
 * This is the single source of truth for the palette shape. Every face of
 * the palette consumes it — the sidebar panel, the empty-state placeholder
 * popover (outlet root, empty container, slot, grid cell), and the
 * quick-inserter — so they list the same blocks with the same metadata.
 * Sorting is by displayName only; callers that group (the sidebar's
 * category sections) or re-order (the inserter's curated-first suggestions)
 * layer their own ordering on top, and within any such group the
 * displayName order is preserved.
 *
 * `description` and `namespaceType` are read off the raw block metadata
 * (they're not part of the resolved display metadata); `thumbnail` is the
 * optional preview a block may declare — a URL string or an inline SVG
 * component (`null` when it doesn't, in which case the tile falls back to a
 * default placeholder).
 *
 * @param blocksService - The `blocks` service (`@service blocks`).
 * @returns The pickable palette rows, sorted by display name.
 */
export function buildBlockPalette(
  blocksService: BlocksService
): BlockPaletteEntry[] {
  return blocksService
    .listBlocksWithMetadata()
    .map(({ name, component, metadata }) => {
      // `getBlockDisplayMetadata` returns `null` only for an unresolved lazy
      // factory (exactly when `metadata` is `null`); every real registered
      // block resolves to a full metadata object, so the fallbacks below only
      // guard that impossible-in-practice path.
      const display = getBlockDisplayMetadata(component);
      return {
        name,
        displayName: display?.displayName ?? "",
        icon: display?.icon ?? "",
        category: display?.category ?? "uncategorized",
        description: metadata?.description ?? "",
        namespaceType: metadata?.namespaceType ?? "core",
        thumbnail: display?.thumbnail ?? null,
        paletteHidden: display?.paletteHidden === true,
      };
    })
    .filter((row) => !row.paletteHidden)
    .sort((a, b) => a.displayName.localeCompare(b.displayName));
}
