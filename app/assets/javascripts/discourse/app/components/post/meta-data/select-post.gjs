import { and, not } from "truth-helpers";
import DButton from "discourse/components/d-button";

const PostMetaDataSelectPost = <template>
  <div class="select-posts">
    {{#if (and (not @selected) (not @post.firstPost))}}
      {{#if @post.hasReplies}}
        <DButton
          class="btn-flat select-replies"
          @label="topic.multi_select.select_replies.label"
          @title="topic.multi_select.select_replies.title"
          @action={{@selectReplies}}
        />
      {{/if}}
      <DButton
        class="btn-flat select-below"
        @label="topic.multi_select.select_below.label"
        @title="topic.multi_select.select_below.title"
        @action={{@selectBelow}}
      />
    {{/if}}
    <DButton
      class="btn-flat select-post"
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
      @action={{@togglePostSelection}}
    />
  </div>
</template>;

export default PostMetaDataSelectPost;
