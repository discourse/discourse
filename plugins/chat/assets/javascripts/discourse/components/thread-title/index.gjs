import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { htmlSafe } from "@ember/template";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { escapeExpression } from "discourse/lib/utilities";
import ThreadUnreadIndicator from "discourse/plugins/chat/discourse/components/thread-unread-indicator";

export default class ChatThreadTitle extends Component {
  get title() {
    if (this.args.thread.title) {
      return replaceEmoji(htmlSafe(escapeExpression(this.args.thread.title)));
    } else {
      return replaceEmoji(htmlSafe(this.args.thread.originalMessage.excerpt));
    }
  }

  <template>
    <div class="chat__thread-title-container">
      <div class="chat__thread-title">
        <LinkTo
          class="chat__thread-title__name"
          @route="chat.channel.thread"
          @models={{@thread.routeModels}}
        >
          {{this.title}}
        </LinkTo>

        <ThreadUnreadIndicator @thread={{@thread}} />
      </div>
    </div>
  </template>
}
