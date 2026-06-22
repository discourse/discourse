// @ts-check
import { DEBUG } from "@glimmer/env";
import { isTesting } from "discourse/lib/environment";

/**
 * Marker key used to distinguish a build-time customization-source descriptor
 * from arbitrary user arguments. A registered symbol is used (rather than a
 * string key) so that ordinary object data — e.g. a bogus `opts` argument —
 * can never be mistaken for a descriptor.
 *
 * The asset processor injects descriptors carrying this key into plugin/theme
 * calls to the API-entry functions (e.g. `withPluginApi`, `apiInitializer`), and
 * the runtime checks for it before treating a trailing argument as a source.
 *
 * IMPORTANT: keep this registry key in sync with the `Symbol.for(...)` literal
 * emitted by the `inject-customization-source` babel plugin in
 * `frontend/asset-processor`.
 *
 * @type {symbol}
 */
export const SOURCE_BRAND = Symbol.for("discourse:customization-source");

/**
 * The origin of a piece of customization code, determined at build time.
 *
 * @typedef {Object} CustomizationSource
 * @property {"plugin"|"theme"} type - Whether the code came from a plugin or a theme.
 * @property {string} [name] - The plugin name (for `type: "plugin"`).
 * @property {number} [id] - The theme id (for `type: "theme"`).
 */

/**
 * Returns true if the given value is a branded customization-source descriptor.
 *
 * @param {unknown} value - The value to test.
 * @returns {value is CustomizationSource} True if it is a source descriptor.
 */
export function isCustomizationSource(value) {
  return (
    typeof value === "object" && value !== null && value[SOURCE_BRAND] === true
  );
}

/**
 * Maps a customization-source descriptor to its stable identifier string.
 *
 * Plugins are keyed by name (`plugin:<name>`); themes are keyed by their
 * immutable id (`theme:<id>`). Core code has no descriptor and resolves to null.
 *
 * @param {CustomizationSource|null|undefined} source - The source descriptor.
 * @returns {string|null} Identifier like "plugin:chat" or "theme:42", or null for core.
 */
export function resolveSourceId(source) {
  if (!source) {
    return null;
  }
  if (source.type === "plugin") {
    return `plugin:${source.name}`;
  }
  if (source.type === "theme") {
    return `theme:${source.id}`;
  }
  return null;
}

/**
 * The authoritative source id of the plugin/theme initializer currently running,
 * recorded by app boot from the (unspoofable) module name. Used only in
 * development to flag code whose build-injected source went missing.
 *
 * @type {string|null|undefined}
 */
let _expectedSourceId;

const _warnedMismatches = DEBUG ? new Set() : null;

/**
 * Runs `fn` while recording `sourceId` as the expected source for any
 * registration that happens synchronously within it. A no-op in production.
 *
 * @template T
 * @param {string|null} sourceId - The authoritative source id, or null for core.
 * @param {() => T} fn - The function to run.
 * @returns {T} The result of `fn`.
 */
export function runWithExpectedSourceId(sourceId, fn) {
  if (!DEBUG) {
    return fn();
  }

  const previous = _expectedSourceId;
  _expectedSourceId = sourceId;
  try {
    return fn();
  } finally {
    _expectedSourceId = previous;
  }
}

/**
 * Development-only check: warns once when a registration's build-injected source
 * does not match the authoritative source of the initializer that is running.
 * This catches code that reaches an API-entry function through an indirect
 * reference (an aliased local, a dynamic import, or a namespace import) the build
 * transform cannot attribute. Stripped from production and silent in tests.
 *
 * @param {string|null} resolvedSourceId - The id resolved from the build-injected source.
 */
export function warnIfSourceUnexpected(resolvedSourceId) {
  if (!DEBUG || isTesting()) {
    return;
  }

  const expected = _expectedSourceId;
  if (!expected || resolvedSourceId === expected) {
    return;
  }

  const key = `${expected}|${resolvedSourceId ?? "core"}`;
  if (_warnedMismatches.has(key)) {
    return;
  }
  _warnedMismatches.add(key);

  // eslint-disable-next-line no-console
  console.warn(
    `[customization-source] Code from ${expected} performed a registration that resolved to ` +
      `"${resolvedSourceId ?? "core"}". This usually means an API-entry function was reached ` +
      `through an indirect reference (an aliased local, a dynamic import, or a namespace import) ` +
      `that the build cannot attribute. Call withPluginApi / apiInitializer directly so the ` +
      `source is tracked.`
  );
}
