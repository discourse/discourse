import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import i18n from "discourse-common/helpers/i18n";

export default class PostMenuReplyButton extends Component {
  static shouldRender(args) {
    return args.context.canCreatePost;
  }

  @service site;

  get showLabel() {
    return (
      this.args.showLabel ??
      (this.site.desktopView && !this.args.context.isWikiMode)
    );
  }

  <template>
    {{#if @shouldRender}}
      <DButton
        class={{concatClass "reply" (if this.showLabel "create fade-out")}}
        ...attributes
        @action={{@buttonActions.replyToPost}}
        @icon="reply"
        @label={{if this.showLabel "topic.reply.title"}}
        @title="post.controls.reply"
        @translatedAriaLabel={{i18n
          "post.sr_reply_to"
          post_number=@post.post_number
          username=@post.username
        }}
      />
    {{/if}}
  </template>
}
