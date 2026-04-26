import bodyClass from "discourse/helpers/body-class";
import { eq } from "discourse/truth-helpers";
import { ORDER_BY_ACTIVITY_FILTER } from "../../components/post-voting-answer-header";

const AddPostVotingTopicPageClass = <template>
  {{#if @outletArgs.model.is_post_voting}}
    {{bodyClass "post-voting-topic"}}
    {{#if (eq @outletArgs.model.postStream.filter ORDER_BY_ACTIVITY_FILTER)}}
      {{bodyClass "--sort-by-activity"}}
    {{/if}}
  {{/if}}
</template>;

export default AddPostVotingTopicPageClass;
