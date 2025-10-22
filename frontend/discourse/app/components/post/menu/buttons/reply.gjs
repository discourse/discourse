import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";

export default class PostMenuReplyButton extends Component {
  static shouldRender(args) {
    return args.state.canCreatePost;
  }

  @service site;

  get showLabel() {
    return (
      this.args.showLabel ??
      (this.site.desktopView && !this.args.state.isWikiMode)
    );
  }

  <template>
    <DButton
      class={{concatClass
        "post-action-menu__reply"
        "reply"
        (if this.showLabel "create fade-out")
      }}
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
  </template>
}
