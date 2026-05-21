// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import DLightDarkImg from "discourse/ui-kit/d-light-dark-img";
import { i18n } from "discourse-i18n";

@block("ve:image", {
  displayName: "Image",
  icon: "image",
  category: "Content",
  description: "An image with an optional dark-mode variant.",
  args: {
    image: {
      type: "object",
      properties: {
        url: { type: "string", required: true },
        width: { type: "number" },
        height: { type: "number" },
      },
      ui: {
        control: "image-upload",
        label: i18n("visual_editor.inspector.image.image_label"),
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
        label: i18n("visual_editor.inspector.image.dark_label"),
        helpText: i18n("visual_editor.inspector.image.dark_help"),
      },
    },
    alt: {
      type: "string",
      default: "",
      ui: {
        label: i18n("visual_editor.inspector.image.alt_label"),
        helpText: i18n("visual_editor.inspector.image.alt_help"),
      },
    },
    link: {
      type: "string",
      default: "",
      ui: {
        control: "url",
        label: i18n("visual_editor.inspector.image.link_label"),
      },
    },
    caption: {
      type: "string",
      default: "",
      ui: {
        label: i18n("visual_editor.inspector.image.caption_label"),
      },
    },
  },
})
export default class VEImage extends Component {
  <template>
    {{#if @image.url}}
      {{#if @caption}}
        <figure class="ve-image">
          {{#if @link}}
            <a href={{@link}}>
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
          <figcaption class="ve-image__caption">{{@caption}}</figcaption>
        </figure>
      {{else if @link}}
        <a href={{@link}} class="ve-image">
          <DLightDarkImg
            @lightImg={{@image}}
            @darkImg={{@imageDark}}
            alt={{@alt}}
          />
        </a>
      {{else}}
        <DLightDarkImg
          class="ve-image"
          @lightImg={{@image}}
          @darkImg={{@imageDark}}
          alt={{@alt}}
        />
      {{/if}}
    {{/if}}
  </template>
}
