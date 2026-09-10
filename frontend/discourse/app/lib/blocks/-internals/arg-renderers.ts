import { trackedObject } from "@ember/reactive/collections";
import type { ComponentLike } from "@glint/template";

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
 */
export const blockArgRenderers = trackedObject(
  {} as Record<string, ComponentLike | undefined>
);

/**
 * Replaces the renderer for an arg kind. Consumers that drive in-session
 * editing call this to mount an edit-aware variant; the swap is reactive,
 * so any block currently rendering that kind re-renders immediately.
 *
 * @param kind - The arg kind, e.g. `"rich-text"`.
 * @param component - The component to render values of that kind.
 */
export function registerBlockArgRenderer(
  kind: string,
  component: ComponentLike
): void {
  blockArgRenderers[kind] = component;
}

/**
 * Clears the override for an arg kind so it falls back to the wrapper's
 * default renderer. Pairs with {@link registerBlockArgRenderer} to undo a
 * swap when editing ends.
 *
 * @param kind - The arg kind, e.g. `"rich-text"`.
 */
export function resetBlockArgRenderer(kind: string): void {
  blockArgRenderers[kind] = undefined;
}
