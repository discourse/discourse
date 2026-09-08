import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import BlockImage from "discourse/blocks/block-image";
import type { BlockImageValue } from "discourse/blocks/image-value";
import { URL_PATTERN } from "discourse/lib/blocks";
import { i18n } from "discourse-i18n";

interface ImageSignature {
  Args: {
    /** Image sources, composition, and optional frame size. */
    image?: BlockImageValue;
    /** Alternative text describing the image. */
    alt?: string;
    /** Destination when the image is activated. */
    link?: string;
    /** Visible caption outside the image's clipping frame. */
    caption?: string;
  };
}

@block("image", {
  thumbnail: () => import("discourse/blocks/thumbnails/image"),
  displayName: "Image",
  icon: "image",
  category: "media",
  description: "An image with an optional dark-mode variant.",
  args: {
    image: {
      type: "image",
      required: true,
      allowDark: true,
      allowResize: true,
      allowComposition: true,
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
        group: i18n("blocks.builtin.image.content_group"),
        helpText: i18n("blocks.builtin.image.alt_help"),
      },
    },
    link: {
      type: "string",
      pattern: URL_PATTERN,
      ui: {
        control: "url",
        label: i18n("blocks.builtin.image.link_label"),
        group: i18n("blocks.builtin.image.content_group"),
      },
    },
    caption: {
      type: "string",
      default: "",
      ui: {
        label: i18n("blocks.builtin.image.caption_label"),
        group: i18n("blocks.builtin.image.content_group"),
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
              <BlockImage
                data-block-arg="image"
                data-drop-fills-block
                @image={{@image}}
                @alt={{@alt}}
              />
            </a>
          {{else}}
            <BlockImage
              data-block-arg="image"
              data-drop-fills-block
              @image={{@image}}
              @alt={{@alt}}
            />
          {{/if}}
          <figcaption class="d-block-image__caption">{{@caption}}</figcaption>
        </figure>
      {{else if @link}}
        <a href={{@link}} class="d-block-image" data-block-arg="link">
          <BlockImage data-block-arg="image" @image={{@image}} @alt={{@alt}} />
        </a>
      {{else}}
        <BlockImage
          class="d-block-image"
          data-block-arg="image"
          data-drop-fills-block
          @image={{@image}}
          @alt={{@alt}}
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
