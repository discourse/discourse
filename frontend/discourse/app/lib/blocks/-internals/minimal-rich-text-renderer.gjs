// @ts-check
import eq from "discourse/truth-helpers/helpers/eq";
/** @type {import("discourse/ui-kit/marked-text.gjs")} */
import MarkedText from "discourse/ui-kit/marked-text";

/**
 * A single inline rich-text run: a marked-text segment, or a hard break.
 *
 * @typedef {object} RichTextRun
 * @property {string} type - The run kind, e.g. "text" or "hard_break".
 * @property {string} [text] - The text content, for a text run.
 * @property {Array} [marks] - The marks applied to the text, for a text run.
 */

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
 *
 * @type {import("@ember/component/template-only").TOC<{ Args: { runs: RichTextRun[], arg?: string, schema?: string, placeholder?: string, isEmpty?: boolean } }>}
 */
const MinimalRichTextRenderer = <template>
  {{~#each @runs as |run|~}}
    {{~#if (eq run.type "hard_break")~}}
      <br />
    {{~else~}}
      <MarkedText @text={{run.text}} @marks={{run.marks}} />
    {{~/if~}}
  {{~/each~}}
</template>;

export default MinimalRichTextRenderer;
