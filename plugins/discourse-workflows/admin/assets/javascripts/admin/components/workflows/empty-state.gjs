import DButton from "discourse/components/d-button";

<template>
  <div class="workflows-empty-state">
    <span class="workflows-empty-state__icon">👋</span>
    <h2>{{@title}}</h2>
    <p>{{@description}}</p>
    {{#if @onAction}}
      <DButton
        @action={{@onAction}}
        @label={{@buttonLabel}}
        class="btn-primary"
      />
    {{/if}}
  </div>
</template>
