// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import DLightDarkImg from "discourse/ui-kit/d-light-dark-img";
import { i18n } from "discourse-i18n";
import { URL_PATTERN } from "../lib/arg-patterns";

@block("wf:image", {
  displayName: "Image",
  icon: "image",
  category: "Content",
  description: "An image with an optional dark-mode variant.",
  args: {
    image: {
      type: "object",
      required: true,
      properties: {
        url: { type: "string", required: true },
        width: { type: "number" },
        height: { type: "number" },
      },
      ui: {
        control: "image-upload",
        label: i18n("wireframe.inspector.image.image_label"),
      },
    },
    imageDark: {
      type: "object",
      properties: {
        url: { type: "string", required: true },
        width: { type: "number" },
        height: { type: "number" },
      },
      ui: {
        control: "image-upload",
        label: i18n("wireframe.inspector.image.dark_label"),
        helpText: i18n("wireframe.inspector.image.dark_help"),
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
                @lightImg={{@image}}
                @darkImg={{@imageDark}}
                alt={{@alt}}
              />
            </a>
          {{else}}
            <DLightDarkImg
              @lightImg={{@image}}
              @darkImg={{@imageDark}}
              alt={{@alt}}
            />
          {{/if}}
          <figcaption class="wf-image__caption">{{@caption}}</figcaption>
        </figure>
      {{else if @link}}
        <a href={{@link}} class="wf-image" data-block-arg="link">
          <DLightDarkImg
            @lightImg={{@image}}
            @darkImg={{@imageDark}}
            alt={{@alt}}
          />
        </a>
      {{else}}
        <DLightDarkImg
          class="wf-image"
          @lightImg={{@image}}
          @darkImg={{@imageDark}}
          alt={{@alt}}
        />
      {{/if}}
    {{/if}}
  </template>
}
