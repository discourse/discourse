// @ts-check
import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import eq from "discourse/truth-helpers/helpers/eq";
import MarkedText from "./marked-text";

/**
 * Pure-render walker for inline rich text content. Accepts either a plain
 * string (the common, unformatted case) or a ProseMirror doc-JSON object.
 *
 * Yields a hash so the block author chooses the wrapper element:
 *
 * ```gjs
 * <InlineRichTextRenderer
 *   @arg="title"
 *   @schema="heading"
 *   @value={{@title}}
 *   @placeholder="Welcome"
 *   as |R|>
 *   <h3 class="ve-cta-banner__title" aria-hidden={{R.isEmpty}}>
 *     <R.Content />
 *   </h3>
 * </InlineRichTextRenderer>
 * ```
 *
 * Yielded shape:
 *   - `R.Content`  — curried inner-content component. Drop it inside the
 *                    wrapper element to render the marks. Emits the data-attrs
 *                    the editor chrome's click-to-edit and PM mount target
 *                    rely on, and carries a `--empty` modifier on its outer
 *                    span whenever the value is empty.
 *   - `R.isEmpty`  — boolean. Wire to `aria-hidden` for screen-reader
 *                    correctness (empty headings / anchors no longer announced),
 *                    and optionally to a BEM `--empty` modifier on the
 *                    wrapper's own class to hide empty wrappers visually on
 *                    the live site. The chrome's `--selected` reveal rule
 *                    re-shows them on the canvas so placeholders stay
 *                    clickable.
 *
 * The data-attrs on `<R.Content />`'s outer span are inert on the live site —
 * nothing listens for them.
 */
export default class InlineRichTextRenderer extends Component {
  /**
   * Normalize the value to a content array. Plain strings become a single
   * text run; doc-JSON's `content` array is returned as-is.
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

  get isEmpty() {
    return this.runs.length === 0;
  }

  <template>
    {{yield
      (hash
        Content=(component
          InlineRichTextContent
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

/**
 * Inner-content component yielded as `R.Content`. Renders the actual mark
 * structure plus the data-attrs the editor chrome relies on. The
 * `--empty` modifier on the outer span is the **explicit replacement for
 * `:empty`** in placeholder CSS — set by JS based on `runs.length === 0`,
 * not by a CSS heuristic that has to navigate Glimmer's comment / whitespace
 * text nodes inside the content span.
 */
const InlineRichTextContent = <template>
  {{! Inner content wrapper exists so the editor chrome can hide rendered
      text via CSS while ProseMirror is mounted (admin chrome rule keys
      off the presence of a `.ve-inline-editor-mount` child) without
      touching the outer span — the outer span is the portal target the
      controller mounts ProseMirror into. }}
  <span
    class="ve-inline-rich-text {{if @isEmpty '--empty'}}"
    data-ve-inline-edit-arg={{@arg}}
    data-ve-inline-edit-schema={{@schema}}
    ...attributes
  ><span
      class="ve-inline-rich-text__content"
      data-ve-placeholder={{if @isEmpty @placeholder}}
    >{{#each @runs as |run|}}{{#if (eq run.type "hard_break")}}<br
          />{{else}}<MarkedText
            @text={{run.text}}
            @marks={{run.marks}}
          />{{/if}}{{/each}}</span></span>
</template>;
