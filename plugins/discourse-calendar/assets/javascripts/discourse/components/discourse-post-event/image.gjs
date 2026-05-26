<template>
  {{#if @imageUpload}}
    <section class="event__section event-image">
      <a class="lightbox" href={{@imageUpload.url}}>
        <img src={{@imageUpload.url}} alt={{@alt}} />
      </a>
    </section>
  {{/if}}
</template>
