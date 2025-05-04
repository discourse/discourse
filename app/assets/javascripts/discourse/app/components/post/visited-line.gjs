import { concat } from "@ember/helper";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";

const PostVisitedLine = <template>
  <div class="small-action topic-post-visited">
    <div
      class={{concatClass
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
