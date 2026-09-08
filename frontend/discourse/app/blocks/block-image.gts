import Component from "@glimmer/component";
import { type TrustedHTML, trustHTML } from "@ember/template";
import {
  type BlockImageValue,
  imageCompositionStyle,
} from "discourse/blocks/image-value";
import DLightDarkImg from "discourse/ui-kit/d-light-dark-img";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

interface BlockImageSignature {
  Args: {
    /** Image source, optional frame, and shared composition. */
    image?: BlockImageValue;
    /** Alternative text; backgrounds should leave this empty. */
    alt?: string;
    /** Fill a frame owned by the containing block, ignoring intrinsic sizing. */
    fill?: boolean;
  };
  Element: HTMLDivElement;
}

export default class BlockImage extends Component<BlockImageSignature> {
  get alt(): string {
    return this.args.alt ?? "";
  }

  get darkSource(): BlockImageValue | undefined {
    const image = this.args.image;
    return image?.dark?.url
      ? { ...image.dark, width: image.width, height: image.height }
      : undefined;
  }

  get style(): TrustedHTML {
    const image = this.args.image;
    const frame = image?.frame ?? image;
    const width = frame?.width;
    const height = frame?.height;
    const geometry =
      !this.args.fill &&
      typeof width === "number" &&
      typeof height === "number" &&
      Number.isFinite(width) &&
      Number.isFinite(height) &&
      width > 0 &&
      height > 0
        ? `--block-image-width: ${width}px; --block-image-ratio: ${width / height};`
        : "";
    return trustHTML(imageCompositionStyle(image) + geometry);
  }

  <template>
    <div
      class={{dConcatClass
        "d-block-image-frame"
        (if @fill "--fill")
        (if @image.frame "--sized")
      }}
      style={{this.style}}
      ...attributes
    >
      <DLightDarkImg
        alt={{this.alt}}
        class="d-block-image-frame__image"
        @darkImg={{this.darkSource}}
        @lightImg={{@image}}
      />
    </div>
  </template>
}
