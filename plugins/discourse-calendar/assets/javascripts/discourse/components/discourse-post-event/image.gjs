import { modifier } from "ember-modifier";
import getURL from "discourse/lib/get-url";
import lightbox from "discourse/lib/lightbox";

const setupLightbox = modifier((element) => {
  lightbox(element.closest(".event-image"));

  return () => window.pswp?.close();
});

<template>
  {{#if @imageUpload}}
    <section class="event__section event-image">
      {{#if @linkToPost}}
        <a href={{getURL @postUrl}} rel="noopener noreferrer">
          <img src={{@imageUpload.url}} alt={{@alt}} />
        </a>
      {{else}}
        <a class="lightbox" href={{@imageUpload.url}} {{setupLightbox}}>
          <img src={{@imageUpload.url}} alt={{@alt}} />
        </a>
      {{/if}}
    </section>
  {{/if}}
</template>
