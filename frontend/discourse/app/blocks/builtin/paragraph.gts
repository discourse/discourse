import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import RichTextRenderer from "discourse/lib/blocks/-internals/rich-text-renderer";
import { i18n } from "discourse-i18n";

const VALID_ALIGNMENTS = ["left", "center", "right"];

/**
 * A rich-inline argument value: either a plain string or a rich-text document
 * whose inline runs live under `content`. Passed straight through to the shared
 * rich-text renderer, which is the only consumer that inspects its shape.
 */
type RichInlineValue = string | { content?: unknown[] };

interface ParagraphSignature {
  Args: {
    text?: RichInlineValue;
    align?: string;
  };
}

@block("paragraph", {
  thumbnail: () => import("discourse/blocks/thumbnails/paragraph"),
  displayName: "Paragraph",
  icon: "paragraph",
  category: "Content",
  description: "A simple paragraph of text.",
  args: {
    text: {
      type: "richInline",
      required: true,
      ui: {
        control: "rich-inline",
        schema: "paragraph",
        label: i18n("blocks.builtin.paragraph.text"),
      },
    },
    align: {
      type: "string",
      default: "left",
      enum: VALID_ALIGNMENTS,
      ui: {
        control: "radio-group",
        label: i18n("blocks.builtin.paragraph.align"),
        optionIcons: {
          left: "wf-align-left",
          center: "wf-align-center",
          right: "wf-align-right",
        },
      },
    },
  },
})
export default class Paragraph extends Component<ParagraphSignature> {
  /**
   * Composes the BEM class list, appending a `--align-<value>` modifier
   * for the chosen text alignment.
   */
  get className(): string {
    return `d-block-paragraph d-block-paragraph--align-${this.args.align ?? "left"}`;
  }

  <template>
    <RichTextRenderer
      @arg="text"
      @schema="paragraph"
      @value={{@text}}
      @placeholder={{i18n "blocks.builtin.placeholders.paragraph_text"}}
      as |R|
    >
      <p class="{{this.className}} {{if R.isEmpty 'd-block-paragraph--empty'}}">
        <R.Content />
      </p>
    </RichTextRenderer>
  </template>
}
