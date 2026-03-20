import { concat } from "@ember/helper";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

const PostVisitedLine = <template>
  <div class="small-action topic-post-visited">
    <div
      class={{dConcatClass
        "topic-post-visited-line"
        (concat "post-" @post.post_number)
      }}
    >
      <span class="topic-post-visited-message">
        {{i18n "topics.new_messages_marker"}}
      </span>
    </div>
  </div>
</template>;

export default PostVisitedLine;
