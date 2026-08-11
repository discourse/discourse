import { LinkTo } from "@ember/routing";
import ReviewableItem from "discourse/components/reviewable/item";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const ReviewShow = <template>
  <div class="reviewable-top-nav">
    <LinkTo @route="review.index">
      {{dIcon "arrow-left"}}
      {{i18n "review.back_to_queue"}}
    </LinkTo>
  </div>
  <ReviewableItem @reviewable={{@controller.reviewable}} @showHelp={{true}} />
</template>;

export default ReviewShow;
