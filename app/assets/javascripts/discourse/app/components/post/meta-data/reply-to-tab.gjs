import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import userPrioritizedName from "discourse/helpers/user-prioritized-name";

export default class PostMetaDataReplyToTab extends Component {
  static shouldRender(args, context, owner) {
    const siteSettings = owner.lookup("service:site-settings");

    return (
      args.post.reply_to_user?.username &&
      (!args.isReplyingDirectlyToPostAbove ||
        !siteSettings.suppress_reply_directly_above)
    );
  }

  @service site;

  <template>
    <a
      class="reply-to-tab"
      disabled={{@repliesAbove.isPending}}
      role={{if this.site.desktopView "button"}}
      aria-controls={{if
        this.site.desktopView
        (concat "embedded-posts__top--" @post.post_number)
      }}
      aria-expanded={{if this.site.desktopView @hasRepliesAbove}}
      tabindex="0"
      title="post.in_reply_to"
      {{on "click" @toggleReplyAbove}}
    >
      {{#if @repliesAbove.isPending}}
        <div class="spinner small"></div>
      {{else}}
        {{icon "share"}}
      {{/if}}
      {{avatar @post.reply_to_user imageSize="small"}}
      <span>{{userPrioritizedName @post.reply_to_user}}</span>
    </a>
  </template>
}
