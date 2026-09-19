import { and, not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";

const PostMetaDataSelectPost = <template>
  <div class="select-posts">
    {{#if (and (not @selected) (not @post.firstPost))}}
      {{#if @post.hasReplies}}
        <DButton
          class="btn-flat select-replies"
          @action={{@selectReplies}}
          @label="topic.multi_select.select_replies.label"
          @title="topic.multi_select.select_replies.title"
        />
      {{/if}}
      <DButton
        class="btn-flat select-below"
        @action={{@selectBelow}}
        @label="topic.multi_select.select_below.label"
        @title="topic.multi_select.select_below.title"
      />
    {{/if}}
    <DButton
      class="btn-flat select-post"
      @action={{@togglePostSelection}}
      @label={{if
        @selected
        "topic.multi_select.selected_post.label"
        "topic.multi_select.select_post.label"
      }}
      @title={{if
        @selected
        "topic.multi_select.selected_post.title"
        "topic.multi_select.select_post.title"
      }}
    />
  </div>
</template>;

export default PostMetaDataSelectPost;
