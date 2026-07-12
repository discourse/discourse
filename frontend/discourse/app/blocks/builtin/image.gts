import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import { URL_PATTERN } from "discourse/lib/blocks";
import DLightDarkImg from "discourse/ui-kit/d-light-dark-img";
import { i18n } from "discourse-i18n";

/**
 * An image argument value: a resolved upload with intrinsic dimensions and an
 * optional dark-scheme variant of the same shape.
 */
interface BlockImageValue {
  url?: string;
  width?: number;
  height?: number;
  dark?: BlockImageValue;
}

interface ImageSignature {
  Args: {
    image?: BlockImageValue;
    alt?: string;
    link?: string;
    caption?: string;
  };
}

/**
 * Returns the dark variant rebound to the LIGHT variant's intrinsic
 * dimensions, so `DLightDarkImg`'s `<picture>` element always renders
 * at the light frame size — even when the site's default colour
 * scheme is dark (in which case `DLightDarkImg.defaultImg` would
 * otherwise pick dark and stamp dark's own dims onto the `<img>`).
 *
 * Combined with `object-fit: cover` on the rendered image, this means
 * the dark variant is clipped to the light frame when their intrinsic
 * aspect ratios diverge — which is exactly what a dark-variant
 * ratio-mismatch check predicts.
 *
 * Returns `undefined` when no dark variant is set so the helper's
 * `isDarkImageAvailable` falls through to the light-only render path.
 *
 * @param image - The image argument value, whose `dark` variant is rebound.
 * @returns The dark variant carrying the light frame's dimensions, or
 *   `undefined` when there is no dark variant.
 */
function darkVariantWithLightFrame(
  image?: BlockImageValue | null
): { url?: string; width?: number; height?: number } | undefined {
  if (!image?.dark?.url) {
    return undefined;
  }
  return {
    url: image.dark.url,
    width: image.width,
    height: image.height,
  };
}

@block("image", {
  thumbnail: () => import("discourse/blocks/thumbnails/image"),
  displayName: "Image",
  icon: "image",
  category: "Content",
  description: "An image with an optional dark-mode variant.",
  args: {
    image: {
      type: "image",
      required: true,
      allowDark: true,
      allowResize: true,
      aspectRatio: "auto",
      defaultFit: "cover",
      ui: {
        label: i18n("blocks.builtin.image.image_label"),
      },
    },
    alt: {
      type: "string",
      default: "",
      ui: {
        label: i18n("blocks.builtin.image.alt_label"),
        helpText: i18n("blocks.builtin.image.alt_help"),
      },
    },
    link: {
      type: "string",
      pattern: URL_PATTERN,
      ui: {
        control: "url",
        label: i18n("blocks.builtin.image.link_label"),
      },
    },
    caption: {
      type: "string",
      default: "",
      ui: {
        label: i18n("blocks.builtin.image.caption_label"),
      },
    },
  },
})
export default class Image extends Component<ImageSignature> {
  <template>
    {{#if @image.url}}
      {{#if @caption}}
        <figure class="d-block-image">
          {{#if @link}}
            <a href={{@link}} data-block-arg="link">
              <DLightDarkImg
                data-block-arg="image"
                data-drop-fills-block
                @lightImg={{@image}}
                @darkImg={{darkVariantWithLightFrame @image}}
                alt={{@alt}}
              />
            </a>
          {{else}}
            <DLightDarkImg
              data-block-arg="image"
              data-drop-fills-block
              @lightImg={{@image}}
              @darkImg={{darkVariantWithLightFrame @image}}
              alt={{@alt}}
            />
          {{/if}}
          <figcaption class="d-block-image__caption">{{@caption}}</figcaption>
        </figure>
      {{else if @link}}
        <a href={{@link}} class="d-block-image" data-block-arg="link">
          <DLightDarkImg
            data-block-arg="image"
            @lightImg={{@image}}
            @darkImg={{darkVariantWithLightFrame @image}}
            alt={{@alt}}
          />
        </a>
      {{else}}
        <DLightDarkImg
          class="d-block-image"
          data-block-arg="image"
          data-drop-fills-block
          @lightImg={{@image}}
          @darkImg={{darkVariantWithLightFrame @image}}
          alt={{@alt}}
        />
      {{/if}}
    {{else}}
      {{! With no image the block renders nothing on the live site, so
          edit tooling has nothing to anchor an overlay to. This persistent
          marker fills that gap: the drop-fills-block flag makes the overlay
          span the whole block, so the marker itself needs no geometry and
          stays collapsed via the empty modifier on the live path. }}
      <div
        class="d-block-image d-block-image--empty"
        data-block-arg="image"
        data-drop-fills-block
      ></div>
    {{/if}}
  </template>
}
