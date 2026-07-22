import DAG from "discourse/lib/dag";

/**
 * Registry of buttons shown in the developer tools toolbar.
 *
 * This module deliberately lives outside `discourse/static/dev-tools/`. That
 * directory contains the toolbar components and the developer tools
 * stylesheet, which are code-split into a chunk that is only fetched when
 * developer tools are enabled. Anything importing from there pulls that
 * module and its transitive imports into the importer's bundle, so keeping
 * the registry here lets eager code (such as the plugin API) reference it
 * without dragging the chunk along.
 *
 * @module discourse/lib/dev-tools/registry
 */

/**
 * The identifier of the last tool shipped with Discourse.
 *
 * Tools registered without an explicit position are placed after this one, so
 * that externally registered tools appear after the core set regardless of
 * when they register. See `resetDevTools` for why that matters.
 *
 * Exported so that the developer tools entrypoint and the tests share one
 * definition: a core tool added after this one would otherwise leave them
 * disagreeing about where the core set ends.
 */
export const LAST_CORE_TOOL = "message-bus";

let devTools;
resetDevTools();

/**
 * Creates an empty registry.
 *
 * Core tools are not seeded here. Their components live in the lazily loaded
 * developer tools chunk, so importing them would defeat the code splitting
 * described above. They are added by the chunk's entrypoint instead.
 *
 * That ordering is the reason for the default position. Application
 * initializers all run synchronously during boot, while the developer tools
 * chunk arrives later in a promise callback, so anything registered through
 * the plugin API is added *before* the core tools are. Defaulting to "after
 * the last core tool" keeps the core buttons in their usual place anyway.
 * The anchor does not exist yet at that point, which is fine: the underlying
 * DAG records the constraint against a placeholder and resolves it once the
 * real entry is added.
 */
function resetDevTools() {
  devTools = new DAG({ defaultPosition: { after: LAST_CORE_TOOL } });
}

/**
 * Returns the registry, for reading or for adding entries directly.
 *
 * @returns {DAG} The developer tools toolbar registry.
 */
export function devToolsDAG() {
  return devTools;
}

/**
 * Empties the registry.
 *
 * Intended for tests. Registration happens once per application boot, and the
 * test suite creates a fresh application per test, so without this the
 * registry would accumulate entries across tests.
 */
export function clearDevTools() {
  resetDevTools();
}
