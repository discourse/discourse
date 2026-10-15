import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import type { ComponentLike } from "@glint/template";
import { blockArgRenderers } from "discourse/lib/blocks/-internals/arg-renderers";
import MinimalRichTextRenderer, {
  type MinimalRichTextRendererSignature,
  type RichTextRun,
} from "./minimal-rich-text-renderer";

/**
 * A doc-JSON rich-inline value: an object carrying a `content` array of runs.
 * Plain strings are the other accepted `@value` shape.
 */
interface RichInlineDoc {
  /**
   * Author-supplied runs; typed loosely at the boundary and narrowed to
   * `RichTextRun[]` by `runs` below (the stored content isn't statically
   * known).
   */
  content?: unknown[];
}

interface RichTextRendererSignature {
  Args: {
    /**
     * The stored rich-inline value: a plain string, a doc-JSON object, or a
     * nullish value (treated as empty).
     */
    value?: string | RichInlineDoc | null;

    /** The arg name the value is stored under, forwarded to the renderer. */
    arg?: string;

    /** The schema variant, forwarded to the renderer. */
    schema?: string;

    /** Placeholder text, forwarded to the renderer. */
    placeholder?: string;
  };
  Blocks: {
    default: [
      renderer: {
        /**
         * The curried inner-content component the author wraps in their own
         * element.
         */
        Content: ComponentLike;
        /** Whether the value contains no runs. */
        isEmpty: boolean;
      },
    ];
  };
}

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
export default class RichTextRenderer extends Component<RichTextRendererSignature> {
  /**
   * Normalizes the value to a content array. Plain strings become a
   * single text run; doc-JSON's `content` array is returned as-is;
   * everything else (null / undefined / unrecognised shape) becomes an
   * empty array.
   */
  get runs(): RichTextRun[] {
    const value = this.args.value;
    if (typeof value === "string") {
      return value ? [{ type: "text", text: value, marks: [] }] : [];
    }
    if (value && Array.isArray(value.content)) {
      return value.content as RichTextRun[];
    }
    return [];
  }

  /**
   * Whether the value contains no runs. Authors typically wire this to
   * an `aria-hidden` attribute on the outer element (for accessibility)
   * and to a BEM `--empty` modifier (so the wrapper collapses visually
   * on the reader page).
   */
  get isEmpty(): boolean {
    return this.runs.length === 0;
  }

  /**
   * The active inner-content implementation. Reads the override registry on
   * each render (so a runtime swap fires a re-render of `R.Content`
   * consumers) and falls back to the minimal live renderer when no override
   * is registered. The default lives here rather than in the registry so the
   * registry — and the `discourse/blocks` facade that re-exports it — stays
   * free of any component dependency (see arg-renderers).
   */
  get contentComponent(): ComponentLike<MinimalRichTextRendererSignature> {
    // The registry is an untyped, dynamically keyed store; annotate the read
    // to keep the return precise rather than widening to an implicit `any`.
    const override = (
      blockArgRenderers as Record<
        string,
        ComponentLike<MinimalRichTextRendererSignature> | undefined
      >
    )["rich-text"];
    return override ?? MinimalRichTextRenderer;
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
