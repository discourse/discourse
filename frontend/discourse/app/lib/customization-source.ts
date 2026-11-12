/**
 * Key under which the asset processor puts a plugin's or theme's source on the
 * `opts` of an API-entry function. Re-exported from `discourse/lib/api` so the
 * generated wrappers can reach it; nothing else may read or write it.
 */
export const _INTERNAL_SOURCE_KEY = Symbol("customization source");

/** The origin of a piece of customization code. */
export type CustomizationSource =
  | { type: "core" }
  | { type: "plugin"; name: string }
  | { type: "theme"; id: number };

/** The source of code shipped with core, rather than a plugin or theme. */
export const CORE_SOURCE: Readonly<CustomizationSource> = Object.freeze({
  type: "core",
});

/**
 * Maps a source to a stable identifier: `plugin:<name>` or `theme:<id>`. Themes
 * are keyed by id because their name can change.
 *
 * @returns null for core, which has no namespace of its own.
 */
export function resolveSourceId(
  source?: CustomizationSource | null
): string | null {
  if (source?.type === "plugin") {
    return `plugin:${source.name}`;
  }
  if (source?.type === "theme") {
    return `theme:${source.id}`;
  }
  return null;
}
