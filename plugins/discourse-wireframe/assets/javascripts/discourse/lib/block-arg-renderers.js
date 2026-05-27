import { trackedObject } from "@ember/reactive/collections";
import MinimalRichTextRenderer from "../components/minimal-rich-text-renderer.gjs";

/**
 * Kind-keyed registry of inline-edit-aware renderers for block-arg
 * values that need real editor-specific DOM (rich-text's mount span
 * structure, etc.). Each key maps to a component that renders that
 * kind of value.
 *
 * The default entry is a minimal renderer: emits just the value with
 * no editor scaffolding — the same DOM a live reader gets. The
 * wireframe admin bundle swaps it to the scaffolded variant when the
 * editor opens, and back when it closes (see `services/wireframe.js`'s
 * `enter()` and `exit()`).
 *
 * Simpler kinds (icon, url) don't go through this registry — the block
 * templates emit `data-block-arg` directly on a small wrapper and the
 * editor chrome reads it on click. The registry is only for kinds
 * whose editing surface needs DOM the live renderer wouldn't provide.
 *
 * Why `trackedObject` (factory function, not `new TrackedObject(...)`):
 * per-key reads are reactive, so a component consuming
 * `blockArgRenderers["rich-text"]` re-renders the moment the editor's
 * lifecycle swaps in / out the scaffolded variant.
 */
export const blockArgRenderers = trackedObject({
  "rich-text": MinimalRichTextRenderer,
});
