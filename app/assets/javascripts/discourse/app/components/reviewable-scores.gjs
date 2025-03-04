import Component from "@ember/component";
import iN from "discourse/helpers/i18n";
import ReviewableScore from "discourse/components/reviewable-score";
import htmlSafe from "discourse/helpers/html-safe";
import ReviewableConversationPost from "discourse/components/reviewable-conversation-post";

export default class ReviewableScores extends Component {<template>{{#if this.reviewable.reviewable_scores}}
  <div class="reviewable-scores__table-wrapper">
    <table class="reviewable-scores">
      <thead>
        <tr>
          <th>{{iN "review.scores.submitted_by"}}</th>
          <th>{{iN "review.scores.date"}}</th>
          <th>{{iN "review.scores.type"}}</th>
          <th>{{iN "review.scores.reviewed_by"}}</th>
          <th>{{iN "review.scores.reviewed_timestamp"}}</th>
          <th>{{iN "review.scores.status"}}</th>
        </tr>
      </thead>
      <tbody>
        {{#each this.reviewable.reviewable_scores as |rs|}}
          <ReviewableScore @rs={{rs}} @reviewable={{this.reviewable}} />
        {{/each}}
      </tbody>
    </table>
  </div>

  {{#each this.reviewable.reviewable_scores as |rs|}}
    {{#if rs.reason}}
      <div class="reviewable-score-reason">{{htmlSafe rs.reason}}</div>
    {{/if}}
    {{#if rs.context}}
      <div class="reviewable-score-context">{{htmlSafe rs.context}}</div>
    {{/if}}

    {{#if rs.reviewable_conversation}}
      <div class="reviewable-conversation">
        {{#each rs.reviewable_conversation.conversation_posts as |p index|}}
          <ReviewableConversationPost @post={{p}} @index={{index}} />
        {{/each}}
        <div class="controls">
          <a href={{rs.reviewable_conversation.permalink}} class="btn btn-small">
            {{iN "review.conversation.view_full"}}
          </a>
        </div>
      </div>
    {{/if}}
  {{/each}}

{{/if}}</template>}
