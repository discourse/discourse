import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import replaceEmoji from "discourse/helpers/replace-emoji";
import ThreadUnreadIndicator from "discourse/plugins/chat/discourse/components/thread-unread-indicator";

export default class ChatThreadTitle extends Component {
  get title() {
    let title =
      this.args.thread.title ?? this.args.thread.originalMessage.excerpt;
    title = replaceEmoji(htmlSafe(title));
    return title;
  }

  <template>
    <div class="chat__thread-title-container">
      <div class="chat__thread-title">
        <span class="chat__thread-title__name">
          {{this.title}}
        </span>

        <ThreadUnreadIndicator @thread={{@thread}} />
      </div>
    </div>
  </template>
}
