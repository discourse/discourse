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
 * The origin of a piece of customization code.
 *
 * @typedef {Object} CustomizationSource
 * @property {"core"|"plugin"|"theme"} type - Whether the code came from core, a plugin, or a theme.
 * @property {string} [name] - The plugin name (for `type: "plugin"`).
 * @property {number} [id] - The theme id (for `type: "theme"`).
 */

/**
 * The customization source for core code. Exposed as `api.source` when core
 * (rather than a plugin or theme) uses the plugin API.
 *
 * @type {Readonly<CustomizationSource>}
 */
export const CORE_SOURCE = Object.freeze({ type: "core" });

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
 * Splits the arguments of an API-entry function (`withPluginApi`/`apiInitializer`)
 * into the build-injected source and the user-facing callback/options. Strips a
 * trailing branded source descriptor and a leading legacy version string.
 *
 * @param {any[]} args - The call arguments (e.g. `Array.from(arguments)`).
 * @returns {{ source: CustomizationSource|undefined, apiCodeCallback: any, opts: any }}
 */
export function splitSourceArgs(args) {
  let source;
  if (args.length > 0 && isCustomizationSource(args[args.length - 1])) {
    source = args.pop();
  }

  if (typeof args[0] === "string") {
    // Old path. First argument is the version string. Silently ignore.
    args = args.slice(1);
  }

  return { source, apiCodeCallback: args[0], opts: args[1] };
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
  // Core (or any other type) has no namespace and resolves to null.
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
 * Development-only check: warns once per source when a registration made inside a
 * known plugin/theme initializer carried NO build-injected source (resolved to
 * core). That flags code which reached an API-entry function through an indirect
 * reference (a namespace import, a dynamic import, or a re-export) the build
 * transform cannot attribute.
 *
 * Best-effort and synchronous by design: only registrations made synchronously
 * within the initializer are checked. Registrations deferred past an await/tick,
 * and legacy `<script>`-tag plugins, resolve to core and are not flagged. A
 * registration attributed to a *different* (but present) source is treated as
 * legitimate cross-source registration, not a missing descriptor. Stripped from
 * production and silent in tests.
 *
 * @param {string|null} resolvedSourceId - The id resolved from the build-injected source.
 */
export function warnIfSourceUnexpected(resolvedSourceId) {
  if (!DEBUG || isTesting()) {
    return;
  }

  const expected = _expectedSourceId;
  // Only the real gap: a plugin/theme initializer registered something that the
  // build attributed to no source at all.
  if (!expected || resolvedSourceId !== null) {
    return;
  }

  if (_warnedMismatches.has(expected)) {
    return;
  }
  _warnedMismatches.add(expected);

  // eslint-disable-next-line no-console
  console.warn(
    `Code from ${expected} performed a registration that resolved to ` +
      `"core". This usually means an API-entry function was reached through an indirect ` +
      `reference (a namespace import, a dynamic import, or a re-export) that the build ` +
      `cannot attribute. Call withPluginApi / apiInitializer directly so the source is tracked.`
  );
}
