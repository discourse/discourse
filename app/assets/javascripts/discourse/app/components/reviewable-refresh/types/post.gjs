// import ReviewablePostEdits from "discourse/components/reviewable-post-edits";
import ReviewableCreatedBy from "discourse/components/reviewable-refresh/created-by";
import ReviewableTopicLink from "discourse/components/reviewable-refresh/topic-link";
import highlightWatchedWords from "discourse/lib/highlight-watched-words";
import { i18n } from "discourse-i18n";

<template>
  <div class="review-item__meta-content">
    <div class="review-item__meta-label">{{i18n "review.posted_in"}}</div>

    <div class="review-item__meta-topic-title">
      <ReviewableTopicLink @reviewable={{@reviewable}} @tagName="" />
      {{!-- <ReviewablePostEdits @reviewable={{@reviewable}} @tagName="" /> --}}
    </div>

    <div class="review-item__meta-label">{{i18n "review.review_user"}}</div>

    <div class="review-item__meta-flagged-user">
      <ReviewableCreatedBy @user={{@reviewable.target_created_by}} />
    </div>
  </div>

  <div class="review-item__post">
    <div class="review-item__post-content-wrapper">
      <p class="review-item__post-content">
        {{#if @reviewable.blank_post}}
          {{i18n "review.deleted_post"}}
        {{else}}
          {{highlightWatchedWords @reviewable.cooked @reviewable}}
        {{/if}}
      </p>
    </div>
  </div>
</template>
