import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { getURLWithCDN } from "discourse/lib/get-url";

export interface DCdnImgSignature {
  Args: {
    /** The URL of the image. Without it, nothing is rendered. */
    src?: string | null;

    /** The width of the image, in pixels. */
    width?: number | null;

    /** The height of the image, in pixels. With `@width`, it sets the aspect ratio. */
    height?: number | null;
  };

  Element: HTMLImageElement;
}

export default class DCdnImg extends Component<DCdnImgSignature> {
  get cdnSrc() {
    // The template only reads this inside `{{#if @src}}`.
    return getURLWithCDN(this.args.src as string);
  }

  get style() {
    if (this.args.width && this.args.height) {
      return trustHTML(
        `--aspect-ratio: ${this.args.width / this.args.height};`
      );
    }
  }

  <template>
    {{#if @src}}
      <img
        ...attributes
        alt=""
        height={{@height}}
        src={{this.cdnSrc}}
        style={{this.style}}
        width={{@width}}
      />
    {{/if}}
  </template>
}
