// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";

const VALID_ALIGNMENTS = ["left", "center", "right"];

@block("ve:paragraph", {
  displayName: "Paragraph",
  icon: "paragraph",
  category: "Content",
  description: "A simple paragraph of text.",
  args: {
    text: {
      type: "string",
      default: "Add your text here.",
      ui: { control: "textarea", label: "Text" },
    },
    align: {
      type: "string",
      default: "left",
      enum: VALID_ALIGNMENTS,
      ui: { label: "Alignment" },
    },
  },
  previewArgs: {
    text: "A short paragraph of body text for the section.",
    align: "left",
  },
})
export default class VEParagraph extends Component {
  get className() {
    return `ve-paragraph ve-paragraph--align-${this.args.align ?? "left"}`;
  }

  <template>
    <p class={{this.className}}>{{@text}}</p>
  </template>
}
