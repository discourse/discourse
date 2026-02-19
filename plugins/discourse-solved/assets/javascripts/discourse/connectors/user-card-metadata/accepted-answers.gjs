import { i18n } from "discourse-i18n";

<template>
  <div class="user-card-metadata-outlet accepted-answers" ...attributes>
    {{#if @outletArgs.user.accepted_answers}}
      <span class="desc">{{i18n "solutions"}}</span>
      <span>{{@outletArgs.user.accepted_answers}}</span>
    {{/if}}
  </div>
</template>
