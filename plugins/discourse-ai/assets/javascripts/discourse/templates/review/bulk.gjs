import ReviewableNav from "discourse/components/reviewable/nav";
import AiReviewBulk from "../../components/ai-review-bulk.gjs";

export default <template>
  <ReviewableNav />
  <AiReviewBulk @suggestions={{@model.suggestions}} @total={{@model.total}} />
</template>
