import ReviewablePost from "discourse/components/reviewable-refresh/post";
import { i18n } from "discourse-i18n";

<template>
  <ReviewablePost
    @reviewable={{@reviewable}}
    @userLabel={{i18n "review.flagged_user"}}
    @pluginOutletName="after-reviewable-flagged-post-body"
  >
    {{yield}}
  </ReviewablePost>
</template>
