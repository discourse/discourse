import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import userPrioritizedName from "discourse/helpers/user-prioritized-name";
import { i18n } from "discourse-i18n";

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

  @action
  handleClick(event) {
    event.preventDefault();
    this.args.toggleReplyAbove();
  }

  <template>
    <a
      href
      class="reply-to-tab"
      disabled={{@repliesAbove.isPending}}
      role={{if this.site.desktopView "button"}}
      aria-expanded={{if this.site.desktopView @hasRepliesAbove}}
      title={{i18n "post.in_reply_to"}}
      {{on "click" this.handleClick}}
    >
      {{#if @repliesAbove.isPending}}
        <div class="spinner small"></div>
      {{else}}
        {{icon "share"}}
      {{/if}}
      <PluginOutlet
        @name="post-meta-data-reply-to-tab-info"
        @outletArgs={{lazyHash post=@post}}
      >
        {{avatar @post.reply_to_user imageSize="small"}}
        <span>{{userPrioritizedName @post.reply_to_user}}</span>
      </PluginOutlet>
    </a>
  </template>
}
