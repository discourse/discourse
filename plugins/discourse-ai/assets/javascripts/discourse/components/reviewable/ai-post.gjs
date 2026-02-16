import ReviewablePost from "discourse/components/reviewable-refresh/post";
import { i18n } from "discourse-i18n";
import ModelAccuracies from "../model-accuracies";

<template>
  <ReviewablePost
    @reviewable={{@reviewable}}
    @userLabel={{i18n "review.flagged_user"}}
    @pluginOutletName="after-reviewable-ai-post-body"
  >
    <ModelAccuracies @accuracies={{@reviewable.payload.accuracies}} />
  </ReviewablePost>
</template>
