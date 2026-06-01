// @ts-check
import { trackedObject } from "@ember/reactive/collections";

/**
 * Kind-keyed registry of OVERRIDE renderers for block-arg values that need
 * real DOM beyond the plain rendered value (rich-text's mount structure,
 * etc.). Empty by default — a kind with no entry falls back to the renderer
 * the block-facing wrapper supplies (see `rich-text-renderer.gjs`).
 *
 * Tooling that drives in-session editing swaps in a richer variant for a
 * kind via {@link registerBlockArgRenderer} and restores the default with
 * {@link resetBlockArgRenderer}.
 *
 * Crucially this module imports NO component. It's re-exported through the
 * `discourse/blocks` public facade, which other bundles (plugins) resolve
 * synchronously via the runtime loader; dragging a (code-split) component
 * into that facade's eager graph would make the lookup miss. Keeping the
 * default renderer in the wrapper instead leaves this module lightweight.
 *
 * `trackedObject` (the factory, not `new TrackedObject(...)`) makes per-key
 * reads reactive, so a component consuming `blockArgRenderers["rich-text"]`
 * re-renders the moment a swap happens.
 *
 * @module discourse/lib/blocks/-internals/arg-renderers
 */
export const blockArgRenderers = trackedObject({});

/**
 * Replaces the renderer for an arg kind. Consumers that drive in-session
 * editing call this to mount an edit-aware variant; the swap is reactive,
 * so any block currently rendering that kind re-renders immediately.
 *
 * @param {string} kind - The arg kind, e.g. `"rich-text"`.
 * @param {object} component - The component to render values of that kind.
 * @returns {void}
 */
export function registerBlockArgRenderer(kind, component) {
  blockArgRenderers[kind] = component;
}

/**
 * Clears the override for an arg kind so it falls back to the wrapper's
 * default renderer. Pairs with {@link registerBlockArgRenderer} to undo a
 * swap when editing ends.
 *
 * @param {string} kind - The arg kind, e.g. `"rich-text"`.
 * @returns {void}
 */
export function resetBlockArgRenderer(kind) {
  blockArgRenderers[kind] = undefined;
}
