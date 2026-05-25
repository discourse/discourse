// @ts-check
import eq from "discourse/truth-helpers/helpers/eq";
import MarkedText from "./marked-text";

/**
 * Default "live" implementation of the rich-text inner-content
 * component yielded as `R.Content` by `RichTextRenderer`. Emits just
 * the rendered runs (`MarkedText` for marked text, `<br>` for hard
 * breaks) — no outer span, no `__content` wrapper, no data-attrs, no
 * placeholder. This is what every viewer page renders.
 *
 * The editor-aware variant lives in admin code
 * (`admin/.../components/scaffolded-rich-text-renderer.gjs`) and the
 * wireframe service swaps it in via `blockArgRenderers["rich-text"]`
 * when the editor opens. Block templates always render the public
 * `RichTextRenderer` wrapper; the implementation swap is opaque to
 * them.
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
