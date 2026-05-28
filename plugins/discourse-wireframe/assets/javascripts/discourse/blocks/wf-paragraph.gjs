// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import { i18n } from "discourse-i18n";
import RichTextRenderer from "../components/rich-text-renderer";

const VALID_ALIGNMENTS = ["left", "center", "right"];

@block("wf:paragraph", {
  displayName: "Paragraph",
  icon: "paragraph",
  category: "Content",
  description: "A simple paragraph of text.",
  args: {
    text: {
      type: "richInline",
      required: true,
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
export default class WFParagraph extends Component {
  get className() {
    return `wf-paragraph wf-paragraph--align-${this.args.align ?? "left"}`;
  }

  <template>
    <RichTextRenderer
      @arg="text"
      @schema="paragraph"
      @value={{@text}}
      @placeholder={{i18n "wireframe.placeholders.paragraph_text"}}
      as |R|
    >
      <p class="{{this.className}} {{if R.isEmpty 'wf-paragraph--empty'}}">
        <R.Content />
      </p>
    </RichTextRenderer>
  </template>
}
