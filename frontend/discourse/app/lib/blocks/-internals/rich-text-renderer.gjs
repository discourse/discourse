// @ts-check
import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { blockArgRenderers } from "discourse/lib/blocks/-internals/arg-renderers";
/** @type {import("./minimal-rich-text-renderer.gjs")} */
import MinimalRichTextRenderer from "./minimal-rich-text-renderer";

/**
 * Public wrapper for rendering inline rich-text args. Blocks consume this
 * component and don't care which underlying implementation is active — the
 * implementation can be swapped at runtime via the arg-renderer registry
 * (see `registerBlockArgRenderer`), e.g. by tooling that drives in-session
 * editing.
 *
 * Yields a hash so the block author chooses the wrapper element: invoke the
 * component with the arg name, a schema variant, the stored value and a
 * placeholder, and receive a block param exposing Content and isEmpty. The
 * author wraps the yielded Content in whatever element they want (e.g. an h3),
 * wiring isEmpty to aria-hidden and, optionally, to an empty BEM modifier.
 *
 * Yielded shape:
 *   - `R.Content`  — curried inner-content component, sourced from the
 *                    registry. On a reader page it's the minimal renderer
 *                    (just emits the value); during in-session editing it's
 *                    the edit-aware variant the registry was swapped to.
 *   - `R.isEmpty`  — boolean. Wire to `aria-hidden` for screen-reader
 *                    correctness, and optionally to a BEM `--empty`
 *                    modifier on the wrapper's own class so empty fields
 *                    collapse visually on the reader page.
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
   * on the reader page).
   *
   * @returns {boolean}
   */
  get isEmpty() {
    return this.runs.length === 0;
  }

  /**
   * The active inner-content implementation. Reads the override registry on
   * each render (so a runtime swap fires a re-render of `R.Content`
   * consumers) and falls back to the minimal live renderer when no override
   * is registered. The default lives here rather than in the registry so the
   * registry — and the `discourse/blocks` facade that re-exports it — stays
   * free of any component dependency (see arg-renderers.js).
   *
   * @returns {object}
   */
  get contentComponent() {
    return blockArgRenderers["rich-text"] ?? MinimalRichTextRenderer;
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
