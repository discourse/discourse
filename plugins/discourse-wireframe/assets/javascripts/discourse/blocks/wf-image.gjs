// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import DLightDarkImg from "discourse/ui-kit/d-light-dark-img";
import { i18n } from "discourse-i18n";
import { URL_PATTERN } from "../lib/arg-patterns";

/**
 * Returns the dark variant rebound to the LIGHT variant's intrinsic
 * dimensions, so `DLightDarkImg`'s `<picture>` element always renders
 * at the light frame size — even when the site's default colour
 * scheme is dark (in which case `DLightDarkImg.defaultImg` would
 * otherwise pick dark and stamp dark's own dims onto the `<img>`).
 *
 * Combined with `object-fit: cover` on the rendered image, this means
 * the dark variant is clipped to the light frame when their intrinsic
 * aspect ratios diverge — which is exactly what the inspector's
 * ratio-mismatch warning predicts.
 *
 * Returns `undefined` when no dark variant is set so the helper's
 * `isDarkImageAvailable` falls through to the light-only render path.
 *
 * @param {{url: string, width?: number, height?: number, dark?: {url: string}}|null|undefined} image
 * @returns {{url: string, width?: number, height?: number}|undefined}
 */
function darkVariantWithLightFrame(image) {
  if (!image?.dark?.url) {
    return undefined;
  }
  return {
    url: image.dark.url,
    width: image.width,
    height: image.height,
  };
}

@block("wf:image", {
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
        label: i18n("wireframe.inspector.image.image_label"),
      },
    },
    alt: {
      type: "string",
      default: "",
      ui: {
        label: i18n("wireframe.inspector.image.alt_label"),
        helpText: i18n("wireframe.inspector.image.alt_help"),
      },
    },
    link: {
      type: "string",
      pattern: URL_PATTERN,
      ui: {
        control: "url",
        label: i18n("wireframe.inspector.image.link_label"),
      },
    },
    caption: {
      type: "string",
      default: "",
      ui: {
        label: i18n("wireframe.inspector.image.caption_label"),
      },
    },
  },
})
export default class WFImage extends Component {
  <template>
    {{#if @image.url}}
      {{#if @caption}}
        <figure class="wf-image">
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
          <figcaption class="wf-image__caption">{{@caption}}</figcaption>
        </figure>
      {{else if @link}}
        <a href={{@link}} class="wf-image" data-block-arg="link">
          <DLightDarkImg
            data-block-arg="image"
            @lightImg={{@image}}
            @darkImg={{darkVariantWithLightFrame @image}}
            alt={{@alt}}
          />
        </a>
      {{else}}
        <DLightDarkImg
          class="wf-image"
          data-block-arg="image"
          data-drop-fills-block
          @lightImg={{@image}}
          @darkImg={{darkVariantWithLightFrame @image}}
          alt={{@alt}}
        />
      {{/if}}
    {{/if}}
  </template>
}
