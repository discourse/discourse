import DButton from "discourse/components/d-button";

<template>
  <div class="workflows-empty-state">
    <span class="workflows-empty-state__icon">👋</span>
    <h2 class="workflows-empty-state__title">{{@title}}</h2>
    <p class="workflows-empty-state__description">{{@description}}</p>
    {{#if @onAction}}
      <DButton
        @action={{@onAction}}
        @label={{@buttonLabel}}
        class="btn-primary"
      />
    {{/if}}
  </div>
</template>
