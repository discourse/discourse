// @ts-check
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";

const DEFAULT_ICON = "cube";
const DEFAULT_CATEGORY = "Misc";

/**
 * Converts a kebab-case `shortName` (e.g. `"hero-banner"`) into a
 * Title Case display string (e.g. `"Hero Banner"`). Splits on
 * hyphens AND colons so namespaced names (`"chat:thread-actions"`)
 * also render meaningfully.
 *
 * @param {string} shortName
 * @returns {string}
 */
export function titleCase(shortName) {
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
 * @param {Object|null} argsSchema
 * @returns {Object}
 */
function previewArgsFromSchema(argsSchema) {
  if (!argsSchema) {
    return {};
  }
  const out = {};
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
 * - `thumbnail` falls back to `null` (the icon is rendered instead).
 *
 * @param {Function} component - A class decorated with `@block`.
 * @returns {{displayName: string, icon: string, category: string,
 *   previewArgs: Object, thumbnail: (string|Function|Object)|null,
 *   paletteHidden: boolean, transparent: boolean}|null}
 *   The fully-resolved display metadata, or `null` if the component is
 *   not a registered block.
 */
export function getBlockDisplayMetadata(component) {
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
