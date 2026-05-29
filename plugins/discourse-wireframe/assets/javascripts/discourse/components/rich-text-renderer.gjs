// @ts-check
import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { blockArgRenderers } from "../lib/block-arg-renderers";

/**
 * Public wrapper for rendering inline rich-text args. Blocks consume
 * this component and don't care which underlying implementation is
 * active — the implementation can be swapped at runtime via
 * `blockArgRenderers["rich-text"]`, e.g. by the wireframe editor's
 * enter / exit lifecycle.
 *
 * Yields a hash so the block author chooses the wrapper element:
 *
 * ```gjs
 * <RichTextRenderer
 *   @arg="title"
 *   @schema="heading"
 *   @value={{@title}}
 *   @placeholder="Welcome"
 *   as |R|>
 *   <h3 class="wf-cta-banner__title" aria-hidden={{R.isEmpty}}>
 *     <R.Content />
 *   </h3>
 * </RichTextRenderer>
 * ```
 *
 * Yielded shape:
 *   - `R.Content`  — curried inner-content component, sourced from the
 *                    registry. On a live viewer page it's the minimal
 *                    renderer (just runs); inside the active wireframe
 *                    editor it's the scaffolded renderer (two-span,
 *                    data-attrs, placeholder host).
 *   - `R.isEmpty`  — boolean. Wire to `aria-hidden` for screen-reader
 *                    correctness, and optionally to a BEM `--empty`
 *                    modifier on the wrapper's own class so empty
 *                    fields collapse visually on the live site.
 */
export default class RichTextRenderer extends Component {
  /**
   * Normalizes the value to a content array. Plain strings become a
   * single text run; doc-JSON's `content` array is returned as-is;
   * everything else (null / undefined / unrecognised shape) becomes an
   * empty array.
   *
   * @returns {Array<object>}
   */
  get runs() {
    const value = this.args.value;
    if (typeof value === "string") {
      return value ? [{ type: "text", text: value, marks: [] }] : [];
    }
    if (value && Array.isArray(value.content)) {
      return value.content;
    }
    return [];
  }

  /**
   * Whether the value contains no runs. Authors typically wire this to
   * an `aria-hidden` attribute on the outer element (for accessibility)
   * and to a BEM `--empty` modifier (so the wrapper collapses visually
   * on the live site).
   *
   * @returns {boolean}
   */
  get isEmpty() {
    return this.runs.length === 0;
  }

  /**
   * The active inner-content implementation, looked up from the
   * registry on each render so an editor-lifecycle swap fires a
   * re-render of `R.Content` consumers.
   *
   * @returns {object}
   */
  get contentComponent() {
    return blockArgRenderers["rich-text"];
  }

  <template>
    {{yield
      (hash
        Content=(component
          this.contentComponent
          arg=@arg
          schema=@schema
          placeholder=@placeholder
          runs=this.runs
          isEmpty=this.isEmpty
        )
        isEmpty=this.isEmpty
      )
    }}
  </template>
}
