import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import { gt } from "truth-helpers";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import userPrioritizedName from "discourse/helpers/user-prioritized-name";

export default class PostMetaDataReplyToTab {
  @service site;

  <template>
    <a
      class="reply-to-tab"
      disabled={{@repliesAbove.loading}}
      role={{if this.site.mobileView "button"}}
      aria-controls={{if
        this.site.mobileView
        (concat "embedded-posts__top--" @post.post_number)
      }}
      aria-expanded={{if
        this.site.mobileView
        (gt @repliesAbove.value.length 0)
      }}
      tabindex="0"
      title="post.in_reply_to"
      {{on "click" this.args.toggleReplyAbove}}
    >
      {{#if @repliesAbove.loading}}
        <div class="spinner small"></div>
      {{else}}
        {{icon "share"}}
      {{/if}}
      {{avatar @post.reply_to_user imageSize="small"}}
      <span>{{userPrioritizedName @post.reply_to_user}}</span>
    </a>
  </template>
}
