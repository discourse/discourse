import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import formatDate from "discourse/helpers/format-date";
import replaceEmoji from "discourse/helpers/replace-emoji";

export default class ThreadPreview extends Component {
  get lastReplyDate() {
    return formatDate(this.args.preview.lastReplyCreatedAt, { leaveAgo: true });
  }

  <template>
    <span class="chat-message-thread-indicator__last-reply-timestamp">
      {{this.lastReplyDate}}
    </span>
    <span class="c-user-thread__excerpt">
      <span class="c-user-thread__excerpt-poster">
        {{@preview.lastReplyUser.username}}
      </span>
      <span>:</span>
      <span class="c-user-thread__excerpt-text">
        {{replaceEmoji (htmlSafe @preview.lastReplyExcerpt)}}
      </span>
    </span>
  </template>
}
