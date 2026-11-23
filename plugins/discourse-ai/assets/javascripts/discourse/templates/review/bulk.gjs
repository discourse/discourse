import ReviewableNav from "discourse/components/reviewable/nav";
import AiReviewBulk from "../../components/ai-review-bulk.gjs";

export default <template>
  <ReviewableNav />
  <AiReviewBulk
    @nextOffset={{@model.next_offset}}
    @suggestions={{@model.suggestions}}
  />
</template>
