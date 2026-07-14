// @ts-check
import eq from "discourse/truth-helpers/helpers/eq";
import MarkedText from "discourse/ui-kit/marked-text";

/**
 * Editor-aware implementation of the rich-text inner-content component
 * yielded as `R.Content` by `RichTextRenderer`. Swapped in over the
 * minimal default by the wireframe service's `enter()` (and reverted
 * by `exit()`) so the scaffold is only present while the editor is
 * actively open.
 *
 * Two nested spans, both load-bearing inside the editor:
 *
 *   - **Outer** (`.wf-rich-text`): the portal mount target the
 *     editor's controller uses. `{{#in-element ... insertBefore=null}}`
 *     appends the editor mount span here as a sibling of `__content`
 *     so the rendered text isn't wiped during edit. Carries three data
 *     attributes: `data-block-arg` (the arg this element renders, a
 *     generic marker shared with image overlays / URL tooltips / the
 *     chrome's click dispatch), `data-block-arg-schema` (the PM schema
 *     variant, read when mounting the editor), and `data-wf-rich-text-arg`
 *     (the dedicated "this is an in-place-editable rich-text field" marker
 *     the in-place text subsystem keys off — see below).
 *   - **Inner** (`.wf-rich-text__content`): the hide target.
 *     CSS hides this span while PM is mounted (rule keys off the
 *     `.wf-rich-text-editor-mount` sibling) so the user sees only the
 *     editor. The wrapper also bundles raw text nodes — `MarkedText`
 *     emits the run text directly for unmarked runs, and CSS can't
 *     `display: none` text nodes, so a single container is required.
 *
 * The `--empty` modifier on the outer span is the explicit
 * replacement for `:empty` (Glimmer's comment / whitespace text
 * nodes inside the content span would defeat that pseudo-class).
 *
 * `data-wf-rich-text-arg` is what the in-place text subsystem
 * (`inplace-text-controller`'s Tab navigation + editor mount target)
 * enumerates — only elements carrying it are reachable as inline-text
 * fields, so image / URL / icon args (which never emit it) can't become
 * edit targets. The chrome's click dispatch is separate: it still derives
 * the per-arg "kind" from schema metadata via `kindForArg` against the
 * generic `data-block-arg`, to route image / URL / rich-text clicks.
 */
const ScaffoldedRichTextRenderer = <template>
  <span
    class="wf-rich-text {{if @isEmpty '--empty'}}"
    data-block-arg={{@arg}}
    data-block-arg-schema={{@schema}}
    data-wf-rich-text-arg={{@arg}}
    ...attributes
  ><span
      class="wf-rich-text__content"
      data-wf-placeholder={{if @isEmpty @placeholder}}
    >{{#each @runs as |run|}}{{#if (eq run.type "hard_break")}}<br
          />{{else}}<MarkedText
            @text={{run.text}}
            @marks={{run.marks}}
          />{{/if}}{{/each}}</span></span>
</template>;

export default ScaffoldedRichTextRenderer;
