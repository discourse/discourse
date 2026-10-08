import ReviewablePost from "discourse/components/reviewable/post";
import { i18n } from "discourse-i18n";

export default <template>
  <ReviewablePost
    @pluginOutletName="after-reviewable-flagged-post-body"
    @reviewable={{@reviewable}}
    @userLabel={{i18n "review.flagged_user"}}
  >
    {{yield}}
  </ReviewablePost>
</template>
