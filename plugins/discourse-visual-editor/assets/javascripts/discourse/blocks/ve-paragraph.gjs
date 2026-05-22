// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import { i18n } from "discourse-i18n";
import InlineRichTextRenderer from "../components/inline-rich-text-renderer";

const VALID_ALIGNMENTS = ["left", "center", "right"];

@block("ve:paragraph", {
  displayName: "Paragraph",
  icon: "paragraph",
  category: "Content",
  description: "A simple paragraph of text.",
  args: {
    text: {
      type: "richInline",
      ui: { control: "rich-inline", label: "Text" },
    },
    align: {
      type: "string",
      default: "left",
      enum: VALID_ALIGNMENTS,
      ui: {
        control: "radio-group",
        label: "Alignment",
        optionIcons: {
          left: "align-left",
          center: "align-center",
          right: "align-right",
        },
      },
    },
  },
})
export default class VEParagraph extends Component {
  get className() {
    return `ve-paragraph ve-paragraph--align-${this.args.align ?? "left"}`;
  }

  <template>
    <InlineRichTextRenderer
      @arg="text"
      @schema="paragraph"
      @value={{@text}}
      @placeholder={{i18n "visual_editor.placeholders.paragraph_text"}}
      as |R|
    >
      <p class="{{this.className}} {{if R.isEmpty 've-paragraph--empty'}}">
        <R.Content />
      </p>
    </InlineRichTextRenderer>
  </template>
}
