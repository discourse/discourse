import ReviewablePost from "discourse/components/reviewable/post";
import { i18n } from "discourse-i18n";
import ModelAccuracies from "../model-accuracies";

export default <template>
  <ReviewablePost
    @pluginOutletName="after-reviewable-ai-post-body"
    @reviewable={{@reviewable}}
    @userLabel={{i18n "review.flagged_user"}}
  >
    <ModelAccuracies @accuracies={{@reviewable.payload.accuracies}} />
  </ReviewablePost>
</template>
