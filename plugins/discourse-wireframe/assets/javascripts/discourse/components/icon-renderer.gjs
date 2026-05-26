// @ts-check
import Component from "@glimmer/component";
import { blockArgRenderers } from "../lib/block-arg-renderers";

/**
 * Public wrapper for rendering inline-editable icon args. Blocks
 * consume this component and don't care which underlying
 * implementation is active — the implementation can be swapped at
 * runtime via `blockArgRenderers["icon"]`, e.g. by the wireframe
 * editor's enter / exit lifecycle.
 *
 * ```gjs
 * <h2>
 *   <IconRenderer @value={{@icon}} @arg="icon" />
 *   {{@title}}
 * </h2>
 * ```
 *
 * - `@value` — the icon id (e.g. `"heart"`). Empty values render
 *   nothing in the live default; in the scaffolded admin variant
 *   they render a placeholder glyph so the field stays clickable.
 * - `@arg` — the block-arg name to write back on commit
 *   (`data-wf-inline-edit-arg` on the scaffolded variant).
 */
export default class IconRenderer extends Component {
  /**
   * The active inner-content implementation, looked up from the
   * registry on each render so an editor-lifecycle swap fires a
   * re-render of consumers.
   */
  get contentComponent() {
    return blockArgRenderers["icon"];
  }

  <template>
    {{! template-lint-disable no-yield-only }}
    <this.contentComponent @value={{@value}} @arg={{@arg}} ...attributes />
  </template>
}
