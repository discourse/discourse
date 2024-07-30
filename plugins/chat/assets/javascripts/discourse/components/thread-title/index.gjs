import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { escapeExpression } from "discourse/lib/utilities";
import ThreadUnreadIndicator from "discourse/plugins/chat/discourse/components/thread-unread-indicator";

export default class ChatThreadTitle extends Component {
  @service site;

  get title() {
    if (this.args.thread.title) {
      return replaceEmoji(htmlSafe(escapeExpression(this.args.thread.title)));
    } else {
      return replaceEmoji(htmlSafe(this.args.thread.originalMessage.excerpt));
    }
  }

  <template>
    <span class="chat__thread-title-container">
      <span class="chat__thread-title">
        {{#if this.site.desktopView}}
          <LinkTo
            class="chat__thread-title__name"
            @route="chat.channel.thread"
            @models={{@thread.routeModels}}
          >
            {{this.title}}
          </LinkTo>
        {{else}}
          <span class="chat__thread-title__name">
            {{this.title}}
          </span>
        {{/if}}

      </span>
      <ThreadUnreadIndicator @thread={{@thread}} />
    </span>
  </template>
}
