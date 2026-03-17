<template>
  {{#if @imageUpload}}
    <section class="event__section event-image">
      <img src={{@imageUpload.url}} alt={{@altText}} />
    </section>
  {{/if}}
</template>
