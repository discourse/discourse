// @ts-check
import eq from "discourse/truth-helpers/helpers/eq";
import MarkedText from "discourse/plugins/discourse-wireframe/discourse/components/marked-text";

/**
 * Editor-aware implementation of the rich-text inner-content component
 * yielded as `R.Content` by `RichTextRenderer`. Swapped in over the
 * minimal default by the wireframe service's `enter()` (and reverted
 * by `exit()`) so the scaffold is only present while the editor is
 * actively open.
 *
 * Two nested spans, both load-bearing inside the editor:
 *
 *   - **Outer** (`.wf-inline-rich-text`): the portal mount target the
 *     editor's controller uses. `{{#in-element ... insertBefore=null}}`
 *     appends the editor mount span here as a sibling of `__content`
 *     so the rendered text isn't wiped during edit. Also carries
 *     `data-block-arg` (the arg this element renders) and
 *     `data-block-arg-schema` (the PM schema variant) for the
 *     click-to-edit handler.
 *   - **Inner** (`.wf-inline-rich-text__content`): the hide target.
 *     CSS hides this span while PM is mounted (rule keys off the
 *     `.wf-inline-editor-mount` sibling) so the user sees only the
 *     editor. The wrapper also bundles raw text nodes — `MarkedText`
 *     emits the run text directly for unmarked runs, and CSS can't
 *     `display: none` text nodes, so a single container is required.
 *
 * The `--empty` modifier on the outer span is the explicit
 * replacement for `:empty` (Glimmer's comment / whitespace text
 * nodes inside the content span would defeat that pseudo-class).
 *
 * The "inline-edit kind" isn't emitted on the DOM — the chrome's
 * click handler derives it from the arg's schema metadata via
 * `kindForArg`. Same applies to icon and url args.
 */
const ScaffoldedRichTextRenderer = <template>
  <span
    class="wf-inline-rich-text {{if @isEmpty '--empty'}}"
    data-block-arg={{@arg}}
    data-block-arg-schema={{@schema}}
    ...attributes
  ><span
      class="wf-inline-rich-text__content"
      data-wf-placeholder={{if @isEmpty @placeholder}}
    >{{#each @runs as |run|}}{{#if (eq run.type "hard_break")}}<br
          />{{else}}<MarkedText
            @text={{run.text}}
            @marks={{run.marks}}
          />{{/if}}{{/each}}</span></span>
</template>;

export default ScaffoldedRichTextRenderer;
