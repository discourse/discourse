import type { ArgSchema, BlockThumbnail } from "discourse/blocks/types";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";

const DEFAULT_ICON = "cube";
const DEFAULT_CATEGORY = "Misc";

/**
 * The fully-resolved display-metadata vocabulary for a block, with defaults
 * filled in for fields the block author didn't explicitly set.
 */
export interface BlockDisplayMetadata {
  /** Human-readable display label. */
  displayName: string;

  /** Icon ID representing the block. */
  icon: string;

  /** Grouping label for organizing blocks. */
  category: string;

  /** Example args used to render a preview of the block. */
  previewArgs: Record<string, unknown>;

  /** Selection/preview thumbnail, or `null` when the icon is rendered instead. */
  thumbnail: BlockThumbnail | null;

  /** Whether the block is omitted from block-selection listings. */
  paletteHidden: boolean;

  /** Whether the block renders without its own wrapper element. */
  transparent: boolean;
}

/**
 * Converts a kebab-case `shortName` (e.g. `"hero-banner"`) into a
 * Title Case display string (e.g. `"Hero Banner"`). Splits on
 * hyphens AND colons so namespaced names (`"chat:thread-actions"`)
 * also render meaningfully.
 *
 * @param shortName - The kebab-case short name.
 * @returns The Title Case display string.
 */
export function titleCase(shortName: string): string {
  return shortName
    .split(/[-:]/)
    .filter(Boolean)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(" ");
}

/**
 * Builds a default `previewArgs` object from an arg schema by harvesting
 * each arg's `default` field. Args without a `default` are omitted so the
 * preview doesn't carry `undefined` placeholders into the rendered block.
 *
 * @param argsSchema - The block's arg schema, keyed by arg name.
 * @returns The harvested preview args.
 */
function previewArgsFromSchema(
  argsSchema: Record<string, ArgSchema> | null | undefined
): Record<string, unknown> {
  if (!argsSchema) {
    return {};
  }
  const out: Record<string, unknown> = {};
  for (const [key, schema] of Object.entries(argsSchema)) {
    if (schema && Object.hasOwn(schema, "default")) {
      out[key] = schema.default;
    }
  }
  return out;
}

/**
 * Returns the resolved display-metadata vocabulary for a block, filling in
 * defaults for fields the block author didn't explicitly set. Pure read-only
 * — does not mutate the registered block metadata.
 *
 * Defaults:
 * - `displayName` falls back to a Title Case of `shortName`.
 * - `icon` falls back to `"cube"`.
 * - `category` falls back to `"Misc"`.
 * - `previewArgs` falls back to a shallow object harvested from each arg
 *   schema's `default` field.
 * - `thumbnail` falls back to `null` (the icon is rendered instead). When set,
 *   it is a URL string, a `{ light, dark }` pair, a component, or a loader that
 *   resolves to a component; it is passed through untouched for the consumer to
 *   present (and to resolve, if it is a loader).
 *
 * @param component - A class decorated with `@block`.
 * @returns The fully-resolved display metadata, or `null` if the component is
 *   not a registered block.
 */
export function getBlockDisplayMetadata(
  component: object
): BlockDisplayMetadata | null {
  const metadata = getBlockMetadata(component);
  if (!metadata) {
    return null;
  }

  return {
    displayName: metadata.displayName ?? titleCase(metadata.shortName),
    icon: metadata.icon ?? DEFAULT_ICON,
    category: metadata.category ?? DEFAULT_CATEGORY,
    previewArgs: metadata.previewArgs ?? previewArgsFromSchema(metadata.args),
    thumbnail: metadata.thumbnail ?? null,
    paletteHidden: metadata.paletteHidden === true,
    transparent: metadata.transparent === true,
  };
}
