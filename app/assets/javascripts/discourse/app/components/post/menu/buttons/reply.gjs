import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import i18n from "discourse-common/helpers/i18n";

const PostMenuReplyButton = <template>
  {{#if @properties.canCreatePost}}
    <DButton
      class={{concatClass "reply" (if @properties.showLabel "create fade-out")}}
      ...attributes
      @icon="reply"
      @title="post.controls.reply"
      @label={{if @properties.showLabel "topic.reply.title"}}
      @translatedAriaLabel={{i18n
        "post.sr_reply_to"
        post_number=@post.post_number
        username=@post.username
      }}
      @action={{@action}}
    />
  {{/if}}
</template>;

export default PostMenuReplyButton;
