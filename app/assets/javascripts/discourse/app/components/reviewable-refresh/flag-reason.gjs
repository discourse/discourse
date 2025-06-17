import { gt } from "truth-helpers";

<template>
  <span class="review-item__flag-reason --{{@score.type}}">
    {{#if (gt @score.count 0)}}
      <span class="review-item__flag-count --{{@score.type}}">
        {{@score.count}}
      </span>
    {{/if}}
    {{@score.title}}
  </span>
</template>