import { trackedObject } from "@ember/reactive/collections";
import MinimalIconRenderer from "../components/minimal-icon-renderer.gjs";
import MinimalRichTextRenderer from "../components/minimal-rich-text-renderer.gjs";

/**
 * Kind-keyed registry of inline-edit-aware renderers for block-arg
 * values. Each key (`"rich-text"`, `"icon"`, future `"image"` /
 * `"link"` / `"button-label"` / …) maps to a component that renders
 * that kind of value.
 *
 * The default entries are minimal renderers: they emit just the value
 * with no editor scaffolding, no data-attrs — the same DOM a live
 * reader gets. The wireframe admin bundle swaps each kind to its
 * "scaffolded" variant when the editor opens, and back to the minimal
 * variant when it closes (see `services/wireframe.js`'s `enter()` and
 * `exit()`).
 *
 * Why `trackedObject` (factory function, not `new TrackedObject(...)`):
 * per-key reads are reactive, so a component consuming
 * `blockArgRenderers["rich-text"]` re-renders the moment the editor's
 * lifecycle swaps in / out the scaffolded variant.
 */
export const blockArgRenderers = trackedObject({
  "rich-text": MinimalRichTextRenderer,
  icon: MinimalIconRenderer,
});
