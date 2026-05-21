// @ts-check
import Component from "@glimmer/component";
import eq from "discourse/truth-helpers/helpers/eq";
import MarkedText from "./marked-text";

/**
 * Pure-render walker for inline rich text content. Accepts either a plain
 * string (the common, unformatted case) or a ProseMirror doc-JSON object.
 *
 * Emits a `<span>` tagged with two data-attrs so the editor chrome can find
 * and decorate the region without the block component needing to know
 * anything about edit state:
 *
 *   - `data-ve-inline-edit-arg`     — the arg name (used for click-to-edit)
 *   - `data-ve-inline-edit-schema`  — the schema variant (plain/heading/paragraph),
 *                                     which the editor reads to choose the
 *                                     ProseMirror extension list and toolbar.
 *
 * The data-attrs are inert on the live site — nothing listens for them.
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
    {{! Inner content wrapper exists so the editor chrome can hide rendered
        text via CSS (`.is-editing > .ve-inline-rich-text__content`) without
        touching the outer span's DOM — that's the portal target the
        controller mounts ProseMirror into. }}
    <span
      class="ve-inline-rich-text"
      data-ve-inline-edit-arg={{@arg}}
      data-ve-inline-edit-schema={{@schema}}
      ...attributes
    ><span
        class="ve-inline-rich-text__content"
        data-ve-placeholder={{if this.isEmpty @placeholder}}
      >{{#each this.runs as |run|}}{{#if (eq run.type "hard_break")}}<br
            />{{else}}<MarkedText
              @text={{run.text}}
              @marks={{run.marks}}
            />{{/if}}{{/each}}</span></span>
  </template>
}
