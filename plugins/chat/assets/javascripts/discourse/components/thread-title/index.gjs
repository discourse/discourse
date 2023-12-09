import Component from "@glimmer/component";
import replaceEmoji from "discourse/helpers/replace-emoji";
import ThreadUnreadIndicator from "discourse/plugins/chat/discourse/components/thread-unread-indicator";

export default class ChatThreadTitle extends Component {
  get title() {
    let title =
      this.args.thread.title ?? this.args.thread.originalMessage.excerpt;
    title.replace(/&hellip;/g, "...");
    return replaceEmoji(title);
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
