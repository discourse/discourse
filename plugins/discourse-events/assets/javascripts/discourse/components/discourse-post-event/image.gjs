import { modifier } from "ember-modifier";
import getURL from "discourse/lib/get-url";
import lightbox from "discourse/lib/lightbox";

const setupLightbox = modifier((element, _positional, { post }) => {
  // Pass the post so the lightbox's quote-image action can build a reply
  lightbox(element.closest(".event-image"), { post });

  return () => window.pswp?.close();
});

export default <template>
  {{#if @imageUpload}}
    <section class="event__section event-image">
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
