// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import DCdnImg from "discourse/ui-kit/d-cdn-img";

@block("ve:image", {
  displayName: "Image",
  icon: "image",
  category: "Content",
  description: "A CDN-aware image with optional dimensions.",
  args: {
    src: {
      type: "string",
      default: "",
      ui: { label: "Image URL" },
    },
    alt: {
      type: "string",
      default: "",
      ui: { label: "Alt text" },
    },
    width: {
      type: "number",
      integer: true,
      min: 1,
      ui: { label: "Width (px)" },
    },
    height: {
      type: "number",
      integer: true,
      min: 1,
      ui: { label: "Height (px)" },
    },
  },
  previewArgs: { src: "", alt: "Sample image" },
})
export default class VEImage extends Component {
  <template>
    <DCdnImg
      class="ve-image"
      @src={{@src}}
      @width={{@width}}
      @height={{@height}}
      alt={{@alt}}
    />
  </template>
}
