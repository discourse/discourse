import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import getURL from "discourse/lib/get-url";
import lightbox from "discourse/lib/lightbox";

const setupLightbox = modifier((element, _positional, { post }) => {
  // Pass the post so the lightbox's quote-image action can build a reply
  lightbox(element.closest(".event-image"), { post });

  return () => window.pswp?.close();
});

const HEX_COLOR = /^[0-9a-f]{6}$/i;

const isSideImage = (upload) =>
  upload?.width > 0 && upload?.height > upload.width;

// Too far from 16:9 to crop without losing much of the image, so it's shown whole inside the banner
const isLetterboxed = (upload) =>
  upload?.height > 0 &&
  upload.width >= upload.height &&
  (upload.width * 3 < upload.height * 4 || upload.width > upload.height * 2);

// Lets letterboxed images fill their frame with their own color and fit it to their size
const letterboxStyle = (upload) => {
  const properties = [];

  if (HEX_COLOR.test(upload?.dominant_color ?? "")) {
    properties.push(`--event-image-color: #${upload.dominant_color}`);
  }

  const width = Number(upload?.width);
  const height = Number(upload?.height);
  if (width > 0 && height > 0) {
    properties.push(`--event-image-ratio: ${height / width}`);
    properties.push(`--event-image-height: ${height}px`);
  }

  return properties.length ? trustHTML(properties.join("; ")) : null;
};

export default <template>
  {{#if @imageUpload}}
    <section
      class="event__section event-image
        {{if (isSideImage @imageUpload) '--side'}}
        {{if (isLetterboxed @imageUpload) '--letterboxed'}}"
      style={{if
        (or (isLetterboxed @imageUpload) (isSideImage @imageUpload))
        (letterboxStyle @imageUpload)
      }}
    >
      {{#if @linkToPost}}
        <a href={{getURL @postUrl}} rel="noopener noreferrer">
          <img alt={{@alt}} src={{@imageUpload.url}} />
        </a>
      {{else}}
        <a
          class="lightbox"
          href={{@imageUpload.url}}
          {{setupLightbox post=@post}}
        >
          <img alt={{@alt}} src={{@imageUpload.url}} />
        </a>
      {{/if}}
    </section>
  {{/if}}
</template>
