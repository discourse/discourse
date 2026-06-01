// @ts-check
import eq from "discourse/truth-helpers/helpers/eq";
import MarkedText from "discourse/ui-kit/marked-text";

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
