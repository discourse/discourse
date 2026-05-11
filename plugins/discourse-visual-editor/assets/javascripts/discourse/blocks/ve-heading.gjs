// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import eq from "discourse/truth-helpers/helpers/eq";

const VALID_LEVELS = [1, 2, 3, 4, 5, 6];
const VALID_ALIGNMENTS = ["left", "center", "right"];

@block("ve:heading", {
  displayName: "Heading",
  icon: "heading",
  category: "Content",
  description: "A configurable section heading.",
  args: {
    text: {
      type: "string",
      default: "Heading",
      ui: { label: "Text" },
    },
    level: {
      type: "number",
      default: 2,
      integer: true,
      enum: VALID_LEVELS,
      ui: { label: "Level" },
    },
    align: {
      type: "string",
      default: "left",
      enum: VALID_ALIGNMENTS,
      ui: { label: "Alignment" },
    },
  },
  previewArgs: { text: "Section heading", level: 2, align: "left" },
})
export default class VEHeading extends Component {
  get className() {
    return `ve-heading ve-heading--align-${this.args.align ?? "left"}`;
  }

  <template>
    {{#if (eq @level 1)}}
      <h1 class={{this.className}}>{{@text}}</h1>
    {{else if (eq @level 3)}}
      <h3 class={{this.className}}>{{@text}}</h3>
    {{else if (eq @level 4)}}
      <h4 class={{this.className}}>{{@text}}</h4>
    {{else if (eq @level 5)}}
      <h5 class={{this.className}}>{{@text}}</h5>
    {{else if (eq @level 6)}}
      <h6 class={{this.className}}>{{@text}}</h6>
    {{else}}
      <h2 class={{this.className}}>{{@text}}</h2>
    {{/if}}
  </template>
}
