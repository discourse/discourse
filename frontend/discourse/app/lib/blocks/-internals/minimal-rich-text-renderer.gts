import type { TemplateOnlyComponent } from "@ember/component/template-only";
import eq from "discourse/truth-helpers/helpers/eq";
import MarkedText from "discourse/ui-kit/marked-text";

/**
 * A single inline rich-text run: a marked-text segment, or a hard break.
 */
export interface RichTextRun {
  /** The run kind, e.g. "text" or "hard_break". */
  type: string;

  /** The text content, for a text run. */
  text?: string;

  /** The marks applied to the text, for a text run. */
  marks?: unknown[];
}

export interface MinimalRichTextRendererSignature {
  Args: {
    /** The inline runs to render. */
    runs: RichTextRun[];

    /**
     * The arg name this value is stored under (forwarded to edit-aware
     * variants; unused by the minimal renderer).
     */
    arg?: string;

    /** The schema variant (forwarded to edit-aware variants; unused here). */
    schema?: string;

    /** Placeholder text (forwarded to edit-aware variants; unused here). */
    placeholder?: string;

    /**
     * Whether the value is empty (forwarded to edit-aware variants; unused
     * here).
     */
    isEmpty?: boolean;
  };
}

/**
 * Default live implementation of the rich-text inner-content component
 * yielded as `R.Content` by `RichTextRenderer`. Emits just the rendered
 * runs (`MarkedText` for marked text, `<br>` for hard breaks) — no outer
 * span, no wrapper element, no data-attributes, no placeholder. This is
 * what every reader page renders.
 *
 * An edit-aware variant can replace this entry in the arg-renderer
 * registry (via `registerBlockArgRenderer`) during in-session editing;
 * block templates always render the public `RichTextRenderer` wrapper, so
 * the swap is opaque to them.
 */
const MinimalRichTextRenderer: TemplateOnlyComponent<MinimalRichTextRendererSignature> =
  <template>
    {{~#each @runs as |run|~}}
      {{~#if (eq run.type "hard_break")~}}
        <br />
      {{~else~}}
        <MarkedText @text={{run.text}} @marks={{run.marks}} />
      {{~/if~}}
    {{~/each~}}
  </template>;

export default MinimalRichTextRenderer;
