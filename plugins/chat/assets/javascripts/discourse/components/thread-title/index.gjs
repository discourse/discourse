import Component from "@glimmer/component";
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
    <span class="chat__thread-title-container">
      <span class="chat__thread-title">
        <span class="chat__thread-title__name">
          {{this.title}}
        </span>

        <ThreadUnreadIndicator @thread={{@thread}} />
      </span>
    </span>
  </template>
}
