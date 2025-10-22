import { eq } from "truth-helpers";
import bodyClass from "discourse/helpers/body-class";
import { ORDER_BY_ACTIVITY_FILTER } from "../../components/post-voting-answer-header";

const AddPostVotingTopicPageClass = <template>
  {{#if @outletArgs.model.is_post_voting}}
    {{bodyClass
      (if
        (eq @outletArgs.model.postStream.filter ORDER_BY_ACTIVITY_FILTER)
        "post-voting-topic-sort-by-activity"
        "post-voting-topic"
      )
    }}
  {{/if}}
</template>;

export default AddPostVotingTopicPageClass;
