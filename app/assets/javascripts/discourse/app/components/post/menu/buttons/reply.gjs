import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import i18n from "discourse-common/helpers/i18n";

export default class PostMenuReplyButton extends Component {
  @service site;

  <template>
    {{#if @transformedPost.canCreatePost}}
      <DButton
        class="reply create fade-out"
        ...attributes
        @icon="reply"
        @title="post.controls.reply"
        @label={{if @properties.showLabel "topic.reply.title"}}
        @translatedAriaLabel={{i18n
          "post.sr_reply_to"
          post_number=@transformedPost.post_number
          username=@transformedPost.username
        }}
        @action={{@action}}
      />
    {{/if}}
  </template>
}
